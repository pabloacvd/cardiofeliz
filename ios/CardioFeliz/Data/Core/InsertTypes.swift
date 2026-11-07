import Foundation

// Tipos de escritura (`Insert`) para PostgREST. Espejo de `ActivityInsert`, `AchievementInsert`,
// `VacationInsert`, etc. de `src/types/database.ts`.
//
// Importante: los opcionales se codifican como `null` explícito (no se omiten), igual que
// `toDbActivity` de la PWA (`started_at: domain.startedAt ?? null`). Con `upsert` en modo merge,
// un `null` explícito permite BORRAR un valor al editar una actividad; omitir la clave lo dejaría
// como estaba en el servidor.
//
// Los tipos `Update` de la PWA (`ActivityUpdate`, `VacationUpdate`...) no los usa ningún módulo
// `src/lib/*Api.ts` (todo se hace con `upsert`), así que no se portan.

struct ActivityInsert: Encodable, Equatable {
    var id: String
    var userId: String
    var type: ActivityType
    var occurredOn: String
    var startedAt: String?
    var durationSeconds: Int
    var dayId: String?
    var blocksCompleted: Int?
    var roundsTotal: Int?
    var distanceKm: Double?
    var runLocation: RunLocation?
    var feeling: Int?
    var caloriesKcal: Double?
    var xpEarned: Int
    var avgHeartRateBpm: Int?

    enum CodingKeys: String, CodingKey {
        case id, type, feeling
        case userId = "user_id"
        case occurredOn = "occurred_on"
        case startedAt = "started_at"
        case durationSeconds = "duration_seconds"
        case dayId = "day_id"
        case blocksCompleted = "blocks_completed"
        case roundsTotal = "rounds_total"
        case distanceKm = "distance_km"
        case runLocation = "run_location"
        case caloriesKcal = "calories_kcal"
        case xpEarned = "xp_earned"
        case avgHeartRateBpm = "avg_heart_rate_bpm"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(userId, forKey: .userId)
        try c.encode(type, forKey: .type)
        try c.encode(occurredOn, forKey: .occurredOn)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        try c.encode(dayId, forKey: .dayId)
        try c.encode(blocksCompleted, forKey: .blocksCompleted)
        try c.encode(roundsTotal, forKey: .roundsTotal)
        try c.encode(distanceKm, forKey: .distanceKm)
        try c.encode(runLocation, forKey: .runLocation)
        try c.encode(feeling, forKey: .feeling)
        try c.encode(caloriesKcal, forKey: .caloriesKcal)
        try c.encode(xpEarned, forKey: .xpEarned)
        try c.encode(avgHeartRateBpm, forKey: .avgHeartRateBpm)
    }
}

/// Solo el peso: no envía `display_name`, así que no pisa el nombre existente (como `pushWeightKg`).
struct ProfileWeightInsert: Encodable, Equatable {
    var userId: String
    var weightKg: Double

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case weightKg = "weight_kg"
    }
}

struct AchievementInsert: Encodable, Equatable {
    var userId: String
    var achievementId: String
    var unlockedAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case achievementId = "achievement_id"
        case unlockedAt = "unlocked_at"
    }
}

struct VacationInsert: Encodable, Equatable {
    var id: String
    var userId: String
    var startOn: String
    var endOn: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startOn = "start_on"
        case endOn = "end_on"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(userId, forKey: .userId)
        try c.encode(startOn, forKey: .startOn)
        try c.encode(endOn, forKey: .endOn)
    }
}

struct RoutineInsert: Encodable, Equatable {
    var userId: String
    var data: RutinaData

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case data
    }
}

/// Lo que devuelve `fetchRoutine` (`RemoteRoutine` en `routineApi.ts`).
public struct RemoteRoutine: Equatable, Sendable {
    public var data: RutinaData
    public var updatedAt: Date?

    public init(data: RutinaData, updatedAt: Date? = nil) {
        self.data = data
        self.updatedAt = updatedAt
    }
}
