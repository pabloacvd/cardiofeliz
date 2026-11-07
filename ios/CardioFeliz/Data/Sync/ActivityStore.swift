import Foundation
import Combine

/// Estado de sincronización visible. Equivale a `SyncStatus` de `useActivities.ts`.
enum SyncStatus: String, Equatable, Sendable {
    case synced
    case syncing
    /// Hay altas, ediciones o borrados sin subir.
    case pending
    /// Sin cambios pendientes pero el último intento de sincronizar falló (sin red o error del servidor).
    case offline
}

struct AddActivityOptions: Sendable {
    var weightKg: Double?
    var vacations: [VacationPeriod]

    init(weightKg: Double? = nil, vacations: [VacationPeriod] = []) {
        self.weightKg = weightKg
        self.vacations = vacations
    }
}

/// Cálculo de valores derivados (XP y calorías) que en la PWA hacen `computeActivityXp` y
/// `estimateCalories` (módulo `src/gamification`, que se porta en la sub-tarea 8). Se inyecta para
/// que esta capa no dependa de la gamificación. El valor por defecto no calcula nada: XP 0 y sin calorías.
struct ActivityDerivation: Sendable {
    /// Devuelve la actividad con `xpEarned` y `caloriesKcal` calculados. `others` son las demás
    /// actividades (para el bono de regreso).
    var derive: @Sendable (_ activity: ActivityRecord, _ others: [ActivityRecord], _ options: AddActivityOptions) -> ActivityRecord
    /// Calorías estimadas para una actividad con un peso dado; nil si no se pueden estimar.
    var estimateCalories: @Sendable (_ activity: ActivityRecord, _ weightKg: Double) -> Double?

    static let none = ActivityDerivation(
        derive: { activity, _, _ in activity },
        estimateCalories: { _, _ in nil }
    )

    static let withCalories = ActivityDerivation(
        derive: { activity, others, options in
            var copy = activity
            if let weight = options.weightKg {
                copy.caloriesKcal = CaloriesEstimator.estimateCalories(
                    type: activity.type,
                    durationSeconds: activity.durationSeconds,
                    distanceKm: activity.distanceKm,
                    weightKg: weight
                )
            }
            let ctx = GameContext(
                activities: others,
                vacations: options.vacations,
                today: activity.occurredOn,
                weightKg: options.weightKg
            )
            copy.xpEarned = GameXp.computeActivityXp(ctx: ctx, activity: activity)
            return copy
        },
        estimateCalories: { activity, weight in
            CaloriesEstimator.estimateCalories(
                type: activity.type,
                durationSeconds: activity.durationSeconds,
                distanceKm: activity.distanceKm,
                weightKg: weight
            )
        }
    )
}

/// Actividades local-first. Equivale a `useActivities` de `src/hooks/useActivities.ts`:
/// cada actividad se guarda al instante en la cache local y se sube a Supabase en segundo plano.
/// Si no hay conexión queda en cola y se reintenta al abrir, al volver la red, al volver a primer
/// plano y cada minuto mientras haya pendientes. El id lo genera el cliente (UUID), así que
/// reintentar nunca duplica (`upsert` por `id`).
@MainActor
final class ActivityStore: ObservableObject {
    @Published private(set) var activities: [ActivityRecord]
    @Published private(set) var syncStatus: SyncStatus = .synced
    /// Cuántos cambios (altas/ediciones + borrados) esperan subir.
    @Published private(set) var pendingCount: Int = 0
    /// Último momento en que una sincronización terminó sin errores.
    @Published private(set) var lastSyncedAt: Date?

    private var cache: ActivityCache
    private var isSyncing = false
    private var hasSyncError = false
    private var rerun = false

    private let userId: String
    private let remote: ActivitiesRemote
    private let store: ActivityCacheStore
    private let derivation: ActivityDerivation
    private let isOnline: @MainActor () -> Bool
    private let now: @MainActor () -> Date
    private let retryInterval: Duration
    private var retryTask: Task<Void, Never>?

    init(
        userId: String,
        remote: ActivitiesRemote,
        store: ActivityCacheStore,
        derivation: ActivityDerivation = .none,
        isOnline: @escaping @MainActor () -> Bool = { true },
        now: @escaping @MainActor () -> Date = { Date() },
        retryInterval: Duration = .seconds(60)
    ) {
        self.userId = userId
        self.remote = remote
        self.store = store
        self.derivation = derivation
        self.isOnline = isOnline
        self.now = now
        self.retryInterval = retryInterval
        let loaded = store.load(userId: userId)
        self.cache = loaded
        self.activities = loaded.activities
        refreshStatus()
        updateRetryLoop()
    }

    deinit { retryTask?.cancel() }

    // MARK: - Sincronización

    /// Al abrir la app, al volver la conexión y al volver a primer plano.
    func start() { trySync() }

    /// Equivale a `trySync`: si se sabe que no hay red, marca el error sin intentarlo.
    func trySync() {
        guard isOnline() else {
            hasSyncError = true
            refreshStatus()
            return
        }
        Task { await sync() }
    }

    /// Ejecuta una sincronización completa y espera a que termine (los tests la usan directamente).
    /// Si ya hay una en curso, pide otra pasada y vuelve enseguida (como `rerunRef` en la PWA).
    func sync() async {
        if isSyncing {
            rerun = true
            return
        }
        isSyncing = true
        refreshStatus()
        do {
            repeat {
                rerun = false

                // 1. Aplicar borrados pendientes.
                for id in cache.deleted {
                    try await remote.delete(id: id)
                    commit { $0.deleted.removeAll { $0 == id } }
                }

                // 2. Subir pendientes en orden (altas y ediciones).
                for id in cache.pending {
                    let activity = cache.activities.first { $0.id == id }
                    if let activity { try await remote.push(activity, userId: userId) }
                    // Si se editó mientras subía, sigue pendiente con su versión nueva.
                    if cache.activities.first(where: { $0.id == id }) == activity {
                        commit { $0.pending.removeAll { $0 == id } }
                    }
                }

                // 3. Hidratar desde el servidor (otro dispositivo, o primera vez en este).
                let remoteActivities = try await remote.fetchAll()
                commit {
                    $0.activities = ActivitySync.merge(
                        local: $0.activities,
                        remote: remoteActivities,
                        pendingIds: Set($0.pending),
                        deletedIds: Set($0.deleted)
                    )
                }
            } while rerun
            hasSyncError = false
            lastSyncedAt = now()
        } catch {
            hasSyncError = true
            AppLog.sync.error("sync failed: \(ErrorSummary.describe(error), privacy: .public)")
        }
        isSyncing = false
        refreshStatus()
    }

    // MARK: - Operaciones locales (inmediatas)

    /// Guarda la actividad al instante (con XP y calorías calculados) y dispara la subida.
    @discardableResult
    func addActivity(_ draft: ActivityDraft, options: AddActivityOptions = AddActivityOptions()) throws -> ActivityRecord {
        try ActivityValidation.validate(draft)
        let base = ActivityRecord(
            id: ActivitySync.newId(),
            userId: userId,
            type: draft.type,
            occurredOn: draft.occurredOn,
            startedAt: draft.startedAt,
            durationSeconds: draft.durationSeconds,
            dayId: draft.dayId,
            blocksCompleted: draft.blocksCompleted,
            roundsTotal: draft.roundsTotal,
            distanceKm: draft.distanceKm,
            runLocation: draft.runLocation,
            feeling: draft.feeling,
            caloriesKcal: nil,
            xpEarned: 0,
            createdAt: nil
        )
        var activity = derivation.derive(base, cache.activities, options)
        activity.createdAt = now()
        commit {
            $0.activities = ActivitySync.sort($0.activities + [activity])
            $0.pending.append(activity.id)
        }
        trySync()
        return activity
    }

    /// Corrige una actividad ya guardada (recalcula XP y calorías) y la vuelve a subir.
    /// Devuelve nil si el id no existe.
    @discardableResult
    func updateActivity(id: String, patch: (inout ActivityDraft) -> Void, options: AddActivityOptions = AddActivityOptions()) throws -> ActivityRecord? {
        guard let current = cache.activities.first(where: { $0.id == id }) else { return nil }
        var draft = current.draft
        patch(&draft)
        try ActivityValidation.validate(draft)
        let others = cache.activities.filter { $0.id != id }
        let updated = derivation.derive(current.applying(draft), others, options)
        commit {
            $0.activities = ActivitySync.sort($0.activities.map { $0.id == id ? updated : $0 })
            if !$0.pending.contains(id) { $0.pending.append(id) }
        }
        trySync()
        return updated
    }

    /// Fija las calorías medidas por el Apple Watch. No pasa por `derivation.derive`, que las pisaría con la
    /// estimación por MET. Devuelve nil si el id no existe o el valor no es válido.
    @discardableResult
    func setMeasuredCalories(id: String, kcal: Double) -> ActivityRecord? {
        setMeasuredHealth(id: id, kcal: kcal, heartRateBpm: nil)
    }

    /// Fija las calorías y/o el pulso medio medidos por el Apple Watch. Un parámetro nil deja ese valor como
    /// estaba. Valores no válidos (calorías negativas o no finitas, pulso fuera de 20 a 260, que es lo que
    /// admite el `check` del servidor) devuelven nil sin tocar nada: una fila que el servidor rechazaría
    /// quedaría atascada en la cola de subida. Devuelve nil también si el id no existe.
    @discardableResult
    func setMeasuredHealth(id: String, kcal: Double?, heartRateBpm: Int?) -> ActivityRecord? {
        if let kcal, !(kcal.isFinite && kcal >= 0) { return nil }
        if let heartRateBpm, !ActivityValidation.heartRateRange.contains(heartRateBpm) { return nil }
        guard let current = cache.activities.first(where: { $0.id == id }) else { return nil }
        var updated = current
        if let kcal { updated.caloriesKcal = kcal }
        if let heartRateBpm { updated.avgHeartRateBpm = heartRateBpm }
        guard updated != current else { return current }
        commit {
            $0.activities = $0.activities.map { $0.id == id ? updated : $0 }
            if !$0.pending.contains(id) { $0.pending.append(id) }
        }
        trySync()
        return updated
    }

    /// Borra una actividad (por ejemplo, un registro duplicado por error).
    func removeActivity(id: String) {
        commit {
            $0.activities.removeAll { $0.id == id }
            $0.pending.removeAll { $0 == id }
            if !$0.deleted.contains(id) { $0.deleted.append(id) }
        }
        trySync()
    }

    /// Completa las calorías de actividades guardadas sin peso, una vez que el peso se conoce.
    func fillMissingCalories(weightKg: Double) {
        var filled: [String: ActivityRecord] = [:]
        for a in cache.activities where a.caloriesKcal == nil {
            if let kcal = derivation.estimateCalories(a, weightKg) {
                var copy = a
                copy.caloriesKcal = kcal
                filled[a.id] = copy
            }
        }
        guard !filled.isEmpty else { return }
        commit {
            $0.activities = $0.activities.map { filled[$0.id] ?? $0 }
            for a in $0.activities where filled[a.id] != nil && !$0.pending.contains(a.id) {
                $0.pending.append(a.id)
            }
        }
        trySync()
    }

    // MARK: - Interno

    private func commit(_ mutate: (inout ActivityCache) -> Void) {
        mutate(&cache)
        activities = cache.activities
        store.save(cache, userId: userId)
        refreshStatus()
        updateRetryLoop()
    }

    private var hasPending: Bool { !cache.pending.isEmpty || !cache.deleted.isEmpty }

    private func refreshStatus() {
        pendingCount = cache.pending.count + cache.deleted.count
        let next: SyncStatus
        if hasPending {
            next = isSyncing ? .syncing : .pending
        } else if hasSyncError {
            next = .offline
        } else {
            next = isSyncing ? .syncing : .synced
        }
        if syncStatus != next { syncStatus = next }
    }

    /// Reintento periódico solo mientras queden pendientes.
    private func updateRetryLoop() {
        if hasPending {
            guard retryTask == nil else { return }
            let interval = retryInterval
            retryTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    if Task.isCancelled { return }
                    self?.trySync()
                }
            }
        } else {
            retryTask?.cancel()
            retryTask = nil
        }
    }
}
