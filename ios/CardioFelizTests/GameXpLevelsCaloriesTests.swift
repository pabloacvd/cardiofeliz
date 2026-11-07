import XCTest

final class GameXpLevelsCaloriesTests: XCTestCase {
    override func setUp() {
        super.setUp()
        GameTestHelpers.reset()
    }

    func testEstimateCalories() {
        XCTAssertNil(CaloriesEstimator.estimateCalories(type: .run, durationSeconds: 1800, distanceKm: nil, weightKg: 10))
        XCTAssertNil(CaloriesEstimator.estimateCalories(type: .run, durationSeconds: 1800, distanceKm: nil, weightKg: 500))

        XCTAssertEqual(CaloriesEstimator.estimateCalories(type: .workoutDay, durationSeconds: 3600, distanceKm: nil, weightKg: 60), 480)
        XCTAssertEqual(CaloriesEstimator.estimateCalories(type: .workoutDay, durationSeconds: 1800, distanceKm: nil, weightKg: 70), 280)
        XCTAssertEqual(CaloriesEstimator.estimateCalories(type: .activeRest, durationSeconds: 3600, distanceKm: nil, weightKg: 60), 180)

        let calRun = CaloriesEstimator.estimateCalories(type: .run, durationSeconds: 1800, distanceKm: nil, weightKg: 60)
        XCTAssertEqual(calRun, round(8.3 * 60.0 * 0.5))

        let metRun4 = CaloriesEstimator.metForRun(distanceKm: 4, minutes: 30)
        XCTAssertEqual(metRun4, 8.3, accuracy: 0.001)

        let metRun5 = CaloriesEstimator.metForRun(distanceKm: 5, minutes: 30)
        XCTAssertGreaterThan(metRun5, 9.8)
        XCTAssertLessThan(metRun5, 11.0)
    }

    func testLevelsProgression() {
        XCTAssertEqual(GameLevels.xpForLevel(1), 0)
        let l0 = GameLevels.levelFromXp(0)
        XCTAssertEqual(l0.level, 1)
        XCTAssertEqual(l0.xpIntoLevel, 0)
        XCTAssertEqual(l0.progress, 0.0)

        XCTAssertEqual(GameLevels.xpForLevel(2), 100)
        XCTAssertEqual(GameLevels.xpForLevel(3), 300)
        XCTAssertEqual(GameLevels.xpForLevel(4), 600)

        XCTAssertEqual(GameLevels.levelFromXp(99).level, 1)
        XCTAssertEqual(GameLevels.levelFromXp(100).level, 2)
        XCTAssertEqual(GameLevels.levelFromXp(299).level, 2)
        XCTAssertEqual(GameLevels.levelFromXp(300).level, 3)

        let l200 = GameLevels.levelFromXp(200)
        XCTAssertEqual(l200.level, 2)
        XCTAssertEqual(l200.xpIntoLevel, 100)
        XCTAssertEqual(l200.xpForNextLevel, 200)
        XCTAssertEqual(l200.progress, 0.5, accuracy: 0.001)

        XCTAssertEqual(GameLevels.levelFromXp(-50).level, 1)
    }

    func testTiersAndMascotStages() {
        XCTAssertEqual(GameLevels.tierNameForLevel(1), "Calentando motores")
        XCTAssertEqual(GameLevels.tierNameForLevel(10), "Imparable")
        XCTAssertEqual(GameLevels.tierNameForLevel(99), "Leyenda")

        XCTAssertEqual(GameLevels.mascotStage(1).stage, 1)
        XCTAssertEqual(GameLevels.mascotStage(4).stage, 2)
        XCTAssertEqual(GameLevels.mascotStage(7).stage, 2)
        XCTAssertEqual(GameLevels.mascotStage(8).stage, 3)
        XCTAssertEqual(GameLevels.mascotStage(100).stage, 5)
    }

    func testActivityBaseXp() {
        XCTAssertEqual(GameXp.activityBaseXp(type: .workoutDay, durationSeconds: 0, blocksCompleted: 3, distanceKm: nil), 100)
        XCTAssertEqual(GameXp.activityBaseXp(type: .workoutDay, durationSeconds: 0, blocksCompleted: 5, distanceKm: nil), 120)
        XCTAssertEqual(GameXp.activityBaseXp(type: .workoutDay, durationSeconds: 0, blocksCompleted: 1, distanceKm: nil), 100)
        XCTAssertEqual(GameXp.activityBaseXp(type: .workoutDay, durationSeconds: 0, blocksCompleted: nil, distanceKm: nil), 100)

        XCTAssertEqual(GameXp.activityBaseXp(type: .run, durationSeconds: 30 * 60, blocksCompleted: nil, distanceKm: nil), 60)
        XCTAssertEqual(GameXp.activityBaseXp(type: .run, durationSeconds: 45 * 60, blocksCompleted: nil, distanceKm: nil), 63)
        XCTAssertEqual(GameXp.activityBaseXp(type: .run, durationSeconds: 20 * 60, blocksCompleted: nil, distanceKm: nil), 60)
        XCTAssertEqual(GameXp.activityBaseXp(type: .run, durationSeconds: 30 * 60, blocksCompleted: nil, distanceKm: 4.0), 70)
        XCTAssertEqual(GameXp.activityBaseXp(type: .run, durationSeconds: 24 * 3600, blocksCompleted: nil, distanceKm: nil), 60 + 20)

        XCTAssertEqual(GameXp.activityBaseXp(type: .activeRest, durationSeconds: 600, blocksCompleted: nil, distanceKm: nil), 20)
    }

    func testComputeActivityXpWithComeback() {
        let v = [GameTestHelpers.vacation("2026-03-01", "2026-03-10")]
        let a = GameTestHelpers.workout("2026-03-11")
        XCTAssertEqual(GameXp.computeActivityXp(ctx: GameTestHelpers.ctx(today: "2026-03-11", activities: [a], vacations: v), activity: a), 150)

        let later = GameTestHelpers.workout("2026-03-20")
        XCTAssertEqual(GameXp.computeActivityXp(ctx: GameTestHelpers.ctx(today: "2026-03-20", activities: [later], vacations: v), activity: later), 100)
    }

    func testComputeXpTotal() {
        XCTAssertEqual(GameXp.computeXp(ctx: GameTestHelpers.ctx(today: "2026-03-10")).total, 0)

        let c = GameTestHelpers.ctx(today: "2026-03-02", activities: [GameTestHelpers.workout("2026-03-02")])
        let xp = GameXp.computeXp(ctx: c)
        XCTAssertEqual(xp.activities, 100)
        XCTAssertGreaterThanOrEqual(xp.total, 100)
        XCTAssertEqual(
            xp.total,
            xp.activities + xp.comebackBonus + xp.perfectWeeks + xp.challenges + xp.missions + xp.streakMilestones
        )

        // Multiple active rests on same day
        let one = GameXp.computeXp(ctx: GameTestHelpers.ctx(today: "2026-03-02", activities: [GameTestHelpers.rest("2026-03-02")]))
        let three = GameXp.computeXp(ctx: GameTestHelpers.ctx(today: "2026-03-02", activities: [
            GameTestHelpers.rest("2026-03-02"),
            GameTestHelpers.rest("2026-03-02"),
            GameTestHelpers.rest("2026-03-02")
        ]))
        XCTAssertEqual(three.activities, one.activities)
    }
}
