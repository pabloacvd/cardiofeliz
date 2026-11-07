import XCTest

final class GameAnalyticsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        GameTestHelpers.reset()
    }

    func testSummaryAndWeekComparison() {
        let context = GameTestHelpers.ctx(
            today: "2026-03-15",
            activities: [
                GameTestHelpers.workout("2026-03-09", durationSeconds: 40 * 60),
                GameTestHelpers.run("2026-03-10", durationSeconds: 30 * 60, distanceKm: 5.0, feeling: 4),
                GameTestHelpers.rest("2026-03-11"),
                GameTestHelpers.workout("2026-03-02", durationSeconds: 45 * 60)
            ],
            weightKg: 65.0
        )

        let summary = GameAnalytics.computeAnalyticsSummary(ctx: context)
        XCTAssertEqual(summary.totalActivities, 4)
        XCTAssertEqual(summary.totalWorkouts, 2)
        XCTAssertEqual(summary.totalRuns, 1)
        XCTAssertEqual(summary.totalActiveRest, 1)
        XCTAssertEqual(summary.totalMinutes, 40 + 30 + 10 + 45)
        XCTAssertEqual(summary.totalKm, 5.0)
        XCTAssertEqual(summary.thisWeek.workouts, 1)
        XCTAssertEqual(summary.prevWeek.workouts, 1)
    }

    func testDailyMinutesBreakdownAndWeeklyHistory() {
        let context = GameTestHelpers.ctx(
            today: "2026-03-15",
            activities: [
                GameTestHelpers.workout("2026-03-15", durationSeconds: 35 * 60),
                GameTestHelpers.run("2026-03-15", durationSeconds: 25 * 60, distanceKm: 4.0)
            ]
        )

        let daily = GameAnalytics.computeDailyMinutes(ctx: context, daysCount: 7)
        XCTAssertEqual(daily.count, 7)
        let todayPoint = daily.last!
        XCTAssertEqual(todayPoint.workoutsMin, 35)
        XCTAssertEqual(todayPoint.runsMin, 25)
        XCTAssertEqual(todayPoint.totalMin, 60)

        let weekly = GameAnalytics.computeWeeklyHistory(ctx: context, weeksCount: 4)
        XCTAssertEqual(weekly.count, 4)
        XCTAssertEqual(weekly.last?.workouts, 1)
        XCTAssertEqual(weekly.last?.runs, 1)
    }

    func testPaceHistoryAndPersonalRecords() {
        let context = GameTestHelpers.ctx(
            today: "2026-03-15",
            activities: [
                GameTestHelpers.run("2026-03-10", durationSeconds: 25 * 60, distanceKm: 5.0, runLocation: .calle),
                GameTestHelpers.run("2026-03-12", durationSeconds: 36 * 60, distanceKm: 6.0, runLocation: .cinta)
            ]
        )

        let pace = GameAnalytics.computePaceHistory(ctx: context)
        XCTAssertEqual(pace.count, 2)
        XCTAssertEqual(pace[0].paceMinKm, 5.0)
        XCTAssertTrue(pace[0].paceFormatted.contains("5:00"))
        XCTAssertEqual(pace[1].paceMinKm, 6.0)

        let records = GameAnalytics.computePersonalRecords(ctx: context)
        XCTAssertEqual(records.longestRunKm, 6.0)
        XCTAssertEqual(records.longestRunMinutes, 36)
        XCTAssertEqual(records.bestPaceMinKm, 5.0)
    }

    func testMonthlyHeatmapGrid() {
        let context = GameTestHelpers.ctx(
            today: "2026-03-15",
            activities: [GameTestHelpers.workout("2026-03-15", durationSeconds: 50 * 60)]
        )

        let heatmap = GameAnalytics.computeMonthlyHeatmap(ctx: context, targetMonthDate: "2026-03-15")
        XCTAssertGreaterThanOrEqual(heatmap.count, 28)
        let day15 = heatmap.first { $0.date == "2026-03-15" }
        XCTAssertNotNil(day15)
        XCTAssertEqual(day15?.intensity, 4)
        XCTAssertTrue(day15?.isToday == true)
    }

    func testTypeDistribution() {
        let context = GameTestHelpers.ctx(
            today: "2026-03-15",
            activities: [
                GameTestHelpers.workout("2026-03-10", durationSeconds: 30 * 60),
                GameTestHelpers.run("2026-03-11", durationSeconds: 20 * 60, runLocation: .cinta),
                GameTestHelpers.rest("2026-03-12")
            ]
        )

        let dist = GameAnalytics.computeTypeDistribution(ctx: context)
        XCTAssertEqual(dist.count, 3)
        XCTAssertEqual(dist.first(where: { $0.name == "Entrenamientos" })?.value, 1)
        XCTAssertEqual(dist.first(where: { $0.name == "Corrida (Cinta)" })?.value, 1)
        XCTAssertEqual(dist.first(where: { $0.name == "Descanso activo" })?.value, 1)
    }
}
