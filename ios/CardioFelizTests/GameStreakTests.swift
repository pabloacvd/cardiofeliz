import XCTest

final class GameStreakTests: XCTestCase {
    override func setUp() {
        super.setUp()
        GameTestHelpers.reset()
    }

    func testNoActivitiesNoStreak() {
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(today: "2026-03-10"))
        XCTAssertEqual(s.current, 0)
        XCTAssertEqual(s.best, 0)
        XCTAssertFalse(s.atRisk)
        XCTAssertNil(s.lastActiveDay)
    }

    func testCountsConsecutiveDaysIncludingToday() {
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(
            today: "2026-03-04",
            activities: GameTestHelpers.activeDays(["2026-03-02", "2026-03-03", "2026-03-04"])
        ))
        XCTAssertEqual(s.current, 3)
        XCTAssertTrue(s.activeToday)
        XCTAssertFalse(s.atRisk)
    }

    func testTodayWithoutActivityDoesNotBreakStreakButPutsAtRisk() {
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(
            today: "2026-03-04",
            activities: GameTestHelpers.activeDays(["2026-03-02", "2026-03-03"])
        ))
        XCTAssertEqual(s.current, 2)
        XCTAssertTrue(s.atRisk)
        XCTAssertFalse(s.activeToday)
    }

    func testMultipleActivitiesInSameDayCountAsOne() {
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(
            today: "2026-03-03",
            activities: [
                GameTestHelpers.workout("2026-03-02"),
                GameTestHelpers.run("2026-03-02"),
                GameTestHelpers.rest("2026-03-02"),
                GameTestHelpers.rest("2026-03-03")
            ]
        ))
        XCTAssertEqual(s.current, 2)
    }

    func testAnyActivitySustainsStreak() {
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(
            today: "2026-03-04",
            activities: [
                GameTestHelpers.workout("2026-03-02"),
                GameTestHelpers.run("2026-03-03"),
                GameTestHelpers.rest("2026-03-04")
            ]
        ))
        XCTAssertEqual(s.current, 3)
    }

    func testGapWithoutFreezesBreaksStreakConservingBest() {
        var acts = GameTestHelpers.activeDays(["2026-03-02", "2026-03-03", "2026-03-04"])
        acts.append(GameTestHelpers.rest("2026-03-08"))
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(today: "2026-03-10", activities: acts))
        XCTAssertEqual(s.best, 3)
        XCTAssertEqual(s.current, 0)
    }

    func testEarnsFreezeEvery5Days() {
        let days = ["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05", "2026-03-06"]
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(today: "2026-03-06", activities: GameTestHelpers.activeDays(days)))
        XCTAssertEqual(s.current, 5)
        XCTAssertEqual(s.freezes, 1)
        XCTAssertEqual(s.freezesEarned, 1)
        XCTAssertTrue(s.earnedFreezeToday)
    }

    func testFreezeAutoUsedSavesMissingDay() {
        var days = GameTestHelpers.activeDays(["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05", "2026-03-06"])
        days.append(GameTestHelpers.rest("2026-03-08"))
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(today: "2026-03-08", activities: days))
        XCTAssertEqual(s.freezesUsedOn, ["2026-03-07"])
        XCTAssertEqual(s.freezes, 0)
        XCTAssertEqual(s.current, 6)
        XCTAssertEqual(s.best, 6)
    }

    func testNeverAccumulatesMoreThan2Freezes() {
        let days = (2...16).map { String(format: "2026-03-%02d", $0) }
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(today: days.last!, activities: GameTestHelpers.activeDays(days)))
        XCTAssertEqual(s.current, 15)
        XCTAssertEqual(s.freezesEarned, 2)
        XCTAssertEqual(s.freezes, 2)
    }

    func testTwoMissingDaysWithOneFreezeBreaksStreak() {
        let days = ["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05", "2026-03-06"]
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(today: "2026-03-10", activities: GameTestHelpers.activeDays(days)))
        XCTAssertEqual(s.freezesUsedOn, ["2026-03-07"])
        XCTAssertEqual(s.current, 0)
        XCTAssertEqual(s.best, 5)
    }

    func testMilestonesWithBonus() {
        let days = ["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05"]
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(today: "2026-03-05", activities: GameTestHelpers.activeDays(days)))
        XCTAssertEqual(s.milestones.count, 1)
        XCTAssertEqual(s.milestones.first?.day, "2026-03-04")
        XCTAssertEqual(s.milestones.first?.value, 3)
    }

    func testVacationsDoNotBreakStreakOrConsumeFreezes() {
        var days = GameTestHelpers.activeDays(["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05", "2026-03-06"])
        days.append(GameTestHelpers.rest("2026-03-12"))
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(
            today: "2026-03-12",
            activities: days,
            vacations: [GameTestHelpers.vacation("2026-03-07", "2026-03-11")]
        ))
        XCTAssertEqual(s.freezesUsedOn, [])
        XCTAssertEqual(s.freezes, 1)
        XCTAssertEqual(s.current, 6)
    }

    func testVacationDaysDoNotAddToStreak() {
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(
            today: "2026-03-12",
            activities: [GameTestHelpers.rest("2026-03-02"), GameTestHelpers.rest("2026-03-12")],
            vacations: [GameTestHelpers.vacation("2026-03-03", "2026-03-11")]
        ))
        XCTAssertEqual(s.current, 2)
    }

    func testOpenVacationFreezesUntilToday() {
        let s = GameStreak.computeStreak(ctx: GameTestHelpers.ctx(
            today: "2026-03-20",
            activities: GameTestHelpers.activeDays(["2026-03-02", "2026-03-03"]),
            vacations: [GameTestHelpers.vacation("2026-03-04", nil)]
        ))
        XCTAssertEqual(s.current, 2)
        XCTAssertFalse(s.atRisk)
        XCTAssertEqual(s.freezesUsedOn, [])
    }
}
