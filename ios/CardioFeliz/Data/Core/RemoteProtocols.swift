import Foundation

// Contratos de acceso remoto, uno por módulo de `src/lib/*Api.ts`. Todos lanzan `DataLayerError`.
// La implementación real (supabase-swift) vive en `Data/Supabase/`; los tests usan dobles.

/// `activitiesApi.ts`
protocol ActivitiesRemote: Sendable {
    /// Todo el historial del usuario (RLS limita a sus filas), ordenado por `occurred_on` desc y `id`.
    func fetchAll() async throws -> [ActivityRecord]
    /// Alta o edición. Idempotente: `upsert` por `id` (`onConflict: id`); reintentar nunca duplica.
    func push(_ activity: ActivityRecord, userId: String) async throws
    /// Si la fila ya no existe no es un error.
    func delete(id: String) async throws
}

/// `profileApi.ts` (más la lectura de `display_name` que hace `AuthContext.tsx`).
protocol ProfileRemote: Sendable {
    /// nil si no hay fila.
    func fetchProfile(userId: String) async throws -> UserProfile?
    /// nil si no hay fila o no tiene peso.
    func fetchWeightKg(userId: String) async throws -> Double?
    /// Solo el peso; crea la fila si no existe.
    func pushWeightKg(userId: String, weightKg: Double) async throws
}

/// `achievementsApi.ts`
protocol AchievementsRemote: Sendable {
    func fetchAll() async throws -> [AchievementUnlock]
    /// Idempotente: si ya existen se conservan tal cual (`ignoreDuplicates`; la fecha original no se pisa).
    func push(_ items: [AchievementUnlock], userId: String) async throws
}

/// `vacationsApi.ts`
protocol VacationsRemote: Sendable {
    /// Ordenadas por `start_on` desc.
    func fetchAll() async throws -> [VacationPeriod]
    func push(_ vacation: VacationPeriod, userId: String) async throws
    func delete(id: String) async throws
}

/// `routineApi.ts`
public protocol RoutineRemote: Sendable {
    /// nil si no hay fila guardada.
    func fetch(userId: String) async throws -> RemoteRoutine?
    /// Upsert por `user_id`. Devuelve el `updated_at` asignado por la base de datos.
    func push(userId: String, data: RutinaData) async throws -> Date?
    func delete(userId: String) async throws
}

struct DataRemotes: Sendable {
    var activities: ActivitiesRemote
    var profile: ProfileRemote
    var achievements: AchievementsRemote
    var vacations: VacationsRemote
    var routine: RoutineRemote
}

/// Paginación de `fetchAllActivities`: páginas de 1000 filas hasta recibir una incompleta.
/// PostgREST limita cada respuesta (1000 por defecto en Supabase), por eso hay que paginar.
enum Pagination {
    static let pageSize = 1000

    /// `fetchPage(from, to)` recibe un rango inclusivo (como `.range(from, to)`).
    static func fetchAll<Row>(
        pageSize: Int = Pagination.pageSize,
        fetchPage: (_ from: Int, _ to: Int) async throws -> [Row]
    ) async throws -> [Row] {
        precondition(pageSize > 0)
        var all: [Row] = []
        var from = 0
        while true {
            let page = try await fetchPage(from, from + pageSize - 1)
            all.append(contentsOf: page)
            if page.count < pageSize { break }
            from += pageSize
        }
        return all
    }
}
