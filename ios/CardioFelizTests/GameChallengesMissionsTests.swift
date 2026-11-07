import XCTest

final class GameChallengesMissionsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        GameTestHelpers.reset()
    }

    private let firstMonday = "2026-03-02"

    private func mondayOf(id: String, activities: [ActivityRecord] = [], vacations: [VacationPeriod] = []) -> String {
        for i in 0..<6 {
            let monday = GameDates.addDays(firstMonday, 7 * i)
            if GameChallenges.evaluateChallenge(ctx: GameTestHelpers.ctx(today: GameDates.weekEnd(monday), activities: activities, vacations: vacations), anyDay: monday).id == id {
                return monday
            }
        }
        XCTFail("El desafío \(id) no aparece en 6 semanas")
        return firstMonday
    }

    func testChallengeIsDeterministic() {
        let c = GameTestHelpers.ctx(today: "2026-03-04", activities: [GameTestHelpers.workout("2026-03-02")])
        XCTAssertEqual(GameChallenges.evaluateChallenge(ctx: c), GameChallenges.evaluateChallenge(ctx: c))
    }

    func testAllDaysInWeekSeeSameChallenge() {
        let c = GameTestHelpers.ctx(today: "2026-03-08")
        let ids = ["2026-03-02", "2026-03-05", "2026-03-08"].map { GameChallenges.evaluateChallenge(ctx: c, anyDay: $0).id }
        XCTAssertEqual(Set(ids).count, 1)
    }

    func testRotationCoversAll6ChallengesWhenFeasible() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let d = cal.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 7))!
        let prior = [GameTestHelpers.run("2026-01-05", distanceKm: 5.0, startedAt: d)]

        var ids = Set<String>()
        for i in 0..<6 {
            let monday = GameDates.addDays(firstMonday, 7 * i)
            ids.insert(GameChallenges.evaluateChallenge(ctx: GameTestHelpers.ctx(today: GameDates.weekEnd(monday), activities: prior), anyDay: monday).id)
        }
        XCTAssertEqual(ids.count, 6)
    }

    func testWithoutHistoryDoesNotOfferImpossibleChallenges() {
        for i in 0..<12 {
            let monday = GameDates.addDays(firstMonday, 7 * i)
            let ch = GameChallenges.evaluateChallenge(ctx: GameTestHelpers.ctx(today: GameDates.weekEnd(monday)), anyDay: monday)
            XCTAssertNotEqual(ch.id, "run_10_km")
            XCTAssertNotEqual(ch.id, "morning_2_days")
        }
    }

    func testKmChallengeAppearsWhenKmRunExists() {
        let prior = [GameTestHelpers.run("2026-01-05", distanceKm: 5.0)]
        let monday = mondayOf(id: "run_10_km", activities: prior)
        XCTAssertFalse(monday.isEmpty)
    }

    func testChallengeProgressAndCompletion() {
        let monday = mondayOf(id: "active_days_5")
        let days = (0..<5).map { GameDates.addDays(monday, $0) }
        let partialActs = days.prefix(3).map { GameTestHelpers.rest($0) }
        let partial = GameChallenges.evaluateChallenge(ctx: GameTestHelpers.ctx(today: GameDates.weekEnd(monday), activities: Array(partialActs)), anyDay: monday)
        XCTAssertEqual(partial.progress, 3.0)
        XCTAssertFalse(partial.done)
        XCTAssertEqual(partial.ratio, 0.6, accuracy: 0.001)

        let fullActs = days.map { GameTestHelpers.rest($0) }
        let full = GameChallenges.evaluateChallenge(ctx: GameTestHelpers.ctx(today: GameDates.weekEnd(monday), activities: fullActs), anyDay: monday)
        XCTAssertTrue(full.done)
        XCTAssertEqual(full.ratio, 1.0)
    }

    func testChallengePausedByVacation() {
        let monday = mondayOf(id: "minutes_150")
        let v = [GameTestHelpers.vacation(monday, GameDates.addDays(monday, 4))]
        let c = GameChallenges.evaluateChallenge(ctx: GameTestHelpers.ctx(today: GameDates.addDays(monday, 6), activities: [], vacations: v), anyDay: monday)
        XCTAssertTrue(c.paused)
        XCTAssertFalse(c.done)
    }

    func testChallengeHiddenIfOnVacationToday() {
        let c = GameChallenges.evaluateChallenge(ctx: GameTestHelpers.ctx(today: "2026-03-04", activities: [], vacations: [GameTestHelpers.vacation("2026-03-01", nil)]))
        XCTAssertTrue(c.hidden)
    }

    func testDailyMissionsOffersBetween2And3() {
        for today in ["2026-03-02", "2026-03-04", "2026-03-08"] {
            let n = GameMissions.pickDailyMissions(ctx: GameTestHelpers.ctx(today: today)).count
            XCTAssertGreaterThanOrEqual(n, 2)
            XCTAssertLessThanOrEqual(n, 3)
        }
    }

    func testDailyMissionsProposesRunAndWorkoutWhenWeekPending() {
        let ids = GameMissions.pickDailyMissions(ctx: GameTestHelpers.ctx(today: "2026-03-04"))
        XCTAssertTrue(ids.contains(.doRun))
        XCTAssertTrue(ids.contains(.doWorkout))
    }

    func testDailyMissionsWhenWeekMet() {
        let week = [
            GameTestHelpers.workout("2026-03-02"),
            GameTestHelpers.workout("2026-03-03"),
            GameTestHelpers.workout("2026-03-04"),
            GameTestHelpers.run("2026-03-05"),
            GameTestHelpers.run("2026-03-06")
        ]
        let ids = GameMissions.pickDailyMissions(ctx: GameTestHelpers.ctx(today: "2026-03-08", activities: week))
        XCTAssertFalse(ids.contains(.doRun))
        XCTAssertFalse(ids.contains(.doWorkout))
        XCTAssertTrue(ids.contains(.anyActivity))
    }

    func testNoMissionsOnVacation() {
        let c = GameTestHelpers.ctx(today: "2026-03-04", activities: [], vacations: [GameTestHelpers.vacation("2026-03-01", nil)])
        XCTAssertEqual(GameMissions.pickDailyMissions(ctx: c), [])
        XCTAssertTrue(GameMissions.evaluateMissions(ctx: c).hidden)
    }

    func testDailyMissionsEvaluatedCorrectly() {
        let result = GameMissions.evaluateMissions(ctx: GameTestHelpers.ctx(today: "2026-03-04", activities: [GameTestHelpers.run("2026-03-04")]))
        XCTAssertTrue(result.missions.first(where: { $0.id == "do_run" })?.done == true)
        XCTAssertFalse(result.missions.first(where: { $0.id == "do_workout" })?.done == true)
        XCTAssertFalse(result.allDone)
    }

    func testAllMissionsDoneAddsBonus() {
        let today = "2026-03-04"
        let day = [GameTestHelpers.workout(today), GameTestHelpers.run(today), GameTestHelpers.rest(today)]
        let result = GameMissions.evaluateMissions(ctx: GameTestHelpers.ctx(today: today, activities: day))
        XCTAssertTrue(result.allDone)
        let base = result.missions.reduce(0) { $0 + $1.xp }
        XCTAssertEqual(result.xpEarned, base + 20)
    }
}
