import XCTest

final class GameAchievementsCoachSummaryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        GameTestHelpers.reset()
    }

    private func unlocked(_ c: GameContext) -> [String] {
        GameAchievements.evaluateAchievements(ctx: c).filter(\.unlocked).map(\.id)
    }

    func testNoActivitiesNoAchievements() {
        XCTAssertEqual(unlocked(GameTestHelpers.ctx(today: "2026-03-04")), [])
    }

    func testFirstWorkoutAndRunUnlockSeparately() {
        let wCtx = GameTestHelpers.ctx(today: "2026-03-04", activities: [GameTestHelpers.workout("2026-03-04")])
        XCTAssertTrue(unlocked(wCtx).contains("first_workout"))
        XCTAssertFalse(unlocked(wCtx).contains("first_run"))

        let rCtx = GameTestHelpers.ctx(today: "2026-03-04", activities: [GameTestHelpers.run("2026-03-04")])
        XCTAssertTrue(unlocked(rCtx).contains("first_run"))
    }

    func testStreakAchievementsUseBestStreak() {
        let days = ["2026-02-01", "2026-02-02", "2026-02-03", "2026-02-04"]
        let ids = unlocked(GameTestHelpers.ctx(today: "2026-03-04", activities: GameTestHelpers.activeDays(days)))
        XCTAssertTrue(ids.contains("streak_3"))
        XCTAssertFalse(ids.contains("streak_7"))
    }

    func testSumsKmIgnoringInvalidValues() {
        let runs = [
            GameTestHelpers.run("2026-03-01", distanceKm: 30),
            GameTestHelpers.run("2026-03-02", distanceKm: 25),
            GameTestHelpers.run("2026-03-03", distanceKm: -10)
        ]
        let ids = unlocked(GameTestHelpers.ctx(today: "2026-03-04", activities: runs))
        XCTAssertTrue(ids.contains("km_50"))
        XCTAssertFalse(ids.contains("km_100"))
    }

    func testLongRuns() {
        let ids = unlocked(GameTestHelpers.ctx(today: "2026-03-04", activities: [GameTestHelpers.run("2026-03-04", durationSeconds: 50 * 60)]))
        XCTAssertTrue(ids.contains("run_45"))
        XCTAssertFalse(ids.contains("run_60"))
    }

    func testEarlyBirdRequiresStartedBefore8() {
        let cal = Calendar.current
        let earlyDate = cal.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 7, minute: 0))!
        let lateDate = cal.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 19, minute: 0))!

        let early = GameTestHelpers.run("2026-03-04", startedAt: earlyDate)
        let late = GameTestHelpers.run("2026-03-04", startedAt: lateDate)

        XCTAssertTrue(unlocked(GameTestHelpers.ctx(today: "2026-03-04", activities: [early])).contains("early_bird"))
        XCTAssertFalse(unlocked(GameTestHelpers.ctx(today: "2026-03-04", activities: [late])).contains("early_bird"))
        XCTAssertFalse(unlocked(GameTestHelpers.ctx(today: "2026-03-04", activities: [GameTestHelpers.run("2026-03-04")])).contains("early_bird"))
    }

    func testComebackCounts7DaysGapWithoutVacation() {
        let acts = [GameTestHelpers.rest("2026-03-01"), GameTestHelpers.rest("2026-03-12")]
        XCTAssertTrue(unlocked(GameTestHelpers.ctx(today: "2026-03-12", activities: acts)).contains("comeback"))

        let withVacation = GameTestHelpers.ctx(today: "2026-03-12", activities: acts, vacations: [GameTestHelpers.vacation("2026-03-02", "2026-03-11")])
        XCTAssertFalse(unlocked(withVacation).contains("comeback"))
    }

    func testNewlyUnlocked() {
        let c = GameTestHelpers.ctx(today: "2026-03-04", activities: [GameTestHelpers.workout("2026-03-04"), GameTestHelpers.run("2026-03-04")])
        let nu = GameAchievements.newlyUnlocked(ctx: c, alreadyUnlockedIds: [])
        let ids = Set(nu.map(\.id))
        XCTAssertTrue(ids.contains("first_workout"))
        XCTAssertTrue(ids.contains("first_run"))

        let nuFiltered = GameAchievements.newlyUnlocked(ctx: c, alreadyUnlockedIds: ["first_workout"])
        XCTAssertFalse(nuFiltered.map(\.id).contains("first_workout"))
        XCTAssertTrue(nuFiltered.map(\.id).contains("first_run"))
    }

    func testCoachMessages() {
        XCTAssertEqual(GameCoach.pickCoachMessage(ctx: GameTestHelpers.ctx(today: "2026-03-04")).id, "welcome")

        let vacCtx = GameTestHelpers.ctx(today: "2026-03-04", activities: [GameTestHelpers.rest("2026-03-03")], vacations: [GameTestHelpers.vacation("2026-03-01", nil)])
        XCTAssertEqual(GameCoach.pickCoachMessage(ctx: vacCtx).id, "vacation")

        let vacLong = GameTestHelpers.ctx(today: "2026-03-04", activities: [], vacations: [GameTestHelpers.vacation("2026-01-01", nil)])
        XCTAssertEqual(GameCoach.pickCoachMessage(ctx: vacLong).id, "vacation_long")

        let comeback = GameTestHelpers.ctx(today: "2026-03-03", activities: [GameTestHelpers.rest("2026-02-10")], vacations: [GameTestHelpers.vacation("2026-02-20", "2026-03-01")])
        let msg = GameCoach.pickCoachMessage(ctx: comeback)
        XCTAssertEqual(msg.id, "comeback")
        XCTAssertEqual(msg.mood, .recover)

        let lapse = GameTestHelpers.ctx(today: "2026-03-10", activities: [GameTestHelpers.rest("2026-03-01")])
        XCTAssertEqual(GameCoach.pickCoachMessage(ctx: lapse).id, "lapse")

        let days = ["2026-02-28", "2026-03-01", "2026-03-02", "2026-03-03", "2026-03-04"]
        XCTAssertEqual(GameCoach.pickCoachMessage(ctx: GameTestHelpers.ctx(today: "2026-03-04", activities: GameTestHelpers.activeDays(days))).id, "freeze_earned")

        let risk = GameTestHelpers.ctx(today: "2026-03-04", activities: GameTestHelpers.activeDays(["2026-03-02", "2026-03-03"]))
        XCTAssertEqual(GameCoach.pickCoachMessage(ctx: risk).id, "streak_risk")
    }

    func testComputeGameSummaryEmpty() {
        let s = GameEngine.computeGameSummary(input: GameTestHelpers.ctx(today: "2026-03-04"))
        XCTAssertEqual(s.xp.total, 0)
        XCTAssertEqual(s.level.level, 1)
        XCTAssertEqual(s.streak.current, 0)
        XCTAssertEqual(s.weekly.current, 0)
        XCTAssertEqual(s.coach.id, "welcome")
        XCTAssertTrue(s.achievements.allSatisfy { !$0.unlocked })
    }

    func testComputeGameSummaryDiscardsInvalidOrFutureActivities() {
        let clean = GameEngine.computeGameSummary(input: GameTestHelpers.ctx(today: "2026-03-04", activities: [GameTestHelpers.workout("2026-03-04")]))
        let dirty = GameEngine.computeGameSummary(input: GameTestHelpers.ctx(today: "2026-03-04", activities: [
            GameTestHelpers.workout("2026-03-04"),
            GameTestHelpers.workout("2026-03-20"),
            GameTestHelpers.workout("ayer"),
            GameTestHelpers.workout("2026-13-45"),
            GameTestHelpers.workout("")
        ]))
        XCTAssertEqual(dirty.xp.total, clean.xp.total)
        XCTAssertEqual(dirty.week.workouts, 1)
        XCTAssertEqual(dirty.streak.current, 1)
    }
}
