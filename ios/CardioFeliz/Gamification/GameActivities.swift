import Foundation

/// Modelado y limpieza del contexto de juego.
/// Equivale a `src/gamification/activities.ts`.

struct GameContext: Sendable {
    var activities: [ActivityRecord]
    var vacations: [VacationPeriod]
    /// Fecha local de hoy (YYYY-MM-DD). Inyectada para que el motor sea determinista.
    var today: DateKey
    var weightKg: Double?
    var displayName: String?

    init(
        activities: [ActivityRecord] = [],
        vacations: [VacationPeriod] = [],
        today: DateKey,
        weightKg: Double? = nil,
        displayName: String? = nil
    ) {
        self.activities = activities
        self.vacations = vacations
        self.today = today
        self.weightKg = weightKg
        self.displayName = displayName
    }
}

enum GameActivities {
    /// Descarta actividades con fecha inválida o futura.
    static func cleanActivities(_ activities: [ActivityRecord], today: DateKey) -> [ActivityRecord] {
        activities.filter { a in
            GameDates.isValidDateKey(a.occurredOn) && a.occurredOn <= today
        }
    }

    /// Descarta vacaciones con fechas inválidas o con fin anterior al inicio.
    static func cleanVacations(_ vacations: [VacationPeriod]) -> [VacationPeriod] {
        vacations.filter { v in
            guard GameDates.isValidDateKey(v.startOn) else { return false }
            if let endOn = v.endOn {
                return GameDates.isValidDateKey(endOn) && endOn >= v.startOn
            }
            return true
        }
    }

    static func groupByDay(_ activities: [ActivityRecord]) -> [DateKey: [ActivityRecord]] {
        var map: [DateKey: [ActivityRecord]] = [:]
        for a in activities {
            map[a.occurredOn, default: []].append(a)
        }
        return map
    }

    static func isWorkout(_ a: ActivityRecord) -> Bool {
        a.type == .workoutDay
    }

    static func isRun(_ a: ActivityRecord) -> Bool {
        a.type == .run
    }

    static func safeDouble(_ value: Double?) -> Double {
        guard let value, value.isFinite, value > 0 else { return 0 }
        return value
    }

    static func safeInt(_ value: Int?) -> Int {
        guard let value, value > 0 else { return 0 }
        return value
    }

    /// Hora local (0-23) en la que empezó la actividad, o nil si no se informó o es inválida.
    static func startedHour(_ a: ActivityRecord, calendar: Calendar = .current) -> Int? {
        guard let startedAt = a.startedAt else { return nil }
        return calendar.component(.hour, from: startedAt)
    }

    /// Contexto "a la mañana de `day`": solo actividades anteriores a ese día y `today = day`.
    static func contextBefore(_ ctx: GameContext, day: DateKey) -> GameContext {
        var copy = ctx
        copy.activities = ctx.activities.filter { $0.occurredOn < day }
        copy.today = day
        return copy
    }
}
