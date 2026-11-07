import Foundation

/// Utilidades de fechas "de calendario" (sin hora) representadas como texto YYYY-MM-DD.
/// Equivale a `src/gamification/dates.ts`.
typealias DateKey = String

enum GameDates {
    private static let keyRegex = try! NSRegularExpression(pattern: #"^(\d{4})-(\d{2})-(\d{2})$"#)
    private static let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    private static func pad2(_ n: Int) -> String {
        String(format: "%02d", n)
    }

    static func isValidDateKey(_ key: String) -> Bool {
        let range = NSRange(location: 0, length: key.utf16.count)
        guard let match = keyRegex.firstMatch(in: key, options: [], range: range) else {
            return false
        }
        guard let yRange = Range(match.range(at: 1), in: key),
              let mRange = Range(match.range(at: 2), in: key),
              let dRange = Range(match.range(at: 3), in: key),
              let y = Int(key[yRange]),
              let m = Int(key[mRange]),
              let d = Int(key[dRange]) else {
            return false
        }
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = utcCalendar.date(from: comps) else { return false }
        let verified = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return verified.year == y && verified.month == m && verified.day == d
    }

    /// Cantidad de días desde 1970-01-01 (UTC).
    static func dayNumber(_ key: DateKey) -> Int {
        guard isValidDateKey(key) else {
            fatalError("Fecha inválida: \(key)")
        }
        let parts = key.split(separator: "-").compactMap { Int($0) }
        var comps = DateComponents()
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = utcCalendar.date(from: comps) else {
            fatalError("Fecha inválida: \(key)")
        }
        let seconds = date.timeIntervalSince1970
        return Int(round(seconds / 86400.0))
    }

    static func dateFromDayNumber(_ n: Int) -> DateKey {
        let date = Date(timeIntervalSince1970: Double(n) * 86400.0)
        let comps = utcCalendar.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else {
            return "1970-01-01"
        }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func addDays(_ key: DateKey, _ n: Int) -> DateKey {
        dateFromDayNumber(dayNumber(key) + n)
    }

    /// a - b, en días.
    static func diffDays(_ a: DateKey, _ b: DateKey) -> Int {
        dayNumber(a) - dayNumber(b)
    }

    /// Fecha local del dispositivo como clave YYYY-MM-DD.
    static func toDateKey(_ date: Date, calendar: Calendar = .current) -> DateKey {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else {
            return "1970-01-01"
        }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func todayKey(_ now: Date = Date(), calendar: Calendar = .current) -> DateKey {
        toDateKey(now, calendar: calendar)
    }

    /// Índice del día de la semana con lunes = 0 ... domingo = 6.
    static func weekdayIndex(_ key: DateKey) -> Int {
        // 1970-01-01 fue jueves (índice 3 con lunes = 0).
        let d = dayNumber(key)
        return (((d + 3) % 7) + 7) % 7
    }

    /// Lunes de la semana a la que pertenece la fecha.
    static func weekStart(_ key: DateKey) -> DateKey {
        addDays(key, -weekdayIndex(key))
    }

    /// Domingo de la semana a la que pertenece la fecha.
    static func weekEnd(_ key: DateKey) -> DateKey {
        addDays(weekStart(key), 6)
    }

    /// Número de semana consecutivo (estable, útil como semilla de rotación).
    static func weekNumber(_ key: DateKey) -> Int {
        Int(floor(Double(dayNumber(weekStart(key)) + 3) / 7.0))
    }

    /// Semana ISO 8601 (año ISO y número de semana).
    static func isoWeek(_ key: DateKey) -> (year: Int, week: Int) {
        let thursday = addDays(weekStart(key), 3)
        let year = Int(thursday.prefix(4)) ?? 1970
        let week = Int(floor(Double(diffDays(thursday, String(format: "%04d-01-01", year))) / 7.0)) + 1
        return (year, week)
    }

    /// Todas las fechas entre `from` y `to`, ambas inclusive. Vacío si from > to.
    static func eachDay(_ from: DateKey, _ to: DateKey) -> [DateKey] {
        guard from <= to else { return [] }
        let start = dayNumber(from)
        let end = dayNumber(to)
        var out: [DateKey] = []
        out.reserveCapacity(max(0, end - start + 1))
        for n in start...end {
            out.append(dateFromDayNumber(n))
        }
        return out
    }
}
