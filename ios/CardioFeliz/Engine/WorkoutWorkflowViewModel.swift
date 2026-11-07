import Foundation
import SwiftUI
import Combine

enum WorkoutDestination: Equatable {
    case home
    case dayDetail(DiaEntrenamiento)
    case warmup(DiaEntrenamiento)
    case blockDetail(DiaEntrenamiento, Bloque)
    case activeWorkout(DiaEntrenamiento, Bloque)
    case routineEditor
    case analytics
}

struct WorkoutCompleteModalData: Equatable, Identifiable {
    var id: String { bloque.id ?? bloque.nombre }
    var bloque: Bloque
    var totalSeconds: Int
    var rounds: Int?
    var isDayFinished: Bool
    var hasNextBlock: Bool
    var nextBlock: Bloque?
    /// Sesión del Apple Watch del bloque; el modal muestra su resumen cuando llega.
    var watchSessionId: String?
    var dayResult: LogOutcome?
    var mascotStage: Int

    init(
        bloque: Bloque,
        totalSeconds: Int,
        rounds: Int? = nil,
        isDayFinished: Bool,
        hasNextBlock: Bool,
        nextBlock: Bloque? = nil,
        watchSessionId: String? = nil,
        dayResult: LogOutcome? = nil,
        mascotStage: Int = 1
    ) {
        self.bloque = bloque
        self.totalSeconds = totalSeconds
        self.rounds = rounds
        self.isDayFinished = isDayFinished
        self.hasNextBlock = hasNextBlock
        self.nextBlock = nextBlock
        self.watchSessionId = watchSessionId
        self.dayResult = dayResult
        self.mascotStage = mascotStage
    }
}

@MainActor
final class WorkoutWorkflowViewModel: ObservableObject {
    @Published private(set) var rutina: RutinaData
    @Published var destination: WorkoutDestination = .home
    @Published var completedModalData: WorkoutCompleteModalData?
    @Published private(set) var blockProgress: [String: BlockProgressEntry] = [:]
    /// Día ya guardado como actividad: sirve para ajustar sus calorías y su pulso cuando llega el resumen del
    /// Watch. Se persiste (con `defaults`) para que un reinicio de la app no deje el resumen sin actividad.
    private var savedDays: [String: SavedDay] = [:]
    private let defaults: UserDefaults?
    static let savedDaysKey = "cf.watch.savedDays.v1"
    private static let savedDaysLimit = 10
    private static let savedDaysMaxAge: TimeInterval = 48 * 3600

    private struct SavedDay: Codable {
        var activityId: String
        var blocks: [WatchCalories.Block]
        var savedAt: Date
    }
    @Published var isIdleTimerDisabled: Bool = false {
        didSet {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = isIdleTimerDisabled
            #endif
        }
    }

    private let routineProvider: RoutineProvider

    init(routineProvider: RoutineProvider = BundledRoutineProvider(), defaults: UserDefaults? = nil) {
        self.routineProvider = routineProvider
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.savedDaysKey),
           let stored = try? JSONDecoder().decode([String: SavedDay].self, from: data) {
            // El resumen llega a los pocos minutos de terminar; un día más viejo ya no espera ninguno.
            self.savedDays = stored.filter { Date().timeIntervalSince($0.value.savedAt) < Self.savedDaysMaxAge }
        }
        do {
            self.rutina = try routineProvider.loadRoutine()
        } catch {
            AppLog.data.error("Error al cargar la rutina por defecto: \(error.localizedDescription)")
            self.rutina = RutinaData(
                usuario: "Usuario",
                edad: 30,
                objetivo: "Cardio",
                diasEntrenamiento: []
            )
        }
    }

    func reloadRoutine() {
        if let reloaded = try? routineProvider.loadRoutine() {
            self.rutina = reloaded
        }
    }

    func setRoutine(_ newRoutine: RutinaData) {
        self.rutina = newRoutine
    }

    func openRoutineEditor() {
        destination = .routineEditor
        isIdleTimerDisabled = false
    }

    func isBlockCompleted(diaId: String, blockId: String?) -> Bool {
        guard let blockId else { return false }
        return blockProgress[WorkoutDayProgress.blockKey(diaId: diaId, blockId: blockId)] != nil
    }

    func selectDay(_ dia: DiaEntrenamiento) {
        destination = .dayDetail(dia)
        isIdleTimerDisabled = true
    }

    func startWarmup(for dia: DiaEntrenamiento) {
        destination = .warmup(dia)
        isIdleTimerDisabled = true
    }

    func showBlockDetail(dia: DiaEntrenamiento, bloque: Bloque) {
        destination = .blockDetail(dia, bloque)
        isIdleTimerDisabled = true
    }

    func startActiveWorkout(dia: DiaEntrenamiento, bloque: Bloque) {
        destination = .activeWorkout(dia, bloque)
        isIdleTimerDisabled = true
    }

    func exitActiveWorkout(to dia: DiaEntrenamiento) {
        destination = .dayDetail(dia)
    }

    func goHome() {
        destination = .home
        isIdleTimerDisabled = false
    }

    func handleBlockCompleted(
        dia: DiaEntrenamiento,
        bloque: Bloque,
        totalSeconds: Int,
        rounds: Int?,
        today: String = ActivityValidation.localDay(Date()),
        activityStore: ActivityStore?,
        weightKg: Double?,
        watchSessionId: String? = nil,
        watchSummaries: [String: WatchSummary] = [:]
    ) {
        // Un bloque puede notificar su fin dos veces (fin del reloj y botón); la segunda no trae sesión.
        var sessionId = watchSessionId
        if let blockId = bloque.id {
            let key = WorkoutDayProgress.blockKey(diaId: dia.id, blockId: blockId)
            sessionId = watchSessionId ?? blockProgress[key]?.watchSessionId
            let entry = BlockProgressEntry(
                date: today,
                completedAt: Date(),
                durationSeconds: totalSeconds,
                rounds: rounds,
                tipoBloque: bloque.tipo,
                bloqueNombre: bloque.nombre,
                watchSessionId: sessionId
            )
            blockProgress[key] = entry
        }

        let dayFinished = WorkoutDayProgress.isDayFinished(dia: dia, progress: blockProgress)

        var dayResult: LogOutcome? = nil
        var stage = 1

        if dayFinished, let activityStore {
            let alreadySavedToday = activityStore.activities.contains {
                $0.type == .workoutDay && $0.dayId == dia.id && $0.occurredOn == today
            }
            let beforeCtx = GameContext(
                activities: activityStore.activities,
                vacations: [],
                today: today,
                weightKg: weightKg
            )
            let lvl = GameLevels.levelFromXp(GameXp.computeXp(ctx: beforeCtx).total).level
            stage = GameLevels.mascotStage(lvl).stage

            if !alreadySavedToday {
                let draft = WorkoutDayProgress.buildWorkoutDayActivity(dia: dia, progress: blockProgress, today: today)
                do {
                    let saved = try activityStore.addActivity(draft, options: AddActivityOptions(weightKg: weightKg))
                    savedDays[dia.id] = SavedDay(
                        activityId: saved.id,
                        blocks: WorkoutDayProgress.watchBlocks(dia: dia, progress: blockProgress),
                        savedAt: Date()
                    )
                    persistSavedDays()
                    let afterCtx = GameOutcome.withActivity(ctx: beforeCtx, activity: saved)
                    let outcome = GameOutcome.logOutcome(before: beforeCtx, after: afterCtx)
                    dayResult = outcome
                    let rawIds = outcome.newAchievements.map { $0.id }
                    ToastManager.shared.push(outcome: outcome, claimedIds: rawIds)
                } catch {
                    AppLog.data.error("addActivity failed: \(ErrorSummary.describe(error), privacy: .public)")
                }
            }
        }
        applyWatchSummaries(watchSummaries, activityStore: activityStore, weightKg: weightKg)

        let currentIndex = dia.bloques.firstIndex { $0.id == bloque.id } ?? -1
        let hasNext = currentIndex >= 0 && currentIndex < dia.bloques.count - 1
        let nextBlock = hasNext ? dia.bloques[currentIndex + 1] : nil

        completedModalData = WorkoutCompleteModalData(
            bloque: bloque,
            totalSeconds: totalSeconds,
            rounds: rounds,
            isDayFinished: dayFinished,
            hasNextBlock: hasNext,
            nextBlock: nextBlock,
            watchSessionId: sessionId,
            dayResult: dayResult,
            mascotStage: stage
        )
    }

    /// Sustituye la estimación por MET por las calorías medidas por el Watch y guarda el pulso medio en los días ya guardados.
    /// El resumen de la última sesión llega después de que el día se guarda, así que se llama también cada
    /// vez que entra un resumen nuevo.
    func applyWatchSummaries(_ summaries: [String: WatchSummary], activityStore: ActivityStore?, weightKg: Double?) {
        guard let activityStore, !summaries.isEmpty else { return }
        for (_, saved) in savedDays {
            let kcal = WatchCalories.dayTotal(blocks: saved.blocks, summaries: summaries, weightKg: weightKg)
            let bpm = WatchHeartRate.dayAverage(blocks: saved.blocks, summaries: summaries)
            guard kcal != nil || bpm != nil else { continue }
            activityStore.setMeasuredHealth(id: saved.activityId, kcal: kcal, heartRateBpm: bpm)
        }
    }

    private func persistSavedDays() {
        guard let defaults else { return }
        if savedDays.count > Self.savedDaysLimit {
            let oldest = savedDays.sorted { $0.value.savedAt < $1.value.savedAt }.prefix(savedDays.count - Self.savedDaysLimit)
            for (key, _) in oldest { savedDays.removeValue(forKey: key) }
        }
        if let data = try? JSONEncoder().encode(savedDays) {
            defaults.set(data, forKey: Self.savedDaysKey)
        }
    }

    func proceedToNextBlock(dia: DiaEntrenamiento) {
        guard let modal = completedModalData, let next = modal.nextBlock else {
            completedModalData = nil
            destination = .dayDetail(dia)
            return
        }
        completedModalData = nil
        destination = .blockDetail(dia, next)
    }

    func dismissCompleteModal(dia: DiaEntrenamiento) {
        completedModalData = nil
        destination = .dayDetail(dia)
    }

    func openAnalytics() {
        destination = .analytics
        isIdleTimerDisabled = false
    }
}
