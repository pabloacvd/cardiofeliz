import XCTest

final class WorkoutClockTests: XCTestCase {

    /// 3 fases con tiempo: 20 / 20 / 20 s.
    private func timedPlan() -> WorkoutPlan { .prototype }

    /// Fase manual, descanso de 10 s, fase manual.
    private func manualPlan() -> WorkoutPlan {
        WorkoutPlan(title: "M", phases: [
            WorkoutPhase(name: "A", duration: 0, order: 0, isManual: true),
            WorkoutPhase(name: "R", duration: 10, order: 1, kind: .rest, startCue: .rest),
            WorkoutPhase(name: "B", duration: 0, order: 2, isManual: true),
        ])
    }

    // MARK: Inicio y fechas absolutas

    func testStartChainsPhaseDates() {
        var c = WorkoutClock(plan: timedPlan())
        XCTAssertEqual(c.start(at: t0), [.started])
        XCTAssertEqual(c.state, .running)
        XCTAssertEqual(c.startDates, [t0, t0.plus(20), t0.plus(40)])
        XCTAssertEqual(c.endDates, [t0.plus(20), t0.plus(40), t0.plus(60)])
        XCTAssertEqual(c.currentIndex, 0)
    }

    func testStartOnEmptyPlanDoesNothing() {
        var c = WorkoutClock(plan: WorkoutPlan(title: "", phases: []))
        XCTAssertTrue(c.start(at: t0).isEmpty)
        XCTAssertEqual(c.state, .idle)
    }

    func testStartWhileRunningIsIgnored() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        XCTAssertTrue(c.start(at: t0.plus(5)).isEmpty)
        XCTAssertEqual(c.startDates.first, t0)
    }

    func testTimeRemainingAndProgress() {
        var c = WorkoutClock(plan: timedPlan())
        XCTAssertNil(c.timeRemainingInCurrentPhase(at: t0), "idle no tiene tiempo")
        c.start(at: t0)
        XCTAssertEqual(c.timeRemainingInCurrentPhase(at: t0.plus(5)) ?? -1, 15, accuracy: 0.001)
        XCTAssertEqual(c.progressInCurrentPhase(at: t0.plus(5)), 0.25, accuracy: 0.001)
        XCTAssertEqual(c.elapsedInCurrentPhase(at: t0.plus(5)), 5, accuracy: 0.001)
    }

    // MARK: Avance por tiempo

    func testTickAdvancesWhenPhaseElapses() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        let events = c.tick(at: t0.plus(20.05))
        XCTAssertEqual(events, [.phaseChanged(from: 0, to: 1, cause: .elapsed)])
        XCTAssertEqual(c.currentIndex, 1)
        // Las fechas no se tocan: el avance por tiempo no desplaza nada.
        XCTAssertEqual(c.startDates[1], t0.plus(20))
    }

    func testTickJustBeforeBoundaryDoesNotAdvance() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        XCTAssertFalse(c.tick(at: t0.plus(19.99)).contains { if case .phaseChanged = $0 { return true } else { return false } })
        XCTAssertEqual(c.currentIndex, 0)
    }

    func testTickAfterBackgroundCatchesUpSeveralPhases() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        // La app estuvo 45 s en segundo plano: debe aterrizar en la fase 3 (índice 2).
        let events = c.tick(at: t0.plus(45))
        XCTAssertEqual(events, [
            .phaseChanged(from: 0, to: 1, cause: .elapsed),
            .phaseChanged(from: 1, to: 2, cause: .elapsed),
        ])
        XCTAssertEqual(c.currentIndex, 2)
        XCTAssertEqual(c.timeRemainingInCurrentPhase(at: t0.plus(45)) ?? -1, 15, accuracy: 0.001)
    }

    func testCompletesAfterLastPhase() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        let events = c.tick(at: t0.plus(61))
        XCTAssertEqual(events.last, .finished(.completed))
        XCTAssertEqual(c.state, .finished)
        XCTAssertEqual(c.result?.reason, .completed)
        XCTAssertEqual(c.result?.phasesCompleted, 3)
    }

    func testNaturalCompletionIsDatedAtPlannedEndNotAtLateTick() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        c.tick(at: t0.plus(500)) // la app despertó mucho después
        XCTAssertEqual(c.result?.elapsedSeconds, 60)
    }

    // MARK: Tics de cuenta regresiva (3, 2, 1)

    func testCountdownTicksFireOncePerSecondMark() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        var ticks: [Int] = []
        // Muestrear a 10 Hz toda la primera fase.
        var t = 0.0
        while t < 20 {
            for e in c.tick(at: t0.plus(t)) {
                if case .countdownTick(let phase, let left) = e, phase == 0 { ticks.append(left) }
            }
            t += 0.1
        }
        XCTAssertEqual(ticks, [3, 2, 1])
    }

    func testCountdownTicksResetOnNewPhase() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        c.tick(at: t0.plus(17.5)) // dispara el 3 de la fase 0
        _ = c.tick(at: t0.plus(20.1)) // pasa a la fase 1
        let events = c.tick(at: t0.plus(37.5)) // 2.5 s antes del fin de la fase 1
        XCTAssertTrue(events.contains(.countdownTick(phase: 1, secondsLeft: 3)))
    }

    func testNoCountdownTicksOnManualPhases() {
        var c = WorkoutClock(plan: manualPlan())
        c.start(at: t0)
        XCTAssertTrue(c.tick(at: t0.plus(1000)).isEmpty)
        XCTAssertEqual(c.currentIndex, 0, "Una fase manual nunca avanza sola")
    }

    func testNoCountdownTicksOnPhasesShorterThanTheTickWindow() {
        let plan = WorkoutPlan(title: "", phases: [WorkoutPhase(name: "x", duration: 2, order: 0), WorkoutPhase(name: "y", duration: 30, order: 1)])
        var c = WorkoutClock(plan: plan)
        c.start(at: t0)
        let events = c.tick(at: t0.plus(0.1))
        XCTAssertFalse(events.contains { if case .countdownTick = $0 { return true } else { return false } })
    }

    // MARK: Pausa y reanudación

    func testPauseFreezesRemainingTime() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        XCTAssertEqual(c.pause(at: t0.plus(5)), [.paused])
        XCTAssertEqual(c.state, .paused)
        XCTAssertEqual(c.timeRemainingInCurrentPhase(at: t0.plus(5)) ?? -1, 15, accuracy: 0.001)
        XCTAssertEqual(c.timeRemainingInCurrentPhase(at: t0.plus(500)) ?? -1, 15, accuracy: 0.001, "Congelado aunque pase el tiempo")
        XCTAssertEqual(c.progressInCurrentPhase(at: t0.plus(500)), 0.25, accuracy: 0.001)
    }

    func testPausedClockDoesNotAdvanceOnTick() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        c.pause(at: t0.plus(5))
        XCTAssertTrue(c.tick(at: t0.plus(500)).isEmpty)
        XCTAssertEqual(c.currentIndex, 0)
    }

    func testResumeShiftsCurrentAndFutureDatesByPauseLength() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        c.pause(at: t0.plus(5))
        XCTAssertEqual(c.resume(at: t0.plus(35)), [.resumed]) // pausa de 30 s
        XCTAssertEqual(c.state, .running)
        XCTAssertEqual(c.startDates, [t0.plus(30), t0.plus(50), t0.plus(70)])
        XCTAssertEqual(c.endDates, [t0.plus(50), t0.plus(70), t0.plus(90)])
        XCTAssertEqual(c.timeRemainingInCurrentPhase(at: t0.plus(35)) ?? -1, 15, accuracy: 0.001)
    }

    func testResumeThenCompleteTakesFullPlannedActiveTime() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        c.pause(at: t0.plus(5))
        c.resume(at: t0.plus(35))
        c.tick(at: t0.plus(91))
        XCTAssertEqual(c.state, .finished)
        XCTAssertEqual(c.result?.elapsedSeconds, 60, "El tiempo activo excluye la pausa")
    }

    func testMultiplePausesAccumulate() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        c.pause(at: t0.plus(5)); c.resume(at: t0.plus(15))   // 10 s
        c.pause(at: t0.plus(20)); c.resume(at: t0.plus(50))  // 30 s
        XCTAssertEqual(c.pausedTotal, 40, accuracy: 0.001)
        XCTAssertEqual(c.endDates.last, t0.plus(100))
        XCTAssertEqual(c.activeElapsed(at: t0.plus(50)), 10, accuracy: 0.001)
    }

    func testPauseResumeOnlyValidInTheRightState() {
        var c = WorkoutClock(plan: timedPlan())
        XCTAssertTrue(c.pause(at: t0).isEmpty)
        XCTAssertTrue(c.resume(at: t0).isEmpty)
        c.start(at: t0)
        XCTAssertTrue(c.resume(at: t0.plus(1)).isEmpty, "No se puede reanudar si no está en pausa")
        c.pause(at: t0.plus(2))
        XCTAssertTrue(c.pause(at: t0.plus(3)).isEmpty, "Doble pausa ignorada")
    }

    func testPauseAfterPhaseAlreadyElapsedAppliesPendingAdvanceFirst() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        // Se pausa 25 s después: la fase 0 ya había terminado, la pausa debe caer en la fase 1.
        let events = c.pause(at: t0.plus(25))
        XCTAssertEqual(events, [.phaseChanged(from: 0, to: 1, cause: .elapsed), .paused])
        XCTAssertEqual(c.currentIndex, 1)
        XCTAssertEqual(c.timeRemainingInCurrentPhase(at: t0.plus(25)) ?? -1, 15, accuracy: 0.001)
    }

    func testPauseAfterPlanAlreadyElapsedCompletesInsteadOfPausing() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        // La app despertó 10 s después del fin planificado (60 s): recorre las fases pendientes y termina.
        let events = c.pause(at: t0.plus(70))
        XCTAssertEqual(events, [
            .phaseChanged(from: 0, to: 1, cause: .elapsed),
            .phaseChanged(from: 1, to: 2, cause: .elapsed),
            .finished(.completed),
        ])
        XCTAssertFalse(events.contains(.paused))
        XCTAssertEqual(c.state, .finished)
        XCTAssertEqual(c.result?.elapsedSeconds, 60, "Se fecha en el fin planificado, no en la hora de la pausa")
    }

    // MARK: Salto de fase

    func testNextSkipsToNextPhaseStartingNowAndShiftsTheRest() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        let events = c.next(at: t0.plus(5))
        XCTAssertEqual(events, [.phaseChanged(from: 0, to: 1, cause: .user)])
        XCTAssertEqual(c.currentIndex, 1)
        XCTAssertEqual(c.endDates[0], t0.plus(5))
        XCTAssertEqual(c.startDates[1], t0.plus(5))
        XCTAssertEqual(c.endDates[1], t0.plus(25))
        XCTAssertEqual(c.startDates[2], t0.plus(25))
        XCTAssertEqual(c.endDates[2], t0.plus(45))
        XCTAssertEqual(c.timeRemainingInCurrentPhase(at: t0.plus(5)) ?? -1, 20, accuracy: 0.001)
    }

    func testNextOnLastPhaseCompletes() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        c.next(at: t0.plus(1)); c.next(at: t0.plus(2))
        XCTAssertEqual(c.currentIndex, 2)
        XCTAssertEqual(c.next(at: t0.plus(3)), [.finished(.completed)])
        XCTAssertEqual(c.state, .finished)
        XCTAssertEqual(c.result?.elapsedSeconds, 3)
        XCTAssertEqual(c.result?.phasesCompleted, 3)
    }

    func testNextWhilePausedKeepsPauseAndGivesFullDuration() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        c.pause(at: t0.plus(5))
        c.next(at: t0.plus(100))
        XCTAssertEqual(c.state, .paused)
        XCTAssertEqual(c.currentIndex, 1)
        XCTAssertEqual(c.timeRemainingInCurrentPhase(at: t0.plus(200)) ?? -1, 20, accuracy: 0.001)
        c.resume(at: t0.plus(110))
        XCTAssertEqual(c.timeRemainingInCurrentPhase(at: t0.plus(110)) ?? -1, 20, accuracy: 0.001)
    }

    func testNextBeforeStartDoesNothing() {
        var c = WorkoutClock(plan: timedPlan())
        XCTAssertTrue(c.next(at: t0).isEmpty)
    }

    // MARK: Fases manuales

    func testManualPhaseAdvancesOnlyOnNext() {
        var c = WorkoutClock(plan: manualPlan())
        c.start(at: t0)
        XCTAssertNil(c.timeRemainingInCurrentPhase(at: t0.plus(3)))
        XCTAssertEqual(c.elapsedInCurrentPhase(at: t0.plus(3)), 3, accuracy: 0.001)
        XCTAssertEqual(c.progressInCurrentPhase(at: t0.plus(3)), 0)
        XCTAssertEqual(c.next(at: t0.plus(30)), [.phaseChanged(from: 0, to: 1, cause: .user)])
    }

    func testManualPhaseAnchorsFollowingTimedPhaseAtConfirmation() {
        var c = WorkoutClock(plan: manualPlan())
        c.start(at: t0)
        c.next(at: t0.plus(30))
        XCTAssertEqual(c.startDates[1], t0.plus(30))
        XCTAssertEqual(c.endDates[1], t0.plus(40))
        // El descanso corre solo y deja a la siguiente fase manual donde termina.
        XCTAssertEqual(c.tick(at: t0.plus(40.1)), [.phaseChanged(from: 1, to: 2, cause: .elapsed)])
        XCTAssertEqual(c.currentIndex, 2)
        XCTAssertEqual(c.startDates[2], t0.plus(40))
    }

    func testManualPhaseThenRestThenFinishOnLastNext() {
        var c = WorkoutClock(plan: manualPlan())
        c.start(at: t0)
        c.next(at: t0.plus(30))
        c.tick(at: t0.plus(41))
        XCTAssertEqual(c.next(at: t0.plus(60)), [.finished(.completed)])
        XCTAssertEqual(c.result?.elapsedSeconds, 60)
    }

    func testSkipTimedRestMovesStraightToNextManualPhase() {
        var c = WorkoutClock(plan: manualPlan())
        c.start(at: t0)
        c.next(at: t0.plus(30))
        XCTAssertEqual(c.next(at: t0.plus(33)), [.phaseChanged(from: 1, to: 2, cause: .user)])
        XCTAssertEqual(c.endDates[1], t0.plus(33))
        XCTAssertEqual(c.startDates[2], t0.plus(33))
    }

    // MARK: Finalización anticipada

    func testFinishEarlyReportsElapsedAndPhasesCompleted() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        c.next(at: t0.plus(10))
        XCTAssertEqual(c.finish(at: t0.plus(25)), [.finished(.finishedEarly)])
        XCTAssertEqual(c.result, WorkoutResult(elapsedSeconds: 25, reason: .finishedEarly, phasesCompleted: 1))
    }

    func testFinishWhilePausedExcludesPausedTime() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        c.pause(at: t0.plus(10))
        c.finish(at: t0.plus(110))
        XCTAssertEqual(c.result?.elapsedSeconds, 10)
    }

    func testFinishWhenIdleOrFinishedDoesNothing() {
        var c = WorkoutClock(plan: timedPlan())
        XCTAssertTrue(c.finish(at: t0).isEmpty)
        c.start(at: t0); c.finish(at: t0.plus(1))
        XCTAssertTrue(c.finish(at: t0.plus(2)).isEmpty)
        XCTAssertTrue(c.tick(at: t0.plus(3)).isEmpty)
    }

    func testCanRestartAfterFinishing() {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0); c.finish(at: t0.plus(1))
        XCTAssertEqual(c.start(at: t0.plus(100)), [.started])
        XCTAssertEqual(c.currentIndex, 0)
        XCTAssertNil(c.result)
        XCTAssertEqual(c.startDates.first, t0.plus(100))
    }

    // MARK: Casos por tipo de bloque

    func testAmrapLowTimeWarningInLastMinute() throws {
        var c = WorkoutClock(plan: WorkoutPlan(bloque: try Fixtures.bloque("dia_2", "dia_2_bloque_b")))
        c.start(at: t0)
        XCTAssertFalse(c.isLowTime(at: t0.plus(600)))
        XCTAssertTrue(c.isLowTime(at: t0.plus(661)))
        XCTAssertFalse(c.isLowTime(at: t0.plus(721)), "Terminado ya no es 'poco tiempo'")
    }

    func testEmomAdvancesEveryMinute() throws {
        var c = WorkoutClock(plan: WorkoutPlan(bloque: try Fixtures.bloque("dia_3", "dia_3_bloque_b")))
        c.start(at: t0)
        c.tick(at: t0.plus(60.1))
        XCTAssertEqual(c.currentIndex, 1)
        c.tick(at: t0.plus(60 * 11 + 1))
        XCTAssertEqual(c.currentIndex, 11)
        c.tick(at: t0.plus(60 * 12 + 1))
        XCTAssertEqual(c.state, .finished)
        XCTAssertEqual(c.result?.elapsedSeconds, 720)
    }

    func testTabataRunsFor230Seconds() throws {
        var c = WorkoutClock(plan: WorkoutPlan(bloque: try Fixtures.bloque("dia_3", "dia_3_bloque_c")))
        c.start(at: t0)
        c.tick(at: t0.plus(229))
        XCTAssertEqual(c.state, .running)
        XCTAssertEqual(c.currentIndex, 14)
        c.tick(at: t0.plus(230.1))
        XCTAssertEqual(c.state, .finished)
    }

    func testForTimeEndsAtCapAndReportsElapsed() throws {
        let b = try decode(Bloque.self, #"{"tipo":"FOR_TIME","nombre":"FT","cap_minutos":1,"ejercicios":[{"detalle":"x"}]}"#)
        var c = WorkoutClock(plan: WorkoutPlan(bloque: b))
        c.start(at: t0)
        XCTAssertEqual(c.elapsedInCurrentPhase(at: t0.plus(30)), 30, accuracy: 0.001)
        c.finish(at: t0.plus(42)) // "¡TERMINÉ!"
        XCTAssertEqual(c.result?.elapsedSeconds, 42)

        var capped = WorkoutClock(plan: WorkoutPlan(bloque: b))
        capped.start(at: t0)
        capped.tick(at: t0.plus(75))
        XCTAssertEqual(capped.result, WorkoutResult(elapsedSeconds: 60, reason: .completed, phasesCompleted: 1))
    }

    func testHiitSequenceTimings() {
        let b = Bloque(tipo: .hiitIntervals, nombre: "H", rondas: 1, trabajoSeg: 40, ejercicios: [
            Ejercicio(detalle: "A", segundos: 60), Ejercicio(detalle: "Descanso", segundos: 60),
        ])
        var c = WorkoutClock(plan: WorkoutPlan(bloque: b))
        c.start(at: t0)
        // trabajo 40 + transición 20 + descanso 60
        XCTAssertEqual(c.endDates, [t0.plus(40), t0.plus(60), t0.plus(120)])
        c.tick(at: t0.plus(41))
        XCTAssertEqual(c.currentPhase?.kind, .transition)
        c.tick(at: t0.plus(61))
        XCTAssertEqual(c.currentPhase?.kind, .rest)
    }

    // MARK: Snapshot (Watch / restauración)

    func testSnapshotRoundTripPreservesRunningState() throws {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        c.next(at: t0.plus(5))
        let data = try JSONEncoder().encode(c.snapshot)
        let restored = try XCTUnwrap(WorkoutClock(snapshot: JSONDecoder().decode(ClockSnapshot.self, from: data)))
        XCTAssertEqual(restored.currentIndex, 1)
        XCTAssertEqual(restored.startDates, c.startDates)
        XCTAssertEqual(restored.timeRemainingInCurrentPhase(at: t0.plus(10)) ?? -1, 15, accuracy: 0.001)
        XCTAssertEqual(restored.state, .running)
    }

    func testSnapshotPreservesPausedState() throws {
        var c = WorkoutClock(plan: timedPlan())
        c.start(at: t0)
        c.pause(at: t0.plus(5))
        var restored = try XCTUnwrap(WorkoutClock(snapshot: c.snapshot))
        XCTAssertEqual(restored.state, .paused)
        XCTAssertEqual(restored.timeRemainingInCurrentPhase(at: t0.plus(999)) ?? -1, 15, accuracy: 0.001)
        restored.resume(at: t0.plus(35))
        XCTAssertEqual(restored.endDates[0], t0.plus(50))
    }

    func testInconsistentSnapshotIsRejected() {
        var snap = WorkoutClock(plan: timedPlan()).snapshot
        snap.state = .running
        snap.startDates = [t0]
        snap.endDates = [t0]
        XCTAssertNil(WorkoutClock(snapshot: snap))
    }
}
