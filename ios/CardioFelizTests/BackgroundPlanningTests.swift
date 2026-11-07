import XCTest

final class BackgroundPlanningTests: XCTestCase {

    // 3 fases: 20 s con cue .none, 10 s con cue .go, 10 s con cue .rest.
    private func plan(manualLast: Bool = false) -> WorkoutPlan {
        WorkoutPlan(title: "Test", phases: [
            WorkoutPhase(name: "A", duration: 20, order: 0, startCue: .none),
            WorkoutPhase(name: "B", duration: 10, order: 1, startCue: .go),
            WorkoutPhase(name: "C", duration: manualLast ? 0 : 10, order: 2, kind: .rest,
                         isManual: manualLast, startCue: .rest),
        ])
    }

    private func runningClock(_ plan: WorkoutPlan) -> WorkoutClock {
        var clock = WorkoutClock(plan: plan)
        clock.start(at: t0)
        return clock
    }

    // MARK: AudioCuePlanner

    func testCuesCoverTicksPhaseStartsAndVictory() {
        let cues = AudioCuePlanner.cues(for: runningClock(plan()), after: t0)
        let expected: [ScheduledCue] = [
            .init(date: t0.plus(17), kind: .tick), .init(date: t0.plus(18), kind: .tick), .init(date: t0.plus(19), kind: .tick),
            .init(date: t0.plus(20), kind: .go),
            .init(date: t0.plus(27), kind: .tick), .init(date: t0.plus(28), kind: .tick), .init(date: t0.plus(29), kind: .tick),
            .init(date: t0.plus(30), kind: .rest),
            .init(date: t0.plus(37), kind: .tick), .init(date: t0.plus(38), kind: .tick), .init(date: t0.plus(39), kind: .tick),
            .init(date: t0.plus(40), kind: .victory),
        ]
        XCTAssertEqual(cues, expected)
    }

    func testCuesAreChronologicalAndStrictlyInTheFuture() {
        let now = t0.plus(18)
        let cues = AudioCuePlanner.cues(for: runningClock(plan()), after: now)
        XCTAssertEqual(cues, cues.sorted { $0.date < $1.date })
        XCTAssertTrue(cues.allSatisfy { $0.date > now })
        XCTAssertEqual(cues.first, .init(date: t0.plus(19), kind: .tick))
    }

    func testCuesStopAtFirstManualPhaseAndOmitVictory() {
        let cues = AudioCuePlanner.cues(for: runningClock(plan(manualLast: true)), after: t0)
        // El inicio de la fase manual es fiable (lo fija la fase anterior); no hay ticks ni fanfarria después.
        XCTAssertEqual(cues.last, .init(date: t0.plus(30), kind: .rest))
        XCTAssertFalse(cues.contains { $0.kind == .victory })
    }

    func testCuesEmptyWhenNotRunning() {
        var clock = runningClock(plan())
        clock.pause(at: t0.plus(5))
        XCTAssertTrue(AudioCuePlanner.cues(for: clock, after: t0.plus(5)).isEmpty)
        XCTAssertTrue(AudioCuePlanner.cues(for: WorkoutClock(plan: plan()), after: t0).isEmpty)
    }

    func testCuesAfterUserSkipUseShiftedDates() {
        var clock = runningClock(plan())
        clock.next(at: t0.plus(5)) // B empieza a t0+5, termina a t0+15
        let cues = AudioCuePlanner.cues(for: clock, after: t0.plus(5))
        XCTAssertEqual(cues.first, .init(date: t0.plus(12), kind: .tick))
        XCTAssertEqual(cues.last, .init(date: t0.plus(25), kind: .victory))
    }

    func testShortPhaseSkipsTicksNotShorterThanItsDuration() {
        let p = WorkoutPlan(title: "T", phases: [WorkoutPhase(name: "x", duration: 2, order: 0)])
        let cues = AudioCuePlanner.cues(for: runningClock(p), after: t0)
        // Como WorkoutClock.tick: solo el tic 1 (el 2 y el 3 no son menores que la duración 2).
        XCTAssertEqual(cues.filter { $0.kind == .tick }.map(\.date), [t0.plus(1)])
    }

    // MARK: NotificationPlanner

    func testNotificationsAreDelayedByBackupGrace() {
        let c = runningClock(plan())
        let list = NotificationPlanner.plan(phases: c.plan.phases, startDates: c.startDates, endDates: c.endDates,
                                            notifyCompletion: true, now: t0)
        XCTAssertEqual(list.map(\.identifier), ["cf_phase_start_1", "cf_phase_start_2", "cf_workout_finished"])
        XCTAssertEqual(list[0].fireDate, t0.plus(20 + NotificationPlanner.backupGrace))
        XCTAssertEqual(list[2].fireDate, t0.plus(40 + NotificationPlanner.backupGrace))
    }

    func testNotificationsSkipPastAndOptionalCompletion() {
        let c = runningClock(plan())
        let list = NotificationPlanner.plan(phases: c.plan.phases, startDates: c.startDates, endDates: c.endDates,
                                            notifyCompletion: false, now: t0.plus(25))
        XCTAssertEqual(list.map(\.identifier), ["cf_phase_start_2"])
    }

    func testNotificationsRejectMismatchedArrays() {
        let c = runningClock(plan())
        XCTAssertTrue(NotificationPlanner.plan(phases: c.plan.phases, startDates: [], endDates: c.endDates,
                                               notifyCompletion: true, now: t0).isEmpty)
    }

    func testNotificationsRespectSystemLimit() {
        let phases = (0..<100).map { WorkoutPhase(name: "F\($0)", duration: 10, order: $0) }
        var clock = WorkoutClock(plan: WorkoutPlan(title: "Largo", phases: phases))
        clock.start(at: t0)
        let list = NotificationPlanner.plan(phases: phases, startDates: clock.startDates, endDates: clock.endDates,
                                            notifyCompletion: true, now: t0)
        XCTAssertEqual(list.count, NotificationPlanner.maxPending)
        XCTAssertEqual(list.first?.identifier, "cf_phase_start_1") // se conservan las más próximas
    }

    // MARK: LiveActivityStateBuilder

    func testStateForRunningTimedPhase() throws {
        let clock = runningClock(plan())
        let s = try XCTUnwrap(LiveActivityStateBuilder.state(for: clock, now: t0.plus(3)))
        XCTAssertEqual(s.phaseName, "A")
        XCTAssertEqual(s.phaseOrder, 0)
        XCTAssertEqual(s.totalPhases, 3)
        XCTAssertEqual(s.currentPhaseStartDate, t0)
        XCTAssertEqual(s.currentPhaseEndDate, t0.plus(20))
        XCTAssertFalse(s.isPaused)
        XCTAssertFalse(s.isManual)
        XCTAssertNil(s.frozenSeconds)
        XCTAssertEqual(LiveActivityStateBuilder.staleDate(for: s), t0.plus(22))
    }

    func testStateWhenPausedFreezesRemainingSeconds() throws {
        var clock = runningClock(plan())
        clock.pause(at: t0.plus(5))
        let s = try XCTUnwrap(LiveActivityStateBuilder.state(for: clock, now: t0.plus(60)))
        XCTAssertTrue(s.isPaused)
        XCTAssertEqual(try XCTUnwrap(s.frozenSeconds), 15, accuracy: 0.001)
        XCTAssertNil(LiveActivityStateBuilder.staleDate(for: s))
    }

    func testStateForManualPhaseIsFlaggedAndFreezesElapsed() throws {
        var clock = runningClock(plan(manualLast: true))
        clock.next(at: t0.plus(5))
        clock.next(at: t0.plus(8)) // fase manual C empieza a t0+8
        var s = try XCTUnwrap(LiveActivityStateBuilder.state(for: clock, now: t0.plus(10)))
        XCTAssertTrue(s.isManual)
        XCTAssertEqual(s.currentPhaseStartDate, s.currentPhaseEndDate)
        XCTAssertNil(LiveActivityStateBuilder.staleDate(for: s))

        clock.pause(at: t0.plus(12))
        s = try XCTUnwrap(LiveActivityStateBuilder.state(for: clock, now: t0.plus(30)))
        XCTAssertEqual(try XCTUnwrap(s.frozenSeconds), 4, accuracy: 0.001) // transcurrido, no restante
    }

    func testStateForCountsUpPhase() throws {
        let p = WorkoutPlan(title: "FT", phases: [WorkoutPhase(name: "For time", duration: 600, order: 0, countsUp: true)])
        var clock = runningClock(p)
        XCTAssertEqual(try XCTUnwrap(LiveActivityStateBuilder.state(for: clock, now: t0)).countsUp, true)
        clock.pause(at: t0.plus(90))
        let s = try XCTUnwrap(LiveActivityStateBuilder.state(for: clock, now: t0.plus(200)))
        XCTAssertEqual(try XCTUnwrap(s.frozenSeconds), 90, accuracy: 0.001)
    }

    func testStateIsNilWhenIdleOrFinished() {
        var clock = WorkoutClock(plan: plan())
        XCTAssertNil(LiveActivityStateBuilder.state(for: clock))
        clock.start(at: t0)
        clock.finish(at: t0.plus(1))
        XCTAssertNil(LiveActivityStateBuilder.state(for: clock))
    }

    func testContentStateRoundTripsThroughCodable() throws {
        let s = WorkoutAttributes.ContentState(phaseName: "Trabajo", detail: "Burpees", phaseOrder: 2, totalPhases: 9,
                                               currentPhaseStartDate: t0, currentPhaseEndDate: t0.plus(20),
                                               isPaused: true, isManual: false, countsUp: false, frozenSeconds: 12)
        let decoded = try JSONDecoder().decode(WorkoutAttributes.ContentState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded, s)
    }
}
