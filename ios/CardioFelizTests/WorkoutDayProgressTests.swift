import XCTest

final class WorkoutDayProgressTests: XCTestCase {

    func testBlockKey() {
        XCTAssertEqual(WorkoutDayProgress.blockKey(diaId: "dia_1", blockId: "b1"), "dia_1::b1")
    }

    func testIsDayFinishedReturnsFalseWhenIncomplete() throws {
        let dia = try Fixtures.defaultRoutine().diasEntrenamiento[0] // 5 blocks
        var progress: [String: BlockProgressEntry] = [:]

        XCTAssertFalse(WorkoutDayProgress.isDayFinished(dia: dia, progress: progress))

        // Complete only first block
        let b1 = dia.bloques[0]
        progress[WorkoutDayProgress.blockKey(diaId: dia.id, blockId: b1.id!)] = BlockProgressEntry(
            date: "2026-05-01",
            durationSeconds: 900,
            tipoBloque: b1.tipo,
            bloqueNombre: b1.nombre
        )
        XCTAssertFalse(WorkoutDayProgress.isDayFinished(dia: dia, progress: progress))
    }

    func testIsDayFinishedReturnsTrueWhenAllBlocksComplete() throws {
        let dia = try Fixtures.defaultRoutine().diasEntrenamiento[0] // 5 blocks
        var progress: [String: BlockProgressEntry] = [:]

        for b in dia.bloques {
            progress[WorkoutDayProgress.blockKey(diaId: dia.id, blockId: b.id!)] = BlockProgressEntry(
                date: "2026-05-01",
                durationSeconds: 300,
                tipoBloque: b.tipo,
                bloqueNombre: b.nombre
            )
        }

        XCTAssertTrue(WorkoutDayProgress.isDayFinished(dia: dia, progress: progress))
    }

    func testBuildWorkoutDayActivityDraft() throws {
        let dia = try Fixtures.defaultRoutine().diasEntrenamiento[0]
        var progress: [String: BlockProgressEntry] = [:]

        let completionTime = Date()
        for (i, b) in dia.bloques.enumerated() {
            progress[WorkoutDayProgress.blockKey(diaId: dia.id, blockId: b.id!)] = BlockProgressEntry(
                date: "2026-05-01",
                completedAt: completionTime.addingTimeInterval(Double(i * 600)),
                durationSeconds: 600,
                rounds: b.tipo == .amrap ? 5 : nil,
                tipoBloque: b.tipo,
                bloqueNombre: b.nombre
            )
        }

        let draft = WorkoutDayProgress.buildWorkoutDayActivity(dia: dia, progress: progress, today: "2026-05-01")
        XCTAssertEqual(draft.type, .workoutDay)
        XCTAssertEqual(draft.occurredOn, "2026-05-01")
        XCTAssertEqual(draft.dayId, "dia_1")
        XCTAssertEqual(draft.blocksCompleted, 5)
        XCTAssertEqual(draft.durationSeconds, 3000)
        XCTAssertNotNil(draft.startedAt)
    }

    func testWeekCompletedDays() {
        let activities: [ActivityRecord] = [
            ActivityRecord(
                id: "1",
                userId: "u1",
                type: .workoutDay,
                occurredOn: "2026-05-01",
                startedAt: nil,
                durationSeconds: 1800,
                dayId: "dia_1",
                blocksCompleted: 5,
                roundsTotal: nil,
                distanceKm: nil,
                runLocation: nil,
                feeling: nil,
                caloriesKcal: nil,
                xpEarned: 100,
                createdAt: nil
            ),
            ActivityRecord(
                id: "2",
                userId: "u1",
                type: .workoutDay,
                occurredOn: "2026-05-03",
                startedAt: nil,
                durationSeconds: 1800,
                dayId: "dia_2",
                blocksCompleted: 3,
                roundsTotal: nil,
                distanceKm: nil,
                runLocation: nil,
                feeling: nil,
                caloriesKcal: nil,
                xpEarned: 100,
                createdAt: nil
            )
        ]

        let result = WorkoutDayProgress.weekCompletedDays(
            activities: activities,
            today: "2026-05-03",
            weekStart: "2026-04-28"
        )

        XCTAssertEqual(result["dia_1"], "week")
        XCTAssertEqual(result["dia_2"], "today")
    }
}
