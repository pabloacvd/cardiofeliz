import Foundation
import Supabase

// Implementaciones reales de los protocolos remotos sobre supabase-swift (PostgREST).
// Cada método replica la consulta del módulo equivalente de `src/lib/*Api.ts`.
// Todos los errores se traducen a `DataLayerError` (sin mensajes del servidor).

/// Ejecuta `body` y traduce cualquier error a `DataLayerError`.
@discardableResult
private func mapped<T>(_ body: () async throws -> T) async throws -> T {
    do {
        return try await body()
    } catch {
        throw SupabaseErrorMapper.map(error, duringSignIn: false)
    }
}

struct SupabaseActivitiesRemote: ActivitiesRemote {
    let client: SupabaseClient

    /// `fetchAllActivities`: orden `occurred_on` desc, luego `id`; páginas de 1000.
    func fetchAll() async throws -> [ActivityRecord] {
        try await mapped {
            let rows = try await Pagination.fetchAll { from, to in
                let page: [ActivityRow] = try await client
                    .from("cf_activities")
                    .select()
                    .order("occurred_on", ascending: false)
                    .order("id")
                    .range(from: from, to: to)
                    .execute()
                    .value
                return page
            }
            return rows.map(Mappers.activity)
        }
    }

    /// `pushActivity`: `upsert(..., onConflict: "id")`.
    func push(_ activity: ActivityRecord, userId: String) async throws {
        try await mapped {
            try await client
                .from("cf_activities")
                .upsert(Mappers.insert(activity, userId: userId), onConflict: "id", returning: .minimal)
                .execute()
        }
    }

    /// `deleteActivityRemote`: borrar una fila inexistente no es un error en PostgREST.
    func delete(id: String) async throws {
        try await mapped {
            try await client.from("cf_activities").delete(returning: .minimal).eq("id", value: id).execute()
        }
    }
}

struct SupabaseProfileRemote: ProfileRemote {
    let client: SupabaseClient

    func fetchProfile(userId: String) async throws -> UserProfile? {
        try await mapped {
            let row: ProfileRow? = try await client
                .from("cf_profiles")
                .select()
                .eq("user_id", value: userId)
                .maybeSingle()
                .execute()
                .value
            return row.map(Mappers.profile)
        }
    }

    private struct WeightRow: Decodable {
        let weightKg: FlexibleDouble?
        enum CodingKeys: String, CodingKey { case weightKg = "weight_kg" }
    }

    func fetchWeightKg(userId: String) async throws -> Double? {
        try await mapped {
            let row: WeightRow? = try await client
                .from("cf_profiles")
                .select("weight_kg")
                .eq("user_id", value: userId)
                .maybeSingle()
                .execute()
                .value
            return row?.weightKg?.value
        }
    }

    /// `pushWeightKg`: `upsert({user_id, weight_kg}, onConflict: "user_id")`.
    func pushWeightKg(userId: String, weightKg: Double) async throws {
        try await mapped {
            try await client
                .from("cf_profiles")
                .upsert(ProfileWeightInsert(userId: userId, weightKg: weightKg), onConflict: "user_id", returning: .minimal)
                .execute()
        }
    }
}

struct SupabaseAchievementsRemote: AchievementsRemote {
    let client: SupabaseClient

    func fetchAll() async throws -> [AchievementUnlock] {
        try await mapped {
            let rows: [AchievementRow] = try await client.from("cf_achievements").select().execute().value
            return rows.compactMap(Mappers.achievement)
        }
    }

    /// `pushAchievements`: `onConflict: "user_id,achievement_id"` + `ignoreDuplicates`. Lista vacía: no-op.
    func push(_ items: [AchievementUnlock], userId: String) async throws {
        guard !items.isEmpty else { return }
        try await mapped {
            try await client
                .from("cf_achievements")
                .upsert(
                    items.map { Mappers.insert($0, userId: userId) },
                    onConflict: "user_id,achievement_id",
                    returning: .minimal,
                    ignoreDuplicates: true
                )
                .execute()
        }
    }
}

struct SupabaseVacationsRemote: VacationsRemote {
    let client: SupabaseClient

    func fetchAll() async throws -> [VacationPeriod] {
        try await mapped {
            let rows: [VacationRow] = try await client
                .from("cf_vacations")
                .select()
                .order("start_on", ascending: false)
                .execute()
                .value
            return rows.map(Mappers.vacation)
        }
    }

    func push(_ vacation: VacationPeriod, userId: String) async throws {
        try await mapped {
            try await client
                .from("cf_vacations")
                .upsert(Mappers.insert(vacation, userId: userId), onConflict: "id", returning: .minimal)
                .execute()
        }
    }

    func delete(id: String) async throws {
        try await mapped {
            try await client.from("cf_vacations").delete(returning: .minimal).eq("id", value: id).execute()
        }
    }
}

struct SupabaseRoutineRemote: RoutineRemote {
    let client: SupabaseClient

    private struct Payload: Decodable {
        let data: RutinaData
        let updatedAt: String
        enum CodingKeys: String, CodingKey {
            case data
            case updatedAt = "updated_at"
        }
    }

    private struct UpdatedAt: Decodable {
        let updatedAt: String
        enum CodingKeys: String, CodingKey { case updatedAt = "updated_at" }
    }

    func fetch(userId: String) async throws -> RemoteRoutine? {
        try await mapped {
            let payload: Payload? = try await client
                .from("cf_routines")
                .select("data, updated_at")
                .eq("user_id", value: userId)
                .maybeSingle()
                .execute()
                .value
            return payload.map { Mappers.routine(data: $0.data, updatedAt: $0.updatedAt) }
        }
    }

    /// `pushRoutine`: upsert por `user_id` y lectura del `updated_at` asignado por el trigger.
    func push(userId: String, data: RutinaData) async throws -> Date? {
        try await mapped {
            let result: UpdatedAt = try await client
                .from("cf_routines")
                .upsert(RoutineInsert(userId: userId, data: data), onConflict: "user_id")
                .select("updated_at")
                .single()
                .execute()
                .value
            return SupabaseDate.parse(result.updatedAt)
        }
    }

    func delete(userId: String) async throws {
        try await mapped {
            try await client.from("cf_routines").delete(returning: .minimal).eq("user_id", value: userId).execute()
        }
    }
}

extension DataRemotes {
    static func supabase(client: SupabaseClient) -> DataRemotes {
        DataRemotes(
            activities: SupabaseActivitiesRemote(client: client),
            profile: SupabaseProfileRemote(client: client),
            achievements: SupabaseAchievementsRemote(client: client),
            vacations: SupabaseVacationsRemote(client: client),
            routine: SupabaseRoutineRemote(client: client)
        )
    }
}
