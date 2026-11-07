import Foundation

/// Único punto de conversión de fechas `timestamptz` de Supabase (ISO 8601).
///
/// PostgREST devuelve p. ej. `2026-03-04T10:20:30.123456+00:00`, pero otros orígenes (la PWA con
/// `toISOString()`, otros clientes) producen `2026-03-04T10:20:30.123Z` o `2026-03-04T10:20:30Z`.
/// `ISO8601DateFormatter` exige elegir con o sin fracciones y no admite `+00`, así que el parser
/// es manual y acepta:
/// - separador `T`, `t` o espacio;
/// - segundos opcionales y fracción de 1 a 9 dígitos (los extra se descartan);
/// - zona `Z`, `±HH:MM`, `±HHMM` o `±HH`; sin zona se asume UTC.
/// Las fechas `date` (`occurred_on`, `start_on`, `end_on`) NO pasan por aquí: son `String` YYYY-MM-DD.
enum SupabaseDate {
    static func parse(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let sep = s.firstIndex(where: { $0 == "T" || $0 == "t" || $0 == " " }) else { return nil }

        // Fecha
        let dateFields = s[s.startIndex..<sep].split(separator: "-", omittingEmptySubsequences: false)
        guard dateFields.count == 3,
              dateFields[0].count == 4, dateFields[1].count == 2, dateFields[2].count == 2,
              let year = int(dateFields[0]), let month = int(dateFields[1]), let day = int(dateFields[2])
        else { return nil }

        // Zona horaria
        var time = s[s.index(after: sep)...]
        var offsetSeconds = 0
        if let last = time.last, last == "Z" || last == "z" {
            time = time.dropLast()
        } else if let idx = time.lastIndex(where: { $0 == "+" || $0 == "-" }) {
            let sign = time[idx] == "-" ? -1 : 1
            let digits = time[time.index(after: idx)...].filter { $0 != ":" }
            guard digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            switch digits.count {
            case 2:
                guard let h = int(digits[...]) else { return nil }
                offsetSeconds = sign * h * 3600
            case 4:
                guard let h = int(digits.prefix(2)), let m = int(digits.suffix(2)), m < 60 else { return nil }
                offsetSeconds = sign * (h * 3600 + m * 60)
            default:
                return nil
            }
            time = time[..<idx]
        }

        // Hora y fracción
        let parts = time.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard let hms = parts.first?.split(separator: ":", omittingEmptySubsequences: false),
              hms.count == 2 || hms.count == 3,
              hms.allSatisfy({ $0.count == 2 }),
              let hour = int(hms[0]), let minute = int(hms[1]),
              let second = hms.count == 3 ? int(hms[2]) : 0,
              hour < 24, minute < 60, second < 60
        else { return nil }

        var fraction = 0.0
        if parts.count == 2 {
            let digits = parts[1]
            guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let f = Double("0." + digits.prefix(9))
            else { return nil }
            fraction = f
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard let base = calendar.date(from: components) else { return nil }
        // Rechaza días inexistentes (p. ej. 30 de febrero), que Calendar normalizaría en silencio.
        let back = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: base)
        guard back.year == year, back.month == month, back.day == day else { return nil }

        return base.addingTimeInterval(fraction - Double(offsetSeconds))
    }

    /// Formato de salida: UTC con milisegundos (igual que `toISOString()` de JavaScript).
    static func format(_ date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func int(_ s: Substring) -> Int? {
        guard !s.isEmpty, s.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(s)
    }
}
