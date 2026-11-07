import Foundation

// Modelos de dominio de la capa de datos (equivalentes a `src/types/gamification.ts`).
//
// La actividad se llama `ActivityRecord` y no `Activity` porque `ActivityKit` exporta
// `Activity<Attributes>` y `TimerManager` lo usa; un tipo propio `Activity` lo taparía.
//
// Criterio de fechas (ver `SupabaseDate`): los `timestamptz` pasan a `Date`; las fechas `date`
// (`occurredOn`, `startOn`, `endOn`) siguen siendo `String` YYYY-MM-DD, igual que en la PWA.


struct ActivityRecord: Hashable, Identifiable, Sendable {
    /// UUID v4 en minúsculas generado en el cliente: es la clave idempotente del upsert.
    var id: String
    var userId: String?
    var type: ActivityType
    /// YYYY-MM-DD (fecha local)
    var occurredOn: String
    var startedAt: Date?
    var durationSeconds: Int
    var dayId: String?
    var blocksCompleted: Int?
    var roundsTotal: Int?
    var distanceKm: Double?
    var runLocation: RunLocation?
    /// 1 (muy pesado) a 5 (excelente)
    var feeling: Int?
    var caloriesKcal: Double?
    var xpEarned: Int
    var createdAt: Date?
    /// Pulso medio (ppm) medido por el Apple Watch; nil si no hubo medición o la actividad viene de la PWA.
    var avgHeartRateBpm: Int? = nil
}

/// Equivale a `ActivityDraft` de `src/utils/workoutDay.ts`: lo que aporta la UI al terminar un
/// entrenamiento o registrar una carrera; el id, el usuario, el XP y las calorías los pone la capa de datos.
struct ActivityDraft: Hashable, Sendable {
    var type: ActivityType
    var occurredOn: String
    var startedAt: Date?
    var durationSeconds: Int
    var dayId: String?
    var blocksCompleted: Int?
    var roundsTotal: Int?
    var distanceKm: Double?
    var runLocation: RunLocation?
    var feeling: Int?

    init(
        type: ActivityType,
        occurredOn: String,
        startedAt: Date? = nil,
        durationSeconds: Int,
        dayId: String? = nil,
        blocksCompleted: Int? = nil,
        roundsTotal: Int? = nil,
        distanceKm: Double? = nil,
        runLocation: RunLocation? = nil,
        feeling: Int? = nil
    ) {
        self.type = type
        self.occurredOn = occurredOn
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.dayId = dayId
        self.blocksCompleted = blocksCompleted
        self.roundsTotal = roundsTotal
        self.distanceKm = distanceKm
        self.runLocation = runLocation
        self.feeling = feeling
    }
}

struct UserProfile: Hashable, Sendable {
    var userId: String
    var displayName: String?
    var weightKg: Double?
    var createdAt: Date?
    var updatedAt: Date?
}

struct AchievementUnlock: Hashable, Sendable, Codable {
    var userId: String?
    var achievementId: String
    var unlockedAt: Date
}

struct VacationPeriod: Hashable, Identifiable, Sendable, Codable {
    var id: String
    var userId: String?
    /// YYYY-MM-DD
    var startOn: String
    /// YYYY-MM-DD; nil mientras el período está activo
    var endOn: String?
    var createdAt: Date?
}
