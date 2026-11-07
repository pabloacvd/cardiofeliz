import Foundation
import SwiftData

// Cache local de actividades con SwiftData (iOS 17). Solo la usa la app iOS: ni el widget ni el
// Watch dependen de SwiftData.

@Model
final class CachedActivity {
    @Attribute(.unique) var id: String
    var userId: String
    var typeRaw: String
    var occurredOn: String
    var startedAt: Date?
    var durationSeconds: Int
    var dayId: String?
    var blocksCompleted: Int?
    var roundsTotal: Int?
    var distanceKm: Double?
    var runLocationRaw: String?
    var feeling: Int?
    var caloriesKcal: Double?
    var xpEarned: Int
    var createdAt: Date?
    /// Añadido después de la primera versión: opcional, así que SwiftData migra el almacén sin pasos extra.
    var avgHeartRateBpm: Int?
    /// Posición en la cola de subida; nil si ya está sincronizada.
    var pendingOrder: Int?
    /// Id del dueño de la fila local (usuario de la sesión); `ActivityRecord.userId` va en `recordUserId`.
    var recordUserId: String?

    init(_ a: ActivityRecord, ownerId: String, pendingOrder: Int?) {
        self.id = a.id
        self.userId = ownerId
        self.typeRaw = a.type.rawValue
        self.occurredOn = a.occurredOn
        self.startedAt = a.startedAt
        self.durationSeconds = a.durationSeconds
        self.dayId = a.dayId
        self.blocksCompleted = a.blocksCompleted
        self.roundsTotal = a.roundsTotal
        self.distanceKm = a.distanceKm
        self.runLocationRaw = a.runLocation?.rawValue
        self.feeling = a.feeling
        self.caloriesKcal = a.caloriesKcal
        self.xpEarned = a.xpEarned
        self.createdAt = a.createdAt
        self.avgHeartRateBpm = a.avgHeartRateBpm
        self.pendingOrder = pendingOrder
        self.recordUserId = a.userId
    }

    func update(from a: ActivityRecord, pendingOrder: Int?) {
        typeRaw = a.type.rawValue
        occurredOn = a.occurredOn
        startedAt = a.startedAt
        durationSeconds = a.durationSeconds
        dayId = a.dayId
        blocksCompleted = a.blocksCompleted
        roundsTotal = a.roundsTotal
        distanceKm = a.distanceKm
        runLocationRaw = a.runLocation?.rawValue
        feeling = a.feeling
        caloriesKcal = a.caloriesKcal
        xpEarned = a.xpEarned
        createdAt = a.createdAt
        avgHeartRateBpm = a.avgHeartRateBpm
        self.pendingOrder = pendingOrder
        recordUserId = a.userId
    }

    /// nil si el tipo guardado ya no es válido (fila corrupta): se descarta.
    var record: ActivityRecord? {
        guard let type = ActivityType(rawValue: typeRaw) else { return nil }
        return ActivityRecord(
            id: id,
            userId: recordUserId,
            type: type,
            occurredOn: occurredOn,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            dayId: dayId,
            blocksCompleted: blocksCompleted,
            roundsTotal: roundsTotal,
            distanceKm: distanceKm,
            runLocation: runLocationRaw.flatMap(RunLocation.init(rawValue:)),
            feeling: feeling,
            caloriesKcal: caloriesKcal,
            xpEarned: xpEarned,
            createdAt: createdAt,
            avgHeartRateBpm: avgHeartRateBpm
        )
    }
}

@Model
final class CachedDeletion {
    @Attribute(.unique) var id: String
    var userId: String
    var order: Int

    init(id: String, userId: String, order: Int) {
        self.id = id
        self.userId = userId
        self.order = order
    }
}

@MainActor
final class SwiftDataActivityCacheStore: ActivityCacheStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: CachedActivity.self, CachedDeletion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    func load(userId: String) -> ActivityCache {
        do {
            let rows = try context.fetch(FetchDescriptor<CachedActivity>(predicate: #Predicate { $0.userId == userId }))
            let deletions = try context.fetch(FetchDescriptor<CachedDeletion>(predicate: #Predicate { $0.userId == userId }))
            let activities = rows.compactMap(\.record)
            let known = Set(activities.map(\.id))
            let pending = rows
                .filter { $0.pendingOrder != nil && known.contains($0.id) }
                .sorted { ($0.pendingOrder ?? 0) < ($1.pendingOrder ?? 0) }
                .map(\.id)
            let deleted = deletions.sorted { $0.order < $1.order }.map(\.id)
            return ActivityCache(activities: ActivitySync.sort(activities), pending: pending, deleted: deleted)
        } catch {
            AppLog.data.error("cache load failed: \(ErrorSummary.describe(error), privacy: .public)")
            return ActivityCache()
        }
    }

    /// Sincroniza la tabla con `cache` (upsert por id y borrado de lo que ya no está).
    func save(_ cache: ActivityCache, userId: String) {
        do {
            let rows = try context.fetch(FetchDescriptor<CachedActivity>(predicate: #Predicate { $0.userId == userId }))
            var byId = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let pendingIndex = Dictionary(cache.pending.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })

            for activity in cache.activities {
                if let row = byId.removeValue(forKey: activity.id) {
                    row.update(from: activity, pendingOrder: pendingIndex[activity.id])
                } else {
                    context.insert(CachedActivity(activity, ownerId: userId, pendingOrder: pendingIndex[activity.id]))
                }
            }
            for stale in byId.values { context.delete(stale) }

            let deletions = try context.fetch(FetchDescriptor<CachedDeletion>(predicate: #Predicate { $0.userId == userId }))
            for d in deletions { context.delete(d) }
            for (order, id) in cache.deleted.enumerated() {
                context.insert(CachedDeletion(id: id, userId: userId, order: order))
            }
            try context.save()
        } catch {
            // La actividad sigue en memoria y se sube igual (mismo criterio que activityCache.ts).
            AppLog.data.error("cache save failed: \(ErrorSummary.describe(error), privacy: .public)")
        }
    }
}
