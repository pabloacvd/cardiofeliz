import XCTest

final class WatchProtocolTests: XCTestCase {

    // MARK: Fixtures

    private func phase(
        _ name: String, _ duration: TimeInterval, order: Int,
        kind: PhaseKind = .work, manual: Bool = false, countsUp: Bool = false
    ) -> WorkoutPhase {
        WorkoutPhase(name: name, duration: duration, order: order, kind: kind, isManual: manual, countsUp: countsUp)
    }

    /// Plan Tabata corto: calentamiento 10 s, trabajo 20 s, descanso 10 s, encadenados desde `t0`.
    private func state(
        id: String = "s1", index: Int = 0, running: Bool = true, paused: Bool = false,
        pausedAt: Date? = nil, sentAt: Date = t0
    ) -> WatchWorkoutState {
        let phases = [
            phase("Calentamiento", 10, order: 0, kind: .warmup),
            phase("Trabajo", 20, order: 1),
            phase("Descanso", 10, order: 2, kind: .rest)
        ]
        let starts = [t0, t0.plus(10), t0.plus(30)]
        let ends = [t0.plus(10), t0.plus(30), t0.plus(40)]
        return WatchWorkoutState(
            sessionId: id, title: "Tabata", phases: phases, startDates: starts, endDates: ends,
            currentPhaseIndex: index, isRunning: running, isPaused: paused, pausedAt: pausedAt, sentAt: sentAt
        )
    }

    // MARK: Codificación

    func testStateRoundTrip() throws {
        let original = state(index: 1, paused: true, pausedAt: t0.plus(12))
        let decoded = try WatchWorkoutState(data: original.encoded())
        XCTAssertEqual(decoded, original)
    }

    func testSummaryRoundTrip() throws {
        let original = WatchSummary(
            sessionId: "s1", startedAt: t0, endedAt: t0.plus(600),
            averageHeartRate: 142.5, activeCalories: 88, savedToHealth: true
        )
        XCTAssertEqual(try WatchSummary(data: original.encoded()), original)
    }

    func testGarbageDataIsRejected() {
        XCTAssertThrowsError(try WatchWorkoutState(data: Data("no es json".utf8)))
        XCTAssertThrowsError(try WatchSummary(data: Data([0, 1, 2])))
    }

    func testCommandsDoNotIncludeStart() {
        XCTAssertFalse(WatchCommand.allCases.map(\.rawValue).contains("start"))
        XCTAssertNil(WatchCommand(rawValue: "start"))
    }

    func testIllFormedStateIsDetected() {
        var s = state()
        s.endDates.removeLast()
        XCTAssertFalse(s.isWellFormed)
        var t = state()
        t.currentPhaseIndex = 9
        XCTAssertFalse(t.isWellFormed)
        XCTAssertTrue(state().isWellFormed)
        XCTAssertTrue(WatchWorkoutState.idle().isWellFormed)
    }

    // MARK: Derivación de fase y tiempo

    func testDisplayDerivesPhaseAndRemainingFromDates() {
        let d = state().display(at: t0.plus(4))
        XCTAssertEqual(d.mode, .running)
        XCTAssertEqual(d.phaseIndex, 0)
        XCTAssertEqual(d.seconds, 6)
        XCTAssertEqual(d.progress, 0.4, accuracy: 0.001)
    }

    func testDisplayAdvancesWhenPhaseEndedWithoutNewState() {
        let d = state().display(at: t0.plus(35))
        XCTAssertEqual(d.phaseIndex, 2)
        XCTAssertEqual(d.phase?.name, "Descanso")
        XCTAssertEqual(d.seconds, 5)
    }

    func testDisplayFinishedAfterLastPhase() {
        let d = state().display(at: t0.plus(41))
        XCTAssertEqual(d.mode, .finished)
        XCTAssertEqual(d.seconds, 0)
    }

    func testPausedDisplayIsFrozenAtPauseInstant() {
        let s = state(index: 1, paused: true, pausedAt: t0.plus(15))
        let early = s.display(at: t0.plus(16))
        let late = s.display(at: t0.plus(500))
        XCTAssertEqual(early.mode, .paused)
        XCTAssertEqual(early.seconds, 15)
        XCTAssertEqual(late.seconds, 15, "En pausa el tiempo no avanza")
        XCTAssertEqual(late.phaseIndex, 1)
    }

    func testNotRunningIsIdle() {
        XCTAssertEqual(WatchWorkoutState.idle().display(at: t0), .idle)
        XCTAssertEqual(WatchWorkoutState.finished(sessionId: "s1", title: "x", sentAt: t0).display(at: t0), .idle)
    }

    func testManualPhaseShowsElapsedAndNeverAutoAdvances() {
        let phases = [phase("Series", 0, order: 0, manual: true), phase("Descanso", 30, order: 1, kind: .rest)]
        let s = WatchWorkoutState(
            sessionId: "m", title: "Manual", phases: phases, startDates: [t0, t0], endDates: [t0, t0.plus(30)],
            currentPhaseIndex: 0, isRunning: true, isPaused: false, pausedAt: nil, sentAt: t0
        )
        let d = s.display(at: t0.plus(95))
        XCTAssertEqual(d.phaseIndex, 0)
        XCTAssertTrue(d.isManual)
        XCTAssertTrue(d.showsElapsed)
        XCTAssertEqual(d.seconds, 95)
        XCTAssertEqual(d.progress, 0)
    }

    func testCountsUpPhaseShowsElapsed() {
        let phases = [phase("For time", 600, order: 0, countsUp: true)]
        let s = WatchWorkoutState(
            sessionId: "f", title: "FT", phases: phases, startDates: [t0], endDates: [t0.plus(600)],
            currentPhaseIndex: 0, isRunning: true, isPaused: false, pausedAt: nil, sentAt: t0
        )
        let d = s.display(at: t0.plus(125))
        XCTAssertTrue(d.showsElapsed)
        XCTAssertEqual(d.seconds, 125)
        XCTAssertNil(d.countdownSecond)
    }

    func testCountdownSecondOnlyInLastThreeSeconds() {
        XCTAssertNil(state().display(at: t0.plus(5)).countdownSecond)
        XCTAssertEqual(state().display(at: t0.plus(7.5)).countdownSecond, 3)
        XCTAssertEqual(state().display(at: t0.plus(9.2)).countdownSecond, 1)
    }

    // MARK: Caducidad (sin sesiones fantasma)

    func testRunningStateStaleOnceKnownEndPassed() {
        let s = state()
        XCTAssertEqual(s.plannedEnd, t0.plus(40))
        XCTAssertFalse(s.isStale(at: t0.plus(45)))
        XCTAssertTrue(s.isStale(at: t0.plus(51)), "Pasado el fin planificado + margen, el iPhone no confirmó")
    }

    func testStaleNeverAppliesToFinishedOrIdle() {
        XCTAssertFalse(WatchWorkoutState.idle().isStale(at: t0.plus(99_999)))
        XCTAssertFalse(WatchWorkoutState.finished(sessionId: "s", title: "t", sentAt: t0).isStale(at: t0.plus(99_999)))
    }

    func testPausedStateStaleOnlyAfterMaxAge() {
        let s = state(index: 1, paused: true, pausedAt: t0.plus(15), sentAt: t0.plus(15))
        XCTAssertFalse(s.isStale(at: t0.plus(60 * 60)))
        XCTAssertTrue(s.isStale(at: t0.plus(15 + WatchWorkoutState.maxAge + 1)))
    }

    func testManualPhaseHasNoKnownEnd() {
        let phases = [phase("Series", 0, order: 0, manual: true)]
        let s = WatchWorkoutState(
            sessionId: "m", title: "M", phases: phases, startDates: [t0], endDates: [t0],
            currentPhaseIndex: 0, isRunning: true, isPaused: false, pausedAt: nil, sentAt: t0
        )
        XCTAssertNil(s.plannedEnd)
        XCTAssertFalse(s.isStale(at: t0.plus(3600)))
        XCTAssertTrue(s.isStale(at: t0.plus(WatchWorkoutState.maxAge + 1)))
    }

    // MARK: Hápticos

    private func feed(_ tracker: inout WatchHapticTracker, _ s: WatchWorkoutState, at offset: TimeInterval) -> [WatchHapticEvent] {
        tracker.update(state: s, display: s.display(at: t0.plus(offset)))
    }

    func testNoHapticWhenJoiningSessionMidway() {
        var tracker = WatchHapticTracker()
        XCTAssertEqual(feed(&tracker, state(index: 1), at: 12), [], "La primera lectura de una sesión es la línea base")
    }

    func testHapticOnPhaseChangeWithKind() {
        var tracker = WatchHapticTracker()
        let s = state()
        _ = feed(&tracker, s, at: 1)
        XCTAssertEqual(feed(&tracker, s, at: 5), [])
        XCTAssertEqual(feed(&tracker, s, at: 10.5), [.phaseStart(.work)])
        XCTAssertEqual(feed(&tracker, s, at: 30.5), [.phaseStart(.rest)])
    }

    func testCountdownTickFiresOncePerSecond() {
        var tracker = WatchHapticTracker()
        let s = state()
        _ = feed(&tracker, s, at: 1)
        XCTAssertEqual(feed(&tracker, s, at: 7.1), [.countdown(3)])
        XCTAssertEqual(feed(&tracker, s, at: 7.4), [], "Mismo segundo, no repite")
        XCTAssertEqual(feed(&tracker, s, at: 8.1), [.countdown(2)])
    }

    func testNoHapticsWhilePaused() {
        var tracker = WatchHapticTracker()
        _ = feed(&tracker, state(), at: 1)
        let paused = state(paused: true, pausedAt: t0.plus(8.2))
        XCTAssertEqual(feed(&tracker, paused, at: 9), [])
        XCTAssertEqual(feed(&tracker, paused, at: 500), [])
    }

    func testFinishedHapticFiresOnceWhenPhoneConfirmsEnd() {
        var tracker = WatchHapticTracker()
        _ = feed(&tracker, state(), at: 1)
        let done = WatchWorkoutState.finished(sessionId: "s1", title: "Tabata", sentAt: t0.plus(20))
        XCTAssertEqual(feed(&tracker, done, at: 20), [.finished])
        XCTAssertEqual(feed(&tracker, done, at: 21), [])
    }

    func testFinishedHapticFiresOnceWhenPlannedTimeRunsOut() {
        var tracker = WatchHapticTracker()
        let s = state()
        _ = feed(&tracker, s, at: 1)
        XCTAssertEqual(feed(&tracker, s, at: 41), [.finished])
        XCTAssertEqual(feed(&tracker, s, at: 42), [])
    }

    func testStaleIdleFromNeverStartedSessionDoesNotVibrate() {
        var tracker = WatchHapticTracker()
        XCTAssertEqual(tracker.update(state: .idle(), display: .idle), [])
        XCTAssertEqual(tracker.update(state: .idle(), display: .idle), [])
    }

    func testNewSessionResetsBaseline() {
        var tracker = WatchHapticTracker()
        _ = feed(&tracker, state(id: "a"), at: 1)
        _ = feed(&tracker, WatchWorkoutState.finished(sessionId: "a", title: "T", sentAt: t0.plus(2)), at: 2)
        XCTAssertEqual(feed(&tracker, state(id: "b", index: 2), at: 31), [], "Sesión nueva: sin vibración de entrada")
    }
}

@MainActor
final class WatchCaloriesTests: XCTestCase {

    private func summary(_ id: String, kcal: Double?, bpm: Double? = 140) -> WatchSummary {
        WatchSummary(sessionId: id, startedAt: t0, endedAt: t0.plus(600), averageHeartRate: bpm, activeCalories: kcal, savedToHealth: true)
    }

    // MARK: WatchSummaryStore

    func testStoreKeepsValidSummary() {
        let store = WatchSummaryStore()
        store.record(summary("a", kcal: 90))
        XCTAssertEqual(store.summaries["a"]?.activeCalories, 90)
        XCTAssertEqual(store.summaries["a"]?.averageHeartRate, 140)
    }

    func testStoreDropsOutOfRangeValuesButKeepsSummary() {
        let store = WatchSummaryStore()
        store.record(summary("a", kcal: -5, bpm: 900))
        store.record(summary("b", kcal: .nan, bpm: .infinity))
        XCTAssertNil(store.summaries["a"]?.activeCalories)
        XCTAssertNil(store.summaries["a"]?.averageHeartRate)
        XCTAssertNil(store.summaries["b"]?.activeCalories)
        XCTAssertNil(store.summaries["b"]?.averageHeartRate)
        XCTAssertNotNil(store.summaries["a"])
    }

    func testStoreIgnoresEmptySessionId() {
        let store = WatchSummaryStore()
        store.record(summary("", kcal: 50))
        XCTAssertTrue(store.summaries.isEmpty)
    }

    func testStoreIsBounded() {
        let store = WatchSummaryStore(limit: 3)
        for i in 0..<6 {
            store.record(WatchSummary(sessionId: "s\(i)", startedAt: t0, endedAt: t0.plus(Double(i)), averageHeartRate: nil, activeCalories: 10, savedToHealth: true))
        }
        XCTAssertEqual(store.summaries.count, 3)
        XCTAssertNotNil(store.summaries["s5"])
        XCTAssertNil(store.summaries["s0"])
    }

    func testStorePersistsAcrossInstances() throws {
        let suite = "cf.test.watchsummaries.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = WatchSummaryStore(defaults: defaults)
        first.record(summary("a", kcal: 90, bpm: 133))

        let second = WatchSummaryStore(defaults: defaults)
        XCTAssertEqual(second.summaries["a"]?.activeCalories, 90)
        XCTAssertEqual(second.summaries["a"]?.averageHeartRate, 133)
    }

    func testStoreRevalidatesPersistedValuesAndIgnoresGarbage() throws {
        let suite = "cf.test.watchsummaries.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let bad = [summary("a", kcal: -5, bpm: 900)]
        defaults.set(try JSONEncoder().encode(bad), forKey: WatchSummaryStore.defaultsKey)
        let store = WatchSummaryStore(defaults: defaults)
        XCTAssertNotNil(store.summaries["a"])
        XCTAssertNil(store.summaries["a"]?.activeCalories)
        XCTAssertNil(store.summaries["a"]?.averageHeartRate)

        defaults.set(Data("no es json".utf8), forKey: WatchSummaryStore.defaultsKey)
        XCTAssertTrue(WatchSummaryStore(defaults: defaults).summaries.isEmpty)
    }

    // MARK: WatchCalories.dayTotal

    func testDayTotalNilWithoutAnyMeasurement() {
        let blocks = [WatchCalories.Block(durationSeconds: 600, sessionId: nil),
                      WatchCalories.Block(durationSeconds: 600, sessionId: "x")]
        XCTAssertNil(WatchCalories.dayTotal(blocks: blocks, summaries: [:], weightKg: 70))
        XCTAssertNil(WatchCalories.dayTotal(blocks: blocks, summaries: ["x": summary("x", kcal: nil)], weightKg: 70))
    }

    func testDayTotalSumsMeasuredBlocks() {
        let blocks = [WatchCalories.Block(durationSeconds: 600, sessionId: "a"),
                      WatchCalories.Block(durationSeconds: 900, sessionId: "b")]
        let total = WatchCalories.dayTotal(
            blocks: blocks, summaries: ["a": summary("a", kcal: 80.4), "b": summary("b", kcal: 120.3)], weightKg: nil
        )
        XCTAssertEqual(total, 201)
    }

    func testDayTotalFallsBackToEstimateForBlocksWithoutWatch() {
        // 8 MET × 70 kg × (1800 s / 3600) = 280 kcal para el bloque sin Watch.
        let blocks = [WatchCalories.Block(durationSeconds: 600, sessionId: "a"),
                      WatchCalories.Block(durationSeconds: 1800, sessionId: nil)]
        let total = WatchCalories.dayTotal(blocks: blocks, summaries: ["a": summary("a", kcal: 100)], weightKg: 70)
        XCTAssertEqual(total, 380)
    }

    func testDayTotalWithoutWeightCountsOnlyMeasured() {
        let blocks = [WatchCalories.Block(durationSeconds: 600, sessionId: "a"),
                      WatchCalories.Block(durationSeconds: 1800, sessionId: nil)]
        XCTAssertEqual(WatchCalories.dayTotal(blocks: blocks, summaries: ["a": summary("a", kcal: 100)], weightKg: nil), 100)
    }

    // MARK: WatchHeartRate.dayAverage

    func testHeartRateAverageIsWeightedByDuration() {
        // (100 × 600 + 160 × 1800) / 2400 = 145
        let blocks = [WatchCalories.Block(durationSeconds: 600, sessionId: "a"),
                      WatchCalories.Block(durationSeconds: 1800, sessionId: "b")]
        let bpm = WatchHeartRate.dayAverage(
            blocks: blocks, summaries: ["a": summary("a", kcal: 1, bpm: 100), "b": summary("b", kcal: 1, bpm: 160)]
        )
        XCTAssertEqual(bpm, 145)
    }

    func testHeartRateAverageIgnoresBlocksWithoutMeasurement() {
        let blocks = [WatchCalories.Block(durationSeconds: 600, sessionId: "a"),
                      WatchCalories.Block(durationSeconds: 9000, sessionId: nil),
                      WatchCalories.Block(durationSeconds: 600, sessionId: "c")]
        let bpm = WatchHeartRate.dayAverage(
            blocks: blocks, summaries: ["a": summary("a", kcal: 1, bpm: 120), "c": summary("c", kcal: 1, bpm: nil)]
        )
        XCTAssertEqual(bpm, 120)
    }

    func testHeartRateAverageNilWithoutAnyMeasurement() {
        let blocks = [WatchCalories.Block(durationSeconds: 600, sessionId: "a")]
        XCTAssertNil(WatchHeartRate.dayAverage(blocks: blocks, summaries: [:]))
        XCTAssertNil(WatchHeartRate.dayAverage(blocks: blocks, summaries: ["a": summary("a", kcal: 5, bpm: nil)]))
        XCTAssertNil(WatchHeartRate.dayAverage(blocks: [], summaries: [:]))
    }

    // MARK: ActivityStore.setMeasuredHealth

    func testSetMeasuredHealthStoresHeartRateAndKeepsCaloriesWhenNil() throws {
        let store = makeStore()
        let saved = try store.addActivity(makeDraft(), options: AddActivityOptions(weightKg: 70))
        let updated = try XCTUnwrap(store.setMeasuredHealth(id: saved.id, kcal: nil, heartRateBpm: 141))
        XCTAssertEqual(updated.avgHeartRateBpm, 141)
        XCTAssertEqual(updated.caloriesKcal, saved.caloriesKcal)
        XCTAssertGreaterThan(store.pendingCount, 0)
    }

    func testSetMeasuredHealthRejectsHeartRateOutsideServerCheck() throws {
        let store = makeStore()
        let saved = try store.addActivity(makeDraft(), options: AddActivityOptions(weightKg: 70))
        XCTAssertNil(store.setMeasuredHealth(id: saved.id, kcal: nil, heartRateBpm: 19))
        XCTAssertNil(store.setMeasuredHealth(id: saved.id, kcal: nil, heartRateBpm: 261))
        XCTAssertNil(store.activities.first?.avgHeartRateBpm)
    }

    func testSetMeasuredHealthSameValuesDoNotRequeue() throws {
        let store = makeStore()
        let saved = try store.addActivity(makeDraft(), options: AddActivityOptions(weightKg: 70))
        store.setMeasuredHealth(id: saved.id, kcal: 90, heartRateBpm: 130)
        let pending = store.pendingCount
        store.setMeasuredHealth(id: saved.id, kcal: 90, heartRateBpm: 130)
        XCTAssertEqual(store.pendingCount, pending)
    }

    func testEditingActivityKeepsHeartRate() throws {
        let store = makeStore()
        let saved = try store.addActivity(makeDraft(), options: AddActivityOptions(weightKg: 70))
        store.setMeasuredHealth(id: saved.id, kcal: nil, heartRateBpm: 150)
        let edited = try XCTUnwrap(store.updateActivity(id: saved.id, patch: { $0.feeling = 4 }))
        XCTAssertEqual(edited.avgHeartRateBpm, 150)
    }

    // MARK: ActivityStore.setMeasuredCalories

    private func makeStore() -> ActivityStore {
        ActivityStore(
            userId: "u1", remote: FakeActivitiesRemote(), store: InMemoryActivityCacheStore(),
            derivation: .withCalories, isOnline: { false }
        )
    }

    func testSetMeasuredCaloriesReplacesEstimateAndQueuesUpload() throws {
        let store = makeStore()
        let saved = try store.addActivity(makeDraft(), options: AddActivityOptions(weightKg: 70))
        XCTAssertNotNil(saved.caloriesKcal, "Con peso hay estimación por MET")

        let updated = store.setMeasuredCalories(id: saved.id, kcal: 123)
        XCTAssertEqual(updated?.caloriesKcal, 123)
        XCTAssertEqual(store.activities.first?.caloriesKcal, 123)
        XCTAssertGreaterThan(store.pendingCount, 0)
    }

    func testSetMeasuredCaloriesKeepsOtherFields() throws {
        let store = makeStore()
        let saved = try store.addActivity(makeDraft(), options: AddActivityOptions(weightKg: 70))
        let updated = try XCTUnwrap(store.setMeasuredCalories(id: saved.id, kcal: 50))
        XCTAssertEqual(updated.durationSeconds, saved.durationSeconds)
        XCTAssertEqual(updated.xpEarned, saved.xpEarned)
        XCTAssertEqual(updated.dayId, saved.dayId)
    }

    func testSetMeasuredCaloriesRejectsBadInput() throws {
        let store = makeStore()
        let saved = try store.addActivity(makeDraft(), options: AddActivityOptions(weightKg: 70))
        XCTAssertNil(store.setMeasuredCalories(id: saved.id, kcal: -1))
        XCTAssertNil(store.setMeasuredCalories(id: saved.id, kcal: .nan))
        XCTAssertNil(store.setMeasuredCalories(id: "no-existe", kcal: 10))
        XCTAssertEqual(store.activities.first?.caloriesKcal, saved.caloriesKcal)
    }

    func testSetMeasuredCaloriesWithSameValueDoesNotRequeue() throws {
        let store = makeStore()
        let saved = try store.addActivity(makeDraft(), options: AddActivityOptions(weightKg: 70))
        store.setMeasuredCalories(id: saved.id, kcal: 77)
        let pending = store.pendingCount
        store.setMeasuredCalories(id: saved.id, kcal: 77)
        XCTAssertEqual(store.pendingCount, pending)
    }

    // MARK: Integración con el view model

    private func dayWithTwoBlocks() throws -> DiaEntrenamiento {
        let rutina = try Fixtures.defaultRoutine()
        var dia = try XCTUnwrap(rutina.diasEntrenamiento.first)
        dia.bloques = Array(dia.bloques.prefix(2))
        return dia
    }

    private func makeViewModel() throws -> WorkoutWorkflowViewModel {
        struct Provider: RoutineProvider {
            let data: RutinaData
            func loadRoutine() throws -> RutinaData { data }
        }
        return WorkoutWorkflowViewModel(routineProvider: Provider(data: try Fixtures.defaultRoutine()))
    }

    func testViewModelAppliesLateSummaryToSavedDay() throws {
        let vm = try makeViewModel()
        let store = makeStore()
        let dia = try dayWithTwoBlocks()
        let today = "2026-03-04"

        vm.handleBlockCompleted(dia: dia, bloque: dia.bloques[0], totalSeconds: 600, rounds: nil, today: today,
                                activityStore: store, weightKg: 70, watchSessionId: "s1")
        XCTAssertTrue(store.activities.isEmpty, "El día no se guarda hasta terminar todos los bloques")

        vm.handleBlockCompleted(dia: dia, bloque: dia.bloques[1], totalSeconds: 600, rounds: nil, today: today,
                                activityStore: store, weightKg: 70, watchSessionId: "s2")
        let estimated = try XCTUnwrap(store.activities.first?.caloriesKcal)

        // El resumen de la última sesión llega después de guardar el día.
        let summaries = ["s1": summary("s1", kcal: 60), "s2": summary("s2", kcal: 70)]
        vm.applyWatchSummaries(summaries, activityStore: store, weightKg: 70)

        XCTAssertEqual(store.activities.first?.caloriesKcal, 130)
        XCTAssertNotEqual(estimated, 130)
    }

    func testViewModelStoresWeightedHeartRateOnSavedDay() throws {
        let vm = try makeViewModel()
        let store = makeStore()
        let dia = try dayWithTwoBlocks()
        let today = "2026-03-04"
        vm.handleBlockCompleted(dia: dia, bloque: dia.bloques[0], totalSeconds: 600, rounds: nil, today: today,
                                activityStore: store, weightKg: 70, watchSessionId: "s1")
        vm.handleBlockCompleted(dia: dia, bloque: dia.bloques[1], totalSeconds: 1800, rounds: nil, today: today,
                                activityStore: store, weightKg: 70, watchSessionId: "s2")
        vm.applyWatchSummaries(["s1": summary("s1", kcal: 60, bpm: 100), "s2": summary("s2", kcal: 70, bpm: 160)],
                               activityStore: store, weightKg: 70)
        XCTAssertEqual(store.activities.first?.avgHeartRateBpm, 145)
    }

    func testSavedDayAndSummarySurviveAppRestart() throws {
        let suite = "cf.test.savedday.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        struct Provider: RoutineProvider {
            let data: RutinaData
            func loadRoutine() throws -> RutinaData { data }
        }
        let provider = Provider(data: try Fixtures.defaultRoutine())
        let store = makeStore()
        let dia = try dayWithTwoBlocks()

        let before = WorkoutWorkflowViewModel(routineProvider: provider, defaults: defaults)
        before.handleBlockCompleted(dia: dia, bloque: dia.bloques[0], totalSeconds: 600, rounds: nil, today: "2026-03-04",
                                    activityStore: store, weightKg: 70, watchSessionId: "s1")
        before.handleBlockCompleted(dia: dia, bloque: dia.bloques[1], totalSeconds: 600, rounds: nil, today: "2026-03-04",
                                    activityStore: store, weightKg: 70, watchSessionId: "s2")

        // La app se reinicia; el resumen llega después y se aplica con un view model nuevo.
        let after = WorkoutWorkflowViewModel(routineProvider: provider, defaults: defaults)
        after.applyWatchSummaries(["s1": summary("s1", kcal: 60, bpm: 120), "s2": summary("s2", kcal: 70, bpm: 140)],
                                  activityStore: store, weightKg: 70)
        XCTAssertEqual(store.activities.first?.caloriesKcal, 130)
        XCTAssertEqual(store.activities.first?.avgHeartRateBpm, 130)
    }

    func testViewModelKeepsEstimateWithoutWatch() throws {
        let vm = try makeViewModel()
        let store = makeStore()
        let dia = try dayWithTwoBlocks()
        for b in dia.bloques {
            vm.handleBlockCompleted(dia: dia, bloque: b, totalSeconds: 600, rounds: nil, today: "2026-03-04",
                                    activityStore: store, weightKg: 70)
        }
        let estimated = store.activities.first?.caloriesKcal
        vm.applyWatchSummaries([:], activityStore: store, weightKg: 70)
        XCTAssertNotNil(estimated)
        XCTAssertEqual(store.activities.first?.caloriesKcal, estimated)
    }

    func testViewModelKeepsSessionWhenBlockReportsTwice() throws {
        let vm = try makeViewModel()
        let store = makeStore()
        let dia = try dayWithTwoBlocks()
        let b0 = dia.bloques[0]
        vm.handleBlockCompleted(dia: dia, bloque: b0, totalSeconds: 600, rounds: nil, today: "2026-03-04",
                                activityStore: store, weightKg: 70, watchSessionId: "s1")
        // Segundo aviso del mismo bloque (botón tras el fin del reloj): ya no trae sesión.
        vm.handleBlockCompleted(dia: dia, bloque: b0, totalSeconds: 600, rounds: nil, today: "2026-03-04",
                                activityStore: store, weightKg: 70)
        let key = WorkoutDayProgress.blockKey(diaId: dia.id, blockId: try XCTUnwrap(b0.id))
        XCTAssertEqual(vm.blockProgress[key]?.watchSessionId, "s1")
    }
}
