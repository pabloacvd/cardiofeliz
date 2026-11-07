import XCTest

final class GameDatesTests: XCTestCase {
    func testValidatesFormatAndRejectsImpossibleDates() {
        XCTAssertTrue(GameDates.isValidDateKey("2026-03-02"))
        XCTAssertFalse(GameDates.isValidDateKey("2026-02-30"))
        XCTAssertFalse(GameDates.isValidDateKey("2026-13-01"))
        XCTAssertFalse(GameDates.isValidDateKey("02/03/2026"))
        XCTAssertFalse(GameDates.isValidDateKey(""))
    }

    func testAddsDaysCrossingMonthsYearsAndLeapYears() {
        XCTAssertEqual(GameDates.addDays("2026-02-28", 1), "2026-03-01")
        XCTAssertEqual(GameDates.addDays("2024-02-28", 1), "2024-02-29")
        XCTAssertEqual(GameDates.addDays("2025-12-31", 1), "2026-01-01")
        XCTAssertEqual(GameDates.addDays("2026-03-01", -1), "2026-02-28")
        XCTAssertEqual(GameDates.diffDays("2026-03-10", "2026-03-01"), 9)
    }

    func testDoesNotDriftWithDaylightSavingTime() {
        XCTAssertEqual(GameDates.addDays("2026-03-07", 1), "2026-03-08")
        XCTAssertEqual(GameDates.addDays("2026-11-01", 1), "2026-11-02")
        XCTAssertEqual(GameDates.eachDay("2026-03-07", "2026-03-10"), [
            "2026-03-07",
            "2026-03-08",
            "2026-03-09",
            "2026-03-10"
        ])
    }

    func testUsesMondayAsFirstDayOfWeek() {
        XCTAssertEqual(GameDates.weekdayIndex("2026-03-02"), 0) // lunes
        XCTAssertEqual(GameDates.weekdayIndex("2026-03-08"), 6) // domingo
        XCTAssertEqual(GameDates.weekStart("2026-03-08"), "2026-03-02")
        XCTAssertEqual(GameDates.weekStart("2026-03-02"), "2026-03-02")
        XCTAssertEqual(GameDates.weekEnd("2026-03-04"), "2026-03-08")
        XCTAssertEqual(GameDates.weekStart("2026-03-09"), "2026-03-09")
    }

    func testNumbersWeeksConsecutively() {
        XCTAssertEqual(GameDates.weekNumber("2026-03-09") - GameDates.weekNumber("2026-03-02"), 1)
        XCTAssertEqual(GameDates.weekNumber("2026-03-08"), GameDates.weekNumber("2026-03-02"))
        XCTAssertEqual(GameDates.weekNumber("2026-01-05") - GameDates.weekNumber("2025-12-29"), 1)
    }

    func testCalculatesIsoWeekIncludingYearBorders() {
        let w1 = GameDates.isoWeek("2026-03-02")
        XCTAssertEqual(w1.year, 2026)
        XCTAssertEqual(w1.week, 10)

        let w2 = GameDates.isoWeek("2026-01-01")
        XCTAssertEqual(w2.year, 2026)
        XCTAssertEqual(w2.week, 1)

        let w3 = GameDates.isoWeek("2021-01-03")
        XCTAssertEqual(w3.year, 2020)
        XCTAssertEqual(w3.week, 53)

        let w4 = GameDates.isoWeek("2024-12-30")
        XCTAssertEqual(w4.year, 2025)
        XCTAssertEqual(w4.week, 1)
    }

    func testEachDayEmptyIfInvertedRange() {
        XCTAssertEqual(GameDates.eachDay("2026-03-05", "2026-03-01"), [])
        XCTAssertEqual(GameDates.eachDay("2026-03-05", "2026-03-05"), ["2026-03-05"])
    }

    func testToDateKeyUsesDeviceLocalDate() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        let d1 = cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 23, minute: 59))!
        let d2 = cal.date(from: DateComponents(year: 2026, month: 3, day: 3, hour: 0, minute: 1))!
        XCTAssertEqual(GameDates.toDateKey(d1, calendar: cal), "2026-03-02")
        XCTAssertEqual(GameDates.toDateKey(d2, calendar: cal), "2026-03-03")
    }
}
