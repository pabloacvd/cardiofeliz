import XCTest

final class GameWeeksVacationsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        GameTestHelpers.reset()
    }

    private func perfectWeek(_ monday: String) -> [ActivityRecord] {
        let d = { (n: Int) -> String in
            GameDates.addDays(monday, n)
        }
        return [
            GameTestHelpers.workout(d(0)),
            GameTestHelpers.workout(d(2)),
            GameTestHelpers.workout(d(4)),
            GameTestHelpers.run(d(1)),
            GameTestHelpers.run(d(5))
        ]
    }

    func testCountsWorkoutsAndRunsMondayToSunday() {
        let w = GameWeeks.weekProgress(
            ctx: GameTestHelpers.ctx(
                today: "2026-03-04",
                activities: [
                    GameTestHelpers.workout("2026-03-02"),
                    GameTestHelpers.run("2026-03-03"),
                    GameTestHelpers.workout("2026-03-01"),
                    GameTestHelpers.workout("2026-03-09")
                ]
            ),
            anyDay: "2026-03-04"
        )
        XCTAssertEqual(w.workouts, 1)
        XCTAssertEqual(w.runs, 1)
        XCTAssertEqual(w.remainingWorkouts, 2)
        XCTAssertEqual(w.remainingRuns, 1)
        XCTAssertEqual(w.status, .inProgress)
    }

    func testSundayBelongsToEndingWeekAndMondayToNext() {
        let c = GameTestHelpers.ctx(
            today: "2026-03-10",
            activities: [GameTestHelpers.workout("2026-03-08"), GameTestHelpers.workout("2026-03-09")]
        )
        XCTAssertEqual(GameWeeks.weekProgress(ctx: c, anyDay: "2026-03-08").workouts, 1)
        XCTAssertEqual(GameWeeks.weekProgress(ctx: c, anyDay: "2026-03-09").workouts, 1)
    }

    func testRingsDoNotExceedGoalEvenIfOverdone() {
        let w = GameWeeks.weekProgress(
            ctx: GameTestHelpers.ctx(
                today: "2026-03-08",
                activities: [
                    GameTestHelpers.workout("2026-03-02"),
                    GameTestHelpers.workout("2026-03-03"),
                    GameTestHelpers.workout("2026-03-04"),
                    GameTestHelpers.workout("2026-03-05"),
                    GameTestHelpers.run("2026-03-06")
                ]
            ),
            anyDay: "2026-03-08"
        )
        XCTAssertEqual(w.workouts, 4)
        XCTAssertEqual(w.workoutsCapped, 3)
        XCTAssertEqual(w.remainingWorkouts, 0)
    }

    func testGoalMetWith3WorkoutsAnd2Runs() {
        let w = GameWeeks.weekProgress(
            ctx: GameTestHelpers.ctx(today: "2026-03-08", activities: perfectWeek("2026-03-02")),
            anyDay: "2026-03-08"
        )
        XCTAssertTrue(w.met)
        XCTAssertEqual(w.status, .met)
    }

    func testPastWeekUnmetIsMissed() {
        let w = GameWeeks.weekProgress(
            ctx: GameTestHelpers.ctx(today: "2026-03-10", activities: [GameTestHelpers.workout("2026-03-02")]),
            anyDay: "2026-03-02"
        )
        XCTAssertEqual(w.status, .missed)
    }

    func testSumsMinutesAndKm() {
        let w = GameWeeks.weekProgress(
            ctx: GameTestHelpers.ctx(
                today: "2026-03-08",
                activities: [
                    GameTestHelpers.workout("2026-03-02"),
                    GameTestHelpers.run("2026-03-03", distanceKm: 5.5),
                    GameTestHelpers.run("2026-03-04", distanceKm: 4.25)
                ]
            ),
            anyDay: "2026-03-08"
        )
        XCTAssertEqual(w.minutes, 45 + 30 + 30)
        XCTAssertEqual(w.km, 9.75)
    }

    func testCountsConsecutivePerfectWeeks() {
        let acts = perfectWeek("2026-02-23") + perfectWeek("2026-03-02")
        let s = GameWeeks.computeWeeklyStreak(ctx: GameTestHelpers.ctx(today: "2026-03-10", activities: acts))
        XCTAssertEqual(s.current, 2)
        XCTAssertEqual(s.best, 2)
        XCTAssertEqual(s.perfectWeeks, 2)
    }

    func testPastFailedWeekBreaksWeeklyStreak() {
        let acts = perfectWeek("2026-02-23") + [GameTestHelpers.workout("2026-03-03")] + perfectWeek("2026-03-09")
        let s = GameWeeks.computeWeeklyStreak(ctx: GameTestHelpers.ctx(today: "2026-03-17", activities: acts))
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.best, 1)
        XCTAssertEqual(s.perfectWeeks, 2)
    }

    func testCurrentWeekUnmetDoesNotBreakWeeklyStreak() {
        let acts = perfectWeek("2026-02-23") + perfectWeek("2026-03-02") + [GameTestHelpers.workout("2026-03-09")]
        let s = GameWeeks.computeWeeklyStreak(ctx: GameTestHelpers.ctx(today: "2026-03-10", activities: acts))
        XCTAssertEqual(s.current, 2)
    }

    func testWeekPausedByVacationsDoesNotBreakOrAdd() {
        let acts = perfectWeek("2026-02-23") + perfectWeek("2026-03-09")
        let s = GameWeeks.computeWeeklyStreak(ctx: GameTestHelpers.ctx(
            today: "2026-03-17",
            activities: acts,
            vacations: [GameTestHelpers.vacation("2026-03-02", "2026-03-08")]
        ))
        XCTAssertEqual(s.current, 2)
        XCTAssertEqual(s.perfectWeeks, 2)
        XCTAssertEqual(s.weeks.first(where: { $0.weekStart == "2026-03-02" })?.status, .paused)
    }

    func testVacationLessThan4DaysDoesNotPauseWeek() {
        let acts = perfectWeek("2026-02-23") + [GameTestHelpers.workout("2026-03-02")] + perfectWeek("2026-03-09")
        let s = GameWeeks.computeWeeklyStreak(ctx: GameTestHelpers.ctx(
            today: "2026-03-17",
            activities: acts,
            vacations: [GameTestHelpers.vacation("2026-03-05", "2026-03-07")]
        ))
        XCTAssertEqual(s.weeks.first(where: { $0.weekStart == "2026-03-02" })?.status, .missed)
        XCTAssertEqual(s.current, 1)
    }

    func testVacationsDetectsDaysInRange() {
        let v = [GameTestHelpers.vacation("2026-03-03", "2026-03-05")]
        XCTAssertFalse(GameVacations.isOnVacation(day: "2026-03-02", vacations: v))
        XCTAssertTrue(GameVacations.isOnVacation(day: "2026-03-03", vacations: v))
        XCTAssertTrue(GameVacations.isOnVacation(day: "2026-03-05", vacations: v))
        XCTAssertFalse(GameVacations.isOnVacation(day: "2026-03-06", vacations: v))
    }

    func testVacationStatusLongWarning() {
        let v = [GameTestHelpers.vacation("2026-03-01", nil)]
        XCTAssertEqual(GameVacations.vacationStatus(today: "2026-03-01", vacations: v).lengthDays, 1)
        XCTAssertFalse(GameVacations.vacationStatus(today: "2026-03-30", vacations: v).longWarning)
        XCTAssertEqual(GameVacations.vacationStatus(today: "2026-03-31", vacations: v).lengthDays, 31)
        XCTAssertTrue(GameVacations.vacationStatus(today: "2026-03-31", vacations: v).longWarning)
        XCTAssertFalse(GameVacations.vacationStatus(today: "2026-02-20", vacations: v).active)
    }

    func testComebackWindowLasts3Days() {
        let v = [GameTestHelpers.vacation("2026-03-01", "2026-03-10")]
        XCTAssertFalse(GameVacations.comebackStatus(today: "2026-03-10", vacations: v).active)
        let d1 = GameVacations.comebackStatus(today: "2026-03-11", vacations: v)
        XCTAssertTrue(d1.active)
        XCTAssertEqual(d1.dayNumber, 1)
        XCTAssertEqual(d1.daysLeft, 3)
        XCTAssertEqual(d1.endedOn, "2026-03-10")

        let d3 = GameVacations.comebackStatus(today: "2026-03-13", vacations: v)
        XCTAssertTrue(d3.active)
        XCTAssertEqual(d3.dayNumber, 3)
        XCTAssertEqual(d3.daysLeft, 1)

        XCTAssertFalse(GameVacations.comebackStatus(today: "2026-03-14", vacations: v).active)
    }
}
