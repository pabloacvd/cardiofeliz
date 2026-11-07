import Foundation

extension ActivityRecord {
    /// Vista de borrador (sin id, usuario, XP, calorías ni `createdAt`).
    var draft: ActivityDraft {
        ActivityDraft(
            type: type,
            occurredOn: occurredOn,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            dayId: dayId,
            blocksCompleted: blocksCompleted,
            roundsTotal: roundsTotal,
            distanceKm: distanceKm,
            runLocation: runLocation,
            feeling: feeling
        )
    }

    /// Aplica un borrador sobre la actividad conservando id, usuario, XP, calorías y `createdAt`.
    func applying(_ d: ActivityDraft) -> ActivityRecord {
        var copy = self
        copy.type = d.type
        copy.occurredOn = d.occurredOn
        copy.startedAt = d.startedAt
        copy.durationSeconds = d.durationSeconds
        copy.dayId = d.dayId
        copy.blocksCompleted = d.blocksCompleted
        copy.roundsTotal = d.roundsTotal
        copy.distanceKm = d.distanceKm
        copy.runLocation = d.runLocation
        copy.feeling = d.feeling
        return copy
    }
}

/// Validación local previa a guardar. Refleja los `check` de `supabase/schema.sql`: una fila que el
/// servidor rechazaría quedaría atascada para siempre en la cola de subida, así que se corta aquí.
enum ActivityValidation {
    static func validate(_ d: ActivityDraft) throws {
        guard isValidDay(d.occurredOn),
              d.durationSeconds >= 0,
              (d.dayId?.count ?? 0) <= 64,
              (d.blocksCompleted ?? 0) >= 0,
              (d.roundsTotal ?? 0) >= 0,
              (d.distanceKm ?? 0) >= 0, (d.distanceKm ?? 0) < 1000, d.distanceKm?.isFinite ?? true,
              d.feeling.map({ (1...5).contains($0) }) ?? true
        else { throw DataLayerError.invalidInput }
    }

    /// YYYY-MM-DD de un día real del calendario.
    static func isValidDay(_ s: String) -> Bool {
        let parts = s.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: y, month: m, day: d)) else { return false }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        return back.year == y && back.month == m && back.day == d
    }

    /// Fecha local del usuario como YYYY-MM-DD (lo que la PWA llama `occurredOn`).
    static func localDay(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
