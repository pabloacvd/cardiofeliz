import Foundation

// Filas de las tablas `cf_*` (ver `supabase/schema.sql` y `src/types/database.ts`).
// Las claves del JSON de PostgREST son snake_case; se mapean con CodingKeys explícitas
// (sin `keyDecodingStrategy`) para que la sub-tarea 3 pueda usar el decoder que quiera.
//
// Las fechas `date` (occurred_on, start_on, end_on) se mantienen como `String` YYYY-MM-DD,
// igual que en la PWA: son fechas locales sin zona horaria y convertirlas a `Date`
// introduciría desfases. Los `timestamptz` también se dejan como String ISO 8601; la
// conversión a Date la decide la capa de datos (los hay con y sin fracciones de segundo).
//
// `numeric` de Postgres (weight_kg, distance_km, calories_kcal) llega como número JSON
// desde PostgREST, pero puede venir como cadena según el cliente. `FlexibleDouble` acepta ambos.

public enum ActivityType: String, Codable, Hashable, Sendable {
    case workoutDay = "workout_day"
    case run
    case activeRest = "active_rest"
}

public enum RunLocation: String, Codable, Hashable, Sendable {
    case cinta
    case calle
}

/// Decodifica un Double que puede llegar como número o como cadena numérica.
public struct FlexibleDouble: Codable, Hashable, Sendable {
    public var value: Double

    public init(_ value: Double) { self.value = value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) {
            value = d
        } else if let s = try? c.decode(String.self), let d = Double(s) {
            value = d
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Se esperaba un número o una cadena numérica")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}

// MARK: - cf_profiles

public struct ProfileRow: Codable, Hashable {
    public var userId: String
    public var displayName: String?
    public var weightKg: FlexibleDouble?
    public var createdAt: String
    public var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case weightKg = "weight_kg"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - cf_activities

public struct ActivityRow: Codable, Hashable, Identifiable {
    public var id: String
    public var userId: String
    public var type: ActivityType
    /// YYYY-MM-DD (fecha local)
    public var occurredOn: String
    /// ISO 8601
    public var startedAt: String?
    public var durationSeconds: Int
    public var dayId: String?
    public var blocksCompleted: Int?
    public var roundsTotal: Int?
    public var distanceKm: FlexibleDouble?
    public var runLocation: RunLocation?
    /// 1 (muy pesado) a 5 (excelente)
    public var feeling: Int?
    public var caloriesKcal: FlexibleDouble?
    public var xpEarned: Int
    public var createdAt: String
    /// Pulso medio del Apple Watch (`avg_heart_rate_bpm`); ausente en filas anteriores a la migración.
    public var avgHeartRateBpm: Int?

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
        case createdAt = "created_at"
        case avgHeartRateBpm = "avg_heart_rate_bpm"
    }
}

// MARK: - cf_achievements

public struct AchievementRow: Codable, Hashable {
    public var userId: String
    public var achievementId: String
    /// ISO 8601
    public var unlockedAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case achievementId = "achievement_id"
        case unlockedAt = "unlocked_at"
    }
}

// MARK: - cf_vacations

public struct VacationRow: Codable, Hashable, Identifiable {
    public var id: String
    public var userId: String
    /// YYYY-MM-DD
    public var startOn: String
    /// YYYY-MM-DD; nil mientras el período está activo
    public var endOn: String?
    public var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startOn = "start_on"
        case endOn = "end_on"
        case createdAt = "created_at"
    }
}

// MARK: - cf_routines

public struct RoutineRow: Codable, Hashable {
    public var userId: String
    /// jsonb. Se decodifica directamente al modelo tipado.
    public var data: RutinaData
    public var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case data
        case userId = "user_id"
        case updatedAt = "updated_at"
    }
}
