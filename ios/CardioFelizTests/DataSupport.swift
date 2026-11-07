import XCTest

// Doble de prueba de `ActivitiesRemote`: simula el servidor (tabla `cf_activities`) en memoria,
// con fallos programables. Sin red ni credenciales.
actor FakeActivitiesRemote: ActivitiesRemote {
    private(set) var server: [String: ActivityRecord] = [:]
    private(set) var pushLog: [String] = []
    private(set) var deleteLog: [String] = []
    private(set) var fetchCount = 0
    private(set) var pushedUserIds: [String] = []

    private var failPush = false
    private var failDelete = false
    private var failFetch = false
    /// El servidor aplica el upsert pero la respuesta "se pierde" (la app cree que falló).
    private var failPushAfterApply = false
    private var onPush: (@Sendable (ActivityRecord) async -> Void)?

    func setFailing(push: Bool? = nil, delete: Bool? = nil, fetch: Bool? = nil, pushAfterApply: Bool? = nil) {
        if let push { failPush = push }
        if let delete { failDelete = delete }
        if let fetch { failFetch = fetch }
        if let pushAfterApply { failPushAfterApply = pushAfterApply }
    }

    func setOffline(_ offline: Bool) {
        failPush = offline
        failDelete = offline
        failFetch = offline
    }

    func setOnPush(_ hook: (@Sendable (ActivityRecord) async -> Void)?) { onPush = hook }

    func seed(_ activities: [ActivityRecord]) {
        for a in activities { server[a.id] = a }
    }

    func fetchAll() async throws -> [ActivityRecord] {
        fetchCount += 1
        if failFetch { throw DataLayerError.network }
        return ActivitySync.sort(Array(server.values))
    }

    func push(_ activity: ActivityRecord, userId: String) async throws {
        if failPush { throw DataLayerError.network }
        pushLog.append(activity.id)
        pushedUserIds.append(userId)
        if let onPush { await onPush(activity) }
        var stored = activity
        stored.userId = activity.userId ?? userId
        server[activity.id] = stored          // upsert por id: nunca duplica
        if failPushAfterApply { throw DataLayerError.network }
    }

    func delete(id: String) async throws {
        if failDelete { throw DataLayerError.network }
        deleteLog.append(id)
        server.removeValue(forKey: id)         // borrar algo inexistente no es un error
    }
}

func makeActivity(
    _ id: String,
    day: String = "2026-03-04",
    type: ActivityType = .run,
    duration: Int = 600,
    xp: Int = 10,
    calories: Double? = nil
) -> ActivityRecord {
    ActivityRecord(
        id: id, userId: "u1", type: type, occurredOn: day, startedAt: nil, durationSeconds: duration,
        dayId: nil, blocksCompleted: nil, roundsTotal: nil, distanceKm: nil, runLocation: nil,
        feeling: nil, caloriesKcal: calories, xpEarned: xp, createdAt: nil
    )
}

func makeDraft(day: String = "2026-03-04", duration: Int = 1800) -> ActivityDraft {
    ActivityDraft(type: .workoutDay, occurredOn: day, durationSeconds: duration, dayId: "dia_1", blocksCompleted: 3)
}

/// Espera (sin bloquear el hilo principal) a que se cumpla una condición.
@MainActor
func eventually(timeout: TimeInterval = 3, _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

/// Variable mutable compartida con closures `@MainActor` (p. ej. el estado de la red simulada).
@MainActor
final class Flag {
    var value: Bool
    init(_ value: Bool) { self.value = value }
}
