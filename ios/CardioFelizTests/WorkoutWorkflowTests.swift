import XCTest

@MainActor
final class WorkoutWorkflowTests: XCTestCase {

    struct MockRoutineProvider: RoutineProvider {
        let routine: RutinaData
        func loadRoutine() throws -> RutinaData { routine }
    }

    func testWorkflowNavigationTransitions() throws {
        let routine = try Fixtures.defaultRoutine()
        let provider = MockRoutineProvider(routine: routine)
        let vm = WorkoutWorkflowViewModel(routineProvider: provider)

        XCTAssertEqual(vm.destination, .home)
        XCTAssertFalse(vm.isIdleTimerDisabled)

        let dia1 = routine.diasEntrenamiento[0]
        vm.selectDay(dia1)
        XCTAssertEqual(vm.destination, .dayDetail(dia1))
        XCTAssertTrue(vm.isIdleTimerDisabled)

        vm.startWarmup(for: dia1)
        XCTAssertEqual(vm.destination, .warmup(dia1))
        XCTAssertTrue(vm.isIdleTimerDisabled)

        let bloqueA = dia1.bloques[0]
        vm.showBlockDetail(dia: dia1, bloque: bloqueA)
        XCTAssertEqual(vm.destination, .blockDetail(dia1, bloqueA))

        vm.startActiveWorkout(dia: dia1, bloque: bloqueA)
        XCTAssertEqual(vm.destination, .activeWorkout(dia1, bloqueA))

        vm.exitActiveWorkout(to: dia1)
        XCTAssertEqual(vm.destination, .dayDetail(dia1))

        vm.goHome()
        XCTAssertEqual(vm.destination, .home)
        XCTAssertFalse(vm.isIdleTimerDisabled)
    }

    func testBlockCompletionAndModalProgression() throws {
        let routine = try Fixtures.defaultRoutine()
        let provider = MockRoutineProvider(routine: routine)
        let vm = WorkoutWorkflowViewModel(routineProvider: provider)

        let dia1 = routine.diasEntrenamiento[0]
        let bloqueA = dia1.bloques[0]
        let bloqueB = dia1.bloques[1]

        vm.handleBlockCompleted(
            dia: dia1,
            bloque: bloqueA,
            totalSeconds: 900,
            rounds: nil,
            today: "2026-05-01",
            activityStore: nil,
            weightKg: 62.5
        )

        XCTAssertTrue(vm.isBlockCompleted(diaId: dia1.id, blockId: bloqueA.id))
        XCTAssertFalse(vm.isBlockCompleted(diaId: dia1.id, blockId: bloqueB.id))

        let modal = try XCTUnwrap(vm.completedModalData)
        XCTAssertEqual(modal.bloque.id, bloqueA.id)
        XCTAssertEqual(modal.totalSeconds, 900)
        XCTAssertFalse(modal.isDayFinished)
        XCTAssertTrue(modal.hasNextBlock)
        XCTAssertEqual(modal.nextBlock?.id, bloqueB.id)

        vm.proceedToNextBlock(dia: dia1)
        XCTAssertEqual(vm.destination, .blockDetail(dia1, bloqueB))
        XCTAssertNil(vm.completedModalData)
    }
}
