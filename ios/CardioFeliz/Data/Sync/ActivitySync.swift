import Foundation

/// Equivalente de `src/utils/activitySync.ts`.
enum ActivitySync {
    /// Ordena de la actividad más reciente a la más antigua (desempate estable por id, descendente).
    static func sort(_ activities: [ActivityRecord]) -> [ActivityRecord] {
        activities.sorted {
            $0.occurredOn == $1.occurredOn ? $0.id > $1.id : $0.occurredOn > $1.occurredOn
        }
    }

    /// Combina el historial remoto con el local.
    /// - El servidor es la fuente de verdad para lo ya sincronizado.
    /// - Las actividades locales todavía pendientes de subir se conservan (y ganan ante el mismo id).
    /// - Las borradas localmente (con borrado pendiente) no reaparecen aunque el servidor aún las tenga.
    static func merge(
        local: [ActivityRecord],
        remote: [ActivityRecord],
        pendingIds: Set<String>,
        deletedIds: Set<String> = []
    ) -> [ActivityRecord] {
        var byId: [String: ActivityRecord] = [:]
        for a in remote { byId[a.id] = a }
        for a in local where pendingIds.contains(a.id) { byId[a.id] = a }
        for id in deletedIds { byId.removeValue(forKey: id) }
        return sort(Array(byId.values))
    }

    /// UUID v4 generado en el cliente, en minúsculas (como `crypto.randomUUID()`): es el id
    /// idempotente de la actividad (upsert sin duplicados).
    static func newId() -> String {
        UUID().uuidString.lowercased()
    }
}
