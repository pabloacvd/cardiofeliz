import XCTest

final class GameOutcomeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        GameTestHelpers.reset()
    }

    func testLogOutcomeCalculatesGains() {
        let before = GameTestHelpers.ctx(today: "2026-03-04", activities: [])
        let w = GameTestHelpers.workout("2026-03-04")
        let after = GameOutcome.withActivity(ctx: before, activity: w)

        let outcome = GameOutcome.logOutcome(before: before, after: after)
        XCTAssertGreaterThan(outcome.xpGained, 0)
        XCTAssertEqual(outcome.streakBefore, 0)
        XCTAssertEqual(outcome.streakAfter, 1)
        XCTAssertFalse(outcome.newAchievements.isEmpty)
        XCTAssertTrue(outcome.newAchievements.contains { $0.id == "first_workout" })
    }
}
