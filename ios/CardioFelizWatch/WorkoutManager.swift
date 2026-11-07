import Foundation
import HealthKit
import WatchKit
import Combine

/// Sesión de entrenamiento del Watch: mantiene la app activa (`HKWorkoutSession`), mide ritmo cardíaco y
/// calorías (`HKLiveWorkoutBuilder`), guarda el entrenamiento en Salud y manda el resumen al iPhone.
///
/// Reglas:
/// - Una sesión de Salud por `sessionId` del iPhone. Se abre solo con un estado "en curso" vigente
///   (`isStale`) y nunca para una sesión que ya cerró aquí: un contexto viejo no abre sesiones fantasma.
/// - Se cierra cuando el iPhone dice que terminó, o cuando el estado caduca (iPhone perdido).
/// - Solo se piden: lectura de ritmo cardíaco y energía activa, y escritura de entrenamientos.
/// - Sin permiso o sin Salud, el cronómetro sigue funcionando; solo faltan los datos de Salud.
public final class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    public static let shared = WorkoutManager()

    public enum HealthStatus: Equatable {
        /// Sin sesión de Salud abierta.
        case idle
        case requestingAccess
        case active
        /// El usuario no dio permiso para guardar entrenamientos.
        case denied
        /// Este dispositivo no tiene Salud, o la sesión no se pudo abrir.
        case unavailable
    }

    // Lo que dibuja la vista.
    @Published public private(set) var display: WatchDisplay = .idle
    @Published public private(set) var state: WatchWorkoutState = .idle()
    @Published public private(set) var heartRate: Double = 0
    @Published public private(set) var activeCalories: Double = 0
    @Published public private(set) var health: HealthStatus = .idle
    /// Resumen del último entrenamiento cerrado en esta ejecución.
    @Published public private(set) var lastSummary: WatchSummary?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var activeSessionId: String?
    private var sessionStartedAt: Date?
    /// Sesiones ya cerradas aquí (acotado): un estado viejo no debe reabrirlas.
    private var closedSessionIds: [String] = []

    private var haptics = WatchHapticTracker()
    private var ticker: Timer?

    private static let bpm = HKUnit.count().unitDivided(by: .minute())

    private override init() {
        super.init()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    // MARK: - Estado del iPhone

    /// Siempre en el hilo principal.
    func apply(_ newState: WatchWorkoutState) {
        state = newState
        reconcile(now: Date())
        refreshDisplay(now: Date())
    }

    /// Vigente = en curso y no caducado.
    private func isLive(_ s: WatchWorkoutState, at now: Date) -> Bool {
        s.isRunning && !s.isStale(at: now)
    }

    private func tick() {
        let now = Date()
        reconcile(now: now)
        refreshDisplay(now: now)
    }

    private func refreshDisplay(now: Date) {
        let live = isLive(state, at: now)
        let newDisplay = live ? state.display(at: now) : .idle
        if newDisplay != display { display = newDisplay }

        // Un estado caducado cuenta como "sin entrenamiento": sin vibración de fin.
        let events = haptics.update(state: live || !state.isRunning ? state : .idle(), display: newDisplay)
        events.forEach(play)
    }

    /// Alinea la sesión de Salud con el estado del iPhone.
    private func reconcile(now: Date) {
        let live = isLive(state, at: now)

        if let id = activeSessionId {
            if state.sessionId == id {
                if live { syncPause() } else { endSession() }
            } else if live {
                // Llegó otro entrenamiento sin que se viera el fin del anterior.
                endSession()
                startSession(id: state.sessionId)
            }
        } else if live, !closedSessionIds.contains(state.sessionId) {
            startSession(id: state.sessionId)
        }
    }

    private func syncPause() {
        guard let session else { return }
        if state.isPaused, session.state == .running {
            session.pause()
        } else if !state.isPaused, session.state == .paused {
            session.resume()
        }
    }

    // MARK: - Sesión de Salud

    private func startSession(id: String) {
        guard HKHealthStore.isHealthDataAvailable() else {
            health = .unavailable
            // Sin Salud no hay sesión, pero se recuerda el id para no reintentar en cada tick.
            remember(closed: id)
            return
        }
        activeSessionId = id
        sessionStartedAt = Date()
        heartRate = 0
        activeCalories = 0
        health = .requestingAccess

        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.healthStore.requestAuthorization(toShare: share, read: read)
            } catch {
                WatchLog.workout.error("Permiso de Salud falló: \(WatchLog.describe(error), privacy: .public)")
            }
            await MainActor.run { self.openSession(id: id) }
        }
    }

    private func openSession(id: String) {
        // El entrenamiento pudo terminar mientras se mostraba la hoja de permisos.
        guard activeSessionId == id else { return }

        guard healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
            health = .denied
            finishWithoutSession(id: id)
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mixedCardio
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            let start = Date()
            sessionStartedAt = start
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { [weak self] success, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if success {
                        self.health = .active
                        self.syncPause()
                    } else {
                        if let error { WatchLog.workout.error("beginCollection falló: \(WatchLog.describe(error), privacy: .public)") }
                        self.health = .unavailable
                    }
                }
            }
        } catch {
            WatchLog.workout.error("No se pudo crear la sesión de Salud: \(WatchLog.describe(error), privacy: .public)")
            health = .unavailable
            finishWithoutSession(id: id)
        }
    }

    /// Sin sesión de Salud (sin permiso o fallo): se sigue mostrando el cronómetro, pero no se reintenta.
    private func finishWithoutSession(id: String) {
        remember(closed: id)
        activeSessionId = nil
        sessionStartedAt = nil
    }

    private func endSession() {
        guard let id = activeSessionId else { return }
        let started = sessionStartedAt ?? Date()
        let session = self.session
        let builder = self.builder

        activeSessionId = nil
        sessionStartedAt = nil
        self.session = nil
        self.builder = nil
        remember(closed: id)
        health = .idle
        heartRate = 0
        activeCalories = 0

        guard let session, let builder else { return }
        let ended = Date()
        session.end()

        Task {
            var saved = false
            var average: Double?
            var calories: Double?
            do {
                try await builder.endCollection(at: ended)
                average = builder.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: Self.bpm)
                calories = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
                saved = (try await builder.finishWorkout()) != nil
            } catch {
                WatchLog.workout.error("No se pudo cerrar el entrenamiento: \(WatchLog.describe(error), privacy: .public)")
            }
            let summary = WatchSummary(
                sessionId: id, startedAt: started, endedAt: ended,
                averageHeartRate: average, activeCalories: calories, savedToHealth: saved
            )
            await MainActor.run {
                WorkoutManager.shared.lastSummary = summary
                PhoneConnector.shared.send(summary)
            }
        }
    }

    private func remember(closed id: String) {
        closedSessionIds.append(id)
        if closedSessionIds.count > 20 { closedSessionIds.removeFirst(closedSessionIds.count - 20) }
    }

    // MARK: - Hápticos

    private func play(_ event: WatchHapticEvent) {
        let device = WKInterfaceDevice.current()
        switch event {
        case .phaseStart(let kind):
            switch kind {
            case .work: device.play(.start)
            case .rest, .transition: device.play(.stop)
            case .warmup: device.play(.directionUp)
            }
        case .countdown:
            device.play(.click)
        case .finished:
            device.play(.success)
        }
    }

    // MARK: - HKWorkoutSessionDelegate

    public func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}

    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        WatchLog.workout.error("Sesión de Salud con error: \(WatchLog.describe(error), privacy: .public)")
        DispatchQueue.main.async { self.health = .unavailable }
    }

    // MARK: - HKLiveWorkoutBuilderDelegate

    public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        var bpmNow: Double?
        var kcal: Double?
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let stats = workoutBuilder.statistics(for: quantityType)
            switch quantityType {
            case HKQuantityType(.heartRate):
                bpmNow = stats?.mostRecentQuantity()?.doubleValue(for: Self.bpm)
            case HKQuantityType(.activeEnergyBurned):
                kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie())
            default:
                break
            }
        }
        DispatchQueue.main.async {
            if let bpmNow { self.heartRate = bpmNow }
            if let kcal { self.activeCalories = kcal }
        }
    }

    public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
