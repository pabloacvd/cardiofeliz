import Foundation

/// Estado local persistido de las actividades. Mismo modelo que `ActivityCache` de
/// `src/utils/activityCache.ts`: la cola de subida son dos listas de ids.
struct ActivityCache: Equatable {
    var activities: [ActivityRecord] = []
    /// Ids de actividades guardadas localmente que todavía no se subieron (altas y ediciones), en orden.
    var pending: [String] = []
    /// Ids borrados localmente cuyo borrado todavía no se aplicó en Supabase, en orden.
    var deleted: [String] = []
}

/// Persistencia de la cache por usuario (la PWA usa claves de localStorage por usuario).
/// Se usa solo desde el hilo principal.
@MainActor
protocol ActivityCacheStore: AnyObject {
    func load(userId: String) -> ActivityCache
    func save(_ cache: ActivityCache, userId: String)
}

/// Implementación en memoria: para tests y como respaldo si SwiftData no puede abrirse.
@MainActor
final class InMemoryActivityCacheStore: ActivityCacheStore {
    private var caches: [String: ActivityCache] = [:]
    private(set) var saveCount = 0

    init() {}

    func load(userId: String) -> ActivityCache {
        caches[userId] ?? ActivityCache()
    }

    func save(_ cache: ActivityCache, userId: String) {
        caches[userId] = cache
        saveCount += 1
    }
}
