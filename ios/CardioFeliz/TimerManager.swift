import Foundation
import Combine
import ActivityKit

/// Capa de efectos sobre `WorkoutClock`: sonido y voz, notificaciones de respaldo, Live Activity
/// y Watch. La lógica de tiempo (fases, pausa, salto) vive en `WorkoutClock`; aquí solo se
/// traducen sus `ClockEvent` a efectos y se publica el estado para SwiftUI.
///
/// Segundo plano: mientras corre un entrenamiento, `SoundManager` mantiene la sesión de audio viva
/// (bucle de silencio) y los tonos se programan con antelación a su hora exacta
/// (`AudioCuePlanner`). Las notificaciones locales son el respaldo si iOS aun así suspende la app.
public class TimerManager: ObservableObject {
    @Published public var phases: [WorkoutPhase] = []
    @Published public var phaseStartDates: [Date] = []
    @Published public var phaseEndDates: [Date] = []
    @Published public var currentPhaseIndex: Int = 0
    @Published public var isPaused: Bool = false
    @Published public var isRunning: Bool = false
    @Published public var totalDuration: TimeInterval = 60
    /// Resultado del último entrenamiento terminado (completado o cortado). nil mientras corre.
    @Published public var lastResult: WorkoutResult?

    public private(set) var clock: WorkoutClock

    private var timer: AnyCancellable?
    private var workoutActivity: Activity<WorkoutAttributes>?
    /// El motor de audio tiene programados los tonos futuros: los ticks del reloj no deben
    /// reproducirlos de nuevo.
    private var audioScheduled = false

    /// El único `TimerManager` con un entrenamiento en curso. Recibe los comandos de la Live Activity.
    private static weak var active: TimerManager?

    /// Identifica el entrenamiento ante el Watch (una `HKWorkoutSession` por id). Nuevo en cada `start()`.
    public private(set) var watchSessionId: String?
    /// Id de sesión del último entrenamiento iniciado, hasta que la pantalla de bloque lo recoja con
    /// `takeLastWatchSessionId()` para asociar las calorías medidas por el Watch al bloque.
    private static var lastWatchSessionId: String?

    /// Devuelve y olvida el id de la última sesión iniciada; nil si no se inició ninguna desde la última vez.
    public static func takeLastWatchSessionId() -> String? {
        defer { lastWatchSessionId = nil }
        return lastWatchSessionId
    }

    /// Olvida el id pendiente (al abrir un bloque nuevo, para no heredar el de otro).
    public static func discardLastWatchSessionId() {
        lastWatchSessionId = nil
    }

    public var onPhaseChange: ((Int) -> Void)?
    public var onTimerEnd: (() -> Void)?

    public init(plan: WorkoutPlan = .prototype) {
        self.clock = WorkoutClock(plan: plan)
        self.phases = plan.phases
        self.totalDuration = plan.plannedDuration ?? 0
    }

    deinit {
        // La vista se fue con el entrenamiento en marcha: no dejar tonos, avisos ni Live Activity huérfanos.
        // `active` es débil y ya vale nil para este objeto; si vale otro, es de un entrenamiento posterior
        // y no se toca.
        if clock.isActive, Self.active == nil {
            Self.tearDownSystemEffects()
            if let id = watchSessionId {
                WatchConnector.shared.commandHandler = nil
                WatchConnector.shared.send(.finished(sessionId: id, title: clock.plan.title, sentAt: Date()))
            }
        }
    }

    /// Cambia el plan. Ignorado mientras hay un entrenamiento en curso.
    public func load(plan: WorkoutPlan) {
        guard !clock.isActive else { return }
        clock = WorkoutClock(plan: plan)
        phases = plan.phases
        totalDuration = plan.plannedDuration ?? 0
        lastResult = nil
    }

    /// Envía al Watch el estado completo con fechas absolutas. Tras `.finished` manda el estado
    /// "terminado" de esta sesión, para que el Watch cierre exactamente su sesión de Salud.
    private func syncWithWatch() {
        guard let id = watchSessionId else { return }
        let now = Date()
        guard clock.isActive else {
            WatchConnector.shared.send(.finished(sessionId: id, title: clock.plan.title, sentAt: now))
            return
        }
        WatchConnector.shared.send(WatchWorkoutState(
            sessionId: id,
            title: clock.plan.title,
            phases: clock.plan.phases,
            startDates: clock.startDates,
            endDates: clock.endDates,
            currentPhaseIndex: clock.currentIndex,
            isRunning: true,
            isPaused: clock.state == .paused,
            pausedAt: clock.pausedAt,
            sentAt: now
        ))
    }

    /// Comando del Watch. Devuelve si se aplicó; un comando que no corresponde al estado actual se rechaza
    /// (p. ej. "pausar" cuando ya está en pausa).
    private func handle(watch command: WatchCommand) -> Bool {
        switch (command, clock.state) {
        case (.pause, .running): pause()
        case (.resume, .paused): resume()
        case (.next, .running), (.next, .paused): next()
        case (.stop, .running), (.stop, .paused): stop()
        default: return false
        }
        return true
    }

    // MARK: - Controles

    public func start() {
        guard !clock.isActive else { return }
        lastResult = nil
        let id = UUID().uuidString
        watchSessionId = id
        Self.lastWatchSessionId = id
        process(clock.start(), at: Date(), fromTick: false)
    }

    public func pause() {
        let now = Date()
        process(clock.pause(at: now), at: now, fromTick: false)
    }

    public func resume() {
        let now = Date()
        process(clock.resume(at: now), at: now, fromTick: false)
    }

    /// Salta a la siguiente fase; en la última, completa el entrenamiento.
    public func next() {
        let now = Date()
        process(clock.next(at: now), at: now, fromTick: false)
    }

    /// Detiene el entrenamiento antes de tiempo.
    public func stop() {
        let now = Date()
        process(clock.finish(at: now), at: now, fromTick: false)
    }

    /// Comandos de la Live Activity (App Intents).
    private func handle(_ command: WorkoutCommand) {
        switch command {
        case .pause: pause()
        case .resume: resume()
        case .next: next()
        }
    }

    // MARK: - Ticks

    private func startObservingTicks() {
        timer?.cancel()
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self else { return }
                self.process(self.clock.tick(at: now), at: now, fromTick: true)
            }
    }

    private func stopObservingTicks() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Eventos del reloj → efectos

    /// - Parameter fromTick: los eventos vienen del paso del tiempo y no de una acción del usuario.
    ///   Si el motor de audio tiene los tonos programados, ya sonaron a su hora: no se repiten.
    private func process(_ events: [ClockEvent], at now: Date, fromTick: Bool) {
        guard !events.isEmpty else { return }
        publishState()

        let toneAlreadyScheduled = fromTick && audioScheduled

        // Si al volver de segundo plano se saltaron varias fases, solo se anuncia la última.
        let lastPhaseChange = events.lastIndex { if case .phaseChanged = $0 { return true } else { return false } }

        for (i, event) in events.enumerated() {
            switch event {
            case .started:
                Self.active = self
                WorkoutCommandBus.shared.handler = { [weak self] command in self?.handle(command) }
                WatchConnector.shared.commandHandler = { [weak self] command in self?.handle(watch: command) ?? false }
                SoundManager.shared.onAudioChanged = { [weak self] in self?.scheduleAudio() }
                SoundManager.shared.beginWorkoutAudio()
                NotificationManager.shared.requestAuthorization()
                scheduleNotifications()
                startLiveActivity()
                SoundManager.shared.speak("Iniciando entrenamiento. Primera fase: \(phases[0].name)")
                SoundManager.shared.playGo()
                scheduleAudio()
                syncWithWatch()
                startObservingTicks()

            case .paused:
                SoundManager.shared.cancelScheduledCues()
                audioScheduled = false
                NotificationManager.shared.cancelAllNotifications()
                updateLiveActivity()
                SoundManager.shared.playBeep()
                SoundManager.shared.speak("Entrenamiento pausado")
                syncWithWatch()
                stopObservingTicks()

            case .resumed:
                scheduleNotifications()
                scheduleAudio()
                updateLiveActivity()
                SoundManager.shared.playGo()
                SoundManager.shared.speak("Continuando, fase actual: \(phases[currentPhaseIndex].name)")
                syncWithWatch()
                startObservingTicks()

            case .phaseChanged(let from, let to, let cause):
                guard i == lastPhaseChange else { continue }
                // La app está viva y ya anunció el cambio: el aviso de respaldo sobra.
                NotificationManager.shared.cancel(
                    identifiers: ((from + 1)...to).map { NotificationPlanner.phaseStartIdentifier($0) }
                )
                if cause == .user {
                    scheduleNotifications()
                    scheduleAudio()
                }
                updateLiveActivity()
                if !toneAlreadyScheduled {
                    SoundManager.shared.playCue(phases[to].startCue)
                }
                SoundManager.shared.vibrate()
                SoundManager.shared.speak(
                    cause == .user ? "Siguiente fase: \(phases[to].name)" : "Cambio de fase: \(phases[to].name)"
                )
                syncWithWatch()
                onPhaseChange?(to)

            case .countdownTick:
                if !toneAlreadyScheduled {
                    SoundManager.shared.playCountdownTick()
                }

            case .finished:
                lastResult = clock.result
                NotificationManager.shared.cancelAllNotifications()
                endLiveActivity()
                if !toneAlreadyScheduled {
                    SoundManager.shared.playVictory()
                }
                SoundManager.shared.vibrate()
                SoundManager.shared.speak("Entrenamiento terminado. Buen trabajo")
                // Con la fanfarria ya programada para el fin, cancelarla la cortaría a medias.
                SoundManager.shared.endWorkoutAudio(cancelScheduled: !toneAlreadyScheduled)
                SoundManager.shared.onAudioChanged = nil
                audioScheduled = false
                if Self.active === self {
                    WorkoutCommandBus.shared.handler = nil
                    WatchConnector.shared.commandHandler = nil
                    Self.active = nil
                }
                resetPublishedState()
                syncWithWatch()
                stopObservingTicks()
                onTimerEnd?()
            }
        }
    }

    private func publishState() {
        phases = clock.plan.phases
        phaseStartDates = clock.startDates
        phaseEndDates = clock.endDates
        currentPhaseIndex = clock.currentIndex
        isPaused = clock.state == .paused
        isRunning = clock.isActive
    }

    /// Mismo estado "en reposo" que dejaba el prototipo al detenerse.
    private func resetPublishedState() {
        isRunning = false
        isPaused = false
        currentPhaseIndex = 0
        phaseStartDates = []
        phaseEndDates = []
    }

    // MARK: - Consultas de UI

    public func timeRemainingInCurrentPhase(at now: Date = Date()) -> TimeInterval {
        clock.timeRemainingInCurrentPhase(at: now) ?? 0
    }

    public func progressInCurrentPhase(at now: Date = Date()) -> Double {
        clock.progressInCurrentPhase(at: now)
    }

    // MARK: - Audio programado

    /// Programa en el motor de audio los tonos futuros a su hora exacta. Se vuelve a llamar cada vez
    /// que las fechas cambian (reanudar, saltar fase) o el audio se recupera de una interrupción.
    private func scheduleAudio() {
        guard clock.state == .running else {
            SoundManager.shared.cancelScheduledCues()
            audioScheduled = false
            return
        }
        let cues = AudioCuePlanner.cues(for: clock, after: Date())
        audioScheduled = SoundManager.shared.scheduleCues(cues)
    }

    // MARK: - Notificaciones de respaldo

    /// Agenda avisos solo hasta donde las fechas son reales. Una fase manual no tiene fin conocido:
    /// su inicio sí es fiable (lo fija la fase anterior), pero nada posterior lo es.
    private func scheduleNotifications() {
        let all = clock.plan.phases
        let from = clock.currentIndex
        guard from < all.count else { return }

        var end = from
        var reachesEnd = true
        for i in from..<all.count {
            end = i
            if all[i].isManual {
                reachesEnd = false
                break
            }
        }
        // Si la fase en curso ya es manual, no hay nada fiable que agendar.
        if all[from].isManual {
            NotificationManager.shared.cancelAllNotifications()
            return
        }
        let range = 0...end
        NotificationManager.shared.scheduleWorkoutNotifications(
            phases: Array(all[range]),
            startDates: Array(clock.startDates[range]),
            endDates: Array(clock.endDates[range]),
            notifyCompletion: reachesEnd
        )
    }

    // MARK: - Live Activity Lifecycle

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLog.workout.info("Live Activities no habilitadas")
            return
        }
        guard let initialState = LiveActivityStateBuilder.state(for: clock) else { return }

        let attributes = WorkoutAttributes(workoutName: clock.plan.title)
        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            let activity = try Activity.request(attributes: attributes, content: content)
            workoutActivity = activity
            // Una actividad de un entrenamiento anterior (app cerrada a la fuerza) no debe quedar duplicada.
            Self.endActivities(except: activity.id)
        } catch {
            AppLog.workout.error("No se pudo iniciar la Live Activity: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// Solo se actualiza en cambios de fase, pausa y reanudación. Entre medias el contador avanza
    /// solo (`Text(timerInterval:)`).
    private func updateLiveActivity() {
        guard let activity = workoutActivity,
              let state = LiveActivityStateBuilder.state(for: clock) else { return }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func endLiveActivity() {
        guard let activity = workoutActivity else { return }
        workoutActivity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func endActivities(except keepID: String?) {
        let others = Activity<WorkoutAttributes>.activities.filter { $0.id != keepID }
        guard !others.isEmpty else { return }
        Task {
            for activity in others {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Cierra Live Activities que quedaron de una ejecución anterior (cierre forzado de la app).
    /// Se llama al lanzar la app, cuando seguro no hay un entrenamiento en memoria.
    public static func endOrphanedLiveActivities() {
        endActivities(except: nil)
    }

    private static func tearDownSystemEffects() {
        NotificationManager.shared.cancelAllNotifications()
        SoundManager.shared.endWorkoutAudio(cancelScheduled: true)
        SoundManager.shared.onAudioChanged = nil
        WorkoutCommandBus.shared.handler = nil
        endActivities(except: nil)
    }
}
