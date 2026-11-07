import XCTest

/// Un test (o grupo) por tipo de bloque. Los valores esperados salen de los componentes de
/// `src/components/timers/*` y de `src/utils/__tests__/timerConfig.test.ts`.
final class WorkoutPlanTests: XCTestCase {

    // MARK: EMOM

    func testEmomDia1A_fifteenOneMinutePhases() throws {
        let plan = WorkoutPlan(bloque: try Fixtures.bloque("dia_1", "dia_1_bloque_a"))
        XCTAssertEqual(plan.phases.count, 15)
        XCTAssertTrue(plan.phases.allSatisfy { $0.duration == 60 && !$0.isManual && $0.startCue == .go })
        XCTAssertEqual(plan.plannedDuration, 900)
        XCTAssertEqual(plan.phases[0].name, "Minuto 1")
        XCTAssertEqual(plan.phases[0].detail, "Assault Bike - 45 seg de esfuerzo / 15 seg transición")
        XCTAssertEqual(plan.phases[14].name, "Minuto 15")
        XCTAssertEqual(plan.phases.map(\.order), Array(0..<15))
    }

    func testEmomRestMinutesAreRestKind() throws {
        let plan = WorkoutPlan(bloque: try Fixtures.bloque("dia_1", "dia_1_bloque_a"))
        let rest = plan.phases.filter { $0.kind == .rest }.map(\.name)
        XCTAssertEqual(rest, ["Minuto 4", "Minuto 8", "Minuto 12"])
    }

    func testEmomCyclesExercisesByPositionNotByMinutoField() throws {
        // Día 3 B: 12 min con 4 ejercicios → 3 vueltas, igual que `(currentMinute-1) % numExercises`.
        let plan = WorkoutPlan(bloque: try Fixtures.bloque("dia_3", "dia_3_bloque_b"))
        XCTAssertEqual(plan.phases.count, 12)
        XCTAssertEqual(plan.phases[0].detail, "15 Goblet Squats con Kettlebell")
        XCTAssertEqual(plan.phases[4].detail, "15 Goblet Squats con Kettlebell")
        XCTAssertEqual(plan.phases[4].round, 2)
        XCTAssertEqual(plan.phases[4].exerciseIndex, 0)
        XCTAssertEqual(plan.phases[11].round, 3)
        XCTAssertTrue(plan.phases.allSatisfy { $0.totalRounds == 3 })
        XCTAssertEqual(plan.phases.filter { $0.kind == .rest }.count, 3)
    }

    func testEmomRoundsAreCeilingWhenNotDivisible() {
        let b = Bloque(tipo: .emom, nombre: "E", duracionMinutos: 5, ejercicios: [
            Ejercicio(detalle: "A", minuto: 1), Ejercicio(detalle: "B", minuto: 2),
        ])
        let plan = WorkoutPlan(bloque: b)
        XCTAssertEqual(plan.phases.count, 5)
        XCTAssertEqual(plan.phases.first?.totalRounds, 3) // ceil(5/2)
        XCTAssertEqual(plan.phases[4].detail, "A")
    }

    func testEmomWithoutDurationHasNoPhases() {
        XCTAssertTrue(WorkoutPlan(bloque: Bloque(tipo: .emom, nombre: "E", ejercicios: [Ejercicio(detalle: "A")])).isEmpty)
    }

    func testEmomWithoutExercisesUsesFallbackDetail() {
        let plan = WorkoutPlan(bloque: Bloque(tipo: .emom, nombre: "E", duracionMinutos: 2))
        XCTAssertEqual(plan.phases.count, 2)
        XCTAssertEqual(plan.phases[0].detail, "Ejercicio activo")
    }

    // MARK: AMRAP

    func testAmrapDia2B_singleCountdownPhaseWithLowTimeWarning() throws {
        let plan = WorkoutPlan(bloque: try Fixtures.bloque("dia_2", "dia_2_bloque_b"))
        XCTAssertEqual(plan.phases.count, 1)
        let p = plan.phases[0]
        XCTAssertEqual(p.duration, 720)
        XCTAssertEqual(p.lowTimeWarning, 60)
        XCTAssertFalse(p.countsUp)
        XCTAssertFalse(p.isManual)
    }

    func testAmrapDefaultsTo15MinutesLikeThePWA() {
        XCTAssertEqual(WorkoutPlan(bloque: Bloque(tipo: .amrap, nombre: "A")).phases.first?.duration, 900)
        XCTAssertEqual(WorkoutPlan(bloque: Bloque(tipo: .amrap, nombre: "A", duracionMinutos: 0)).phases.first?.duration, 900)
    }

    // MARK: FOR_TIME

    func testForTimeCountsUpToTheCap() throws {
        let b = try decode(Bloque.self, #"{"tipo":"FOR_TIME","nombre":"FT","cap_minutos":10,"ejercicios":[{"detalle":"100 Burpees"}]}"#)
        let plan = WorkoutPlan(bloque: b)
        XCTAssertEqual(plan.phases.count, 1)
        XCTAssertEqual(plan.phases[0].duration, 600)
        XCTAssertTrue(plan.phases[0].countsUp)
        XCTAssertNil(plan.phases[0].lowTimeWarning)
    }

    func testForTimeDefaultsToFifteenMinuteCap() {
        XCTAssertEqual(WorkoutPlan(bloque: Bloque(tipo: .forTime, nombre: "FT")).phases.first?.duration, 900)
    }

    // MARK: TABATA

    func testTabataDia3C_alternatesWorkAndRestWithoutTrailingRest() throws {
        let plan = WorkoutPlan(bloque: try Fixtures.bloque("dia_3", "dia_3_bloque_c"))
        // 8 trabajos + 7 descansos
        XCTAssertEqual(plan.phases.count, 15)
        XCTAssertEqual(plan.phases.map(\.name).prefix(4), ["Trabajo", "Descanso", "Trabajo", "Descanso"])
        XCTAssertEqual(plan.phases.last?.name, "Trabajo")
        XCTAssertEqual(plan.phases.filter { $0.kind == .work }.count, 8)
        XCTAssertEqual(plan.phases.filter { $0.kind == .rest }.count, 7)
        XCTAssertTrue(plan.phases.filter { $0.kind == .work }.allSatisfy { $0.duration == 20 && $0.startCue == .go })
        XCTAssertTrue(plan.phases.filter { $0.kind == .rest }.allSatisfy { $0.duration == 10 && $0.startCue == .rest })
        XCTAssertEqual(plan.plannedDuration, 230)
    }

    func testTabataRoundsAndDetail() throws {
        let plan = WorkoutPlan(bloque: try Fixtures.bloque("dia_1", "dia_1_bloque_b1"))
        XCTAssertEqual(plan.phases[0].round, 1)
        XCTAssertEqual(plan.phases[0].totalRounds, 8)
        XCTAssertEqual(plan.phases[1].round, 1) // el descanso 1 pertenece a la ronda 1
        XCTAssertEqual(plan.phases[2].round, 2)
        XCTAssertEqual(plan.phases[0].detail, "Slam Balls (balón medicinal contra el suelo)")
    }

    func testTabataUsesDefaultsWhenFieldsMissing() {
        let plan = WorkoutPlan(bloque: Bloque(tipo: .tabata, nombre: "T", ejercicios: [Ejercicio(detalle: "X")]))
        XCTAssertEqual(plan.phases.count, 15)
        XCTAssertEqual(plan.phases[0].duration, 20)
        XCTAssertEqual(plan.phases[1].duration, 10)
    }

    func testTabataCustomConfig() {
        let b = Bloque(tipo: .tabata, nombre: "T", rondas: 3, trabajoSeg: 30, descansoTabataSeg: 15, ejercicios: [Ejercicio(detalle: "X")])
        let plan = WorkoutPlan(bloque: b)
        XCTAssertEqual(plan.phases.map(\.duration), [30, 15, 30, 15, 30])
    }

    // MARK: TRISERIE / DENSITY

    func testDensityDia2A_manualExercisesWithRestBetweenRounds() throws {
        let plan = WorkoutPlan(bloque: try Fixtures.bloque("dia_2", "dia_2_bloque_a"))
        // 4 rondas × 4 ejercicios + 3 descansos (ninguno tras la última ronda)
        XCTAssertEqual(plan.phases.count, 19)
        XCTAssertEqual(plan.phases.filter(\.isManual).count, 16)
        let rests = plan.phases.filter { $0.kind == .rest }
        XCTAssertEqual(rests.count, 3)
        XCTAssertTrue(rests.allSatisfy { $0.duration == 45 && !$0.isManual && $0.startCue == .rest })
        XCTAssertEqual(plan.phases[4].kind, .rest)
        XCTAssertEqual(plan.phases.last?.isManual, true)
        XCTAssertNil(plan.plannedDuration, "Con pasos manuales la duración total es desconocida")
    }

    func testTriserieDefaultsFourRoundsAnd45sRest() {
        let b = Bloque(tipo: .triserie, nombre: "T", ejercicios: [Ejercicio(detalle: "A"), Ejercicio(detalle: "B"), Ejercicio(detalle: "C")])
        let plan = WorkoutPlan(bloque: b)
        XCTAssertEqual(plan.phases.count, 4 * 3 + 3)
        XCTAssertEqual(plan.phases.first(where: { $0.kind == .rest })?.duration, 45)
    }

    func testTriserieRestFromLegacyString() {
        let b = Bloque(tipo: .triserie, nombre: "T", descansoEntreRondas: "1 min", ejercicios: [Ejercicio(detalle: "A")])
        XCTAssertEqual(WorkoutPlan(bloque: b).phases.first(where: { $0.kind == .rest })?.duration, 60)
    }

    func testTriserieWithZeroRestSkipsRestPhases() {
        let b = Bloque(tipo: .triserie, nombre: "T", rondas: 3, descansoSeg: 0, ejercicios: [Ejercicio(detalle: "A"), Ejercicio(detalle: "B")])
        let plan = WorkoutPlan(bloque: b)
        XCTAssertEqual(plan.phases.count, 6)
        XCTAssertTrue(plan.phases.allSatisfy { $0.isManual })
    }

    func testTriserieWithoutExercisesHasNoPhases() {
        XCTAssertTrue(WorkoutPlan(bloque: Bloque(tipo: .triserie, nombre: "T")).isEmpty)
    }

    // MARK: FINISHER

    func testFinisherDia1C_manualStepsAndTimedRest() throws {
        let plan = WorkoutPlan(bloque: try Fixtures.bloque("dia_1", "dia_1_bloque_c"))
        XCTAssertEqual(plan.phases.count, 9)
        XCTAssertEqual(plan.phases.prefix(3).map(\.isManual), [true, true, false])
        XCTAssertEqual(plan.phases[2].kind, .rest)
        XCTAssertEqual(plan.phases[2].duration, 30)
        XCTAssertEqual(plan.phases[3].round, 2)
        XCTAssertNil(plan.plannedDuration)
    }

    func testFinisherDia2C_threeTimedStepsPerRound() throws {
        let plan = WorkoutPlan(bloque: try Fixtures.bloque("dia_2", "dia_2_bloque_c"))
        XCTAssertEqual(plan.phases.map(\.kind), [.work, .work, .rest, .work, .work, .rest, .work, .work, .rest])
        XCTAssertEqual(plan.plannedDuration, 270)
    }

    // MARK: HIIT_INTERVALS

    func testHiitSplitsWorkAndTransition() {
        let b = Bloque(tipo: .hiitIntervals, nombre: "HIIT", rondas: 4, trabajoSeg: 40, ejercicios: [
            Ejercicio(detalle: "Ejercicio 1", segundos: 60),
            Ejercicio(detalle: "Ejercicio 2", segundos: 60),
            Ejercicio(detalle: "Descanso total", segundos: 60),
        ])
        let plan = WorkoutPlan(bloque: b)
        XCTAssertEqual(plan.phases.count, 20)
        XCTAssertEqual(plan.phases.prefix(5).map(\.kind), [.work, .transition, .work, .transition, .rest])
        XCTAssertEqual(plan.phases.prefix(5).map(\.duration), [40, 20, 40, 20, 60])
        XCTAssertEqual(plan.phases[5].round, 2)
        XCTAssertEqual(plan.phases[19].round, 4)
        XCTAssertEqual(plan.plannedDuration, 720)
        // Transición y descanso suenan como descanso; el trabajo como "go".
        XCTAssertEqual(plan.phases.prefix(5).map(\.startCue), [.go, .rest, .go, .rest, .rest])
    }

    func testHiitStepNotLongerThanWorkIsNotSplit() {
        let b = Bloque(tipo: .hiitIntervals, nombre: "H", rondas: 1, trabajoSeg: 40, ejercicios: [Ejercicio(detalle: "Bike", segundos: 40)])
        XCTAssertEqual(WorkoutPlan(bloque: b).phases.map(\.duration), [40])
    }

    func testFinisherRestWithoutSecondsUsesDefault30s() {
        let b = Bloque(tipo: .finisher, nombre: "F", rondas: 1, ejercicios: [Ejercicio(detalle: "Descanso")])
        XCTAssertEqual(WorkoutPlan(bloque: b).phases.first?.duration, 30)
    }

    func testFinisherDefaultsToThreeRounds() {
        let b = Bloque(tipo: .finisher, nombre: "F", ejercicios: [Ejercicio(detalle: "A", segundos: 30)])
        XCTAssertEqual(WorkoutPlan(bloque: b).phases.count, 3)
    }

    // MARK: Calentamiento

    func testWarmupIsOneCountdownPhaseWithoutStartCue() throws {
        let dia = try XCTUnwrap(Fixtures.defaultRoutine().diasEntrenamiento.first)
        let plan = try XCTUnwrap(WorkoutPlan.warmup(for: dia))
        XCTAssertEqual(plan.phases.count, 1)
        XCTAssertEqual(plan.phases[0].duration, 300)
        XCTAssertEqual(plan.phases[0].kind, .warmup)
        XCTAssertEqual(plan.phases[0].startCue, .none)
    }

    func testWarmupIsNilWithoutMinutes() {
        XCTAssertNil(WorkoutPlan.warmup(for: DiaEntrenamiento(id: "d", nombre: "D")))
        XCTAssertNil(WorkoutPlan.warmup(for: DiaEntrenamiento(id: "d", nombre: "D", calentamientoMinutos: 0)))
    }

    // MARK: Cobertura de toda la rutina

    func testEveryBlockInDefaultRoutineProducesAPlan() throws {
        let rutina = try Fixtures.defaultRoutine()
        for dia in rutina.diasEntrenamiento {
            for bloque in dia.bloques {
                let plan = WorkoutPlan(bloque: bloque)
                XCTAssertFalse(plan.isEmpty, "\(bloque.id ?? bloque.nombre) sin fases")
                XCTAssertEqual(plan.phases.map(\.order), Array(0..<plan.phases.count))
                XCTAssertEqual(Set(plan.phases.map(\.id)).count, plan.phases.count, "ids de fase repetidos en \(bloque.id ?? "")")
            }
        }
    }

    func testPhaseDecodesLegacyPrototypePayload() throws {
        let p = try decode(WorkoutPhase.self, #"{"name":"Esfuerzo","duration":20,"order":1}"#)
        XCTAssertEqual(p.name, "Esfuerzo")
        XCTAssertEqual(p.kind, .work)
        XCTAssertFalse(p.isManual)
        XCTAssertEqual(p.startCue, .go)
    }

    func testPlanCodableRoundTrip() throws {
        let plan = WorkoutPlan(bloque: try Fixtures.bloque("dia_2", "dia_2_bloque_a"))
        let decoded = try JSONDecoder().decode(WorkoutPlan.self, from: JSONEncoder().encode(plan))
        XCTAssertEqual(decoded, plan)
    }
}

final class TimerConfigTests: XCTestCase {
    func testParseRestSeconds() {
        XCTAssertEqual(TimerConfig.parseRestSeconds("45 seg"), 45)
        XCTAssertEqual(TimerConfig.parseRestSeconds("45s"), 45)
        XCTAssertEqual(TimerConfig.parseRestSeconds("1 min"), 60)
        XCTAssertNil(TimerConfig.parseRestSeconds(nil))
        XCTAssertNil(TimerConfig.parseRestSeconds("sin descanso"))
    }

    func testTriserieConfig() throws {
        XCTAssertEqual(TimerConfig.triserieConfig(for: Bloque(tipo: .triserie, nombre: "")), TriserieConfig(rounds: 4, restSeconds: 45))
        XCTAssertEqual(
            TimerConfig.triserieConfig(for: Bloque(tipo: .triserie, nombre: "", descansoEntreRondas: "45 seg", rondas: 6, descansoSeg: 20)),
            TriserieConfig(rounds: 6, restSeconds: 20)
        )
        XCTAssertEqual(TimerConfig.triserieConfig(for: Bloque(tipo: .triserie, nombre: "", descansoSeg: 0)).restSeconds, 0)
        XCTAssertEqual(TimerConfig.triserieConfig(for: Bloque(tipo: .triserie, nombre: "", rondas: -2, descansoSeg: -1)), TriserieConfig(rounds: 4, restSeconds: 45))
        XCTAssertEqual(TimerConfig.triserieConfig(for: try Fixtures.bloque("dia_2", "dia_2_bloque_a")), TriserieConfig(rounds: 4, restSeconds: 45))
    }

    func testTabataConfig() throws {
        XCTAssertEqual(TimerConfig.tabataConfig(for: Bloque(tipo: .tabata, nombre: "")), TabataConfig(rounds: 8, workSeconds: 20, restSeconds: 10))
        XCTAssertEqual(
            TimerConfig.tabataConfig(for: Bloque(tipo: .tabata, nombre: "", rondas: 6, trabajoSeg: 30, descansoTabataSeg: 15)),
            TabataConfig(rounds: 6, workSeconds: 30, restSeconds: 15)
        )
        XCTAssertEqual(TimerConfig.tabataConfig(for: try Fixtures.bloque("dia_3", "dia_3_bloque_c")), TabataConfig(rounds: 8, workSeconds: 20, restSeconds: 10))
    }

    func testRestExerciseDetection() {
        XCTAssertTrue(Ejercicio(detalle: "Descanso total").esDescanso)
        XCTAssertTrue(Ejercicio(detalle: "DESCANSO").esDescanso)
        XCTAssertFalse(Ejercicio(detalle: "Burpees").esDescanso)
    }

    func testFinisherTotalSeconds() {
        let steps = TimerConfig.finisherSteps(for: Bloque(tipo: .finisher, nombre: "", rondas: 2, ejercicios: [
            Ejercicio(detalle: "A", segundos: 30), Ejercicio(detalle: "Descanso", segundos: 30),
        ]))
        XCTAssertEqual(TimerConfig.finisherTotalSeconds(steps), 120)
        let manual = TimerConfig.finisherSteps(for: Bloque(tipo: .finisher, nombre: "", rondas: 1, ejercicios: [Ejercicio(detalle: "A")]))
        XCTAssertNil(TimerConfig.finisherTotalSeconds(manual))
    }
}
