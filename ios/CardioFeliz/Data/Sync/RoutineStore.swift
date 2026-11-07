import Foundation
import Combine

enum RoutineSyncStatus: String, Sendable, Equatable {
    case synced
    case pending
    case syncing
    case error
}

/// Orquestador local-first de la rutina personalizada del usuario.
/// Equivalente a `useRoutine` en la PWA (`src/hooks/useRoutine.ts`).
/// Los cambios se aplican de inmediato en local y se sincronizan en segundo plano con Supabase.
@MainActor
final class RoutineStore: ObservableObject, RoutineProvider {
    @Published private(set) var rutina: RutinaData
    @Published private(set) var isCustom: Bool
    @Published private(set) var syncStatus: RoutineSyncStatus
    @Published private(set) var isLoaded: Bool = false

    private let userId: String
    private let displayName: String
    private let remote: RoutineRemote?
    private let storage: KeyValueStorage
    private let bundledProvider: RoutineProvider

    private var cache: RoutineCacheState
    private var isSyncing: Bool = false
    private var storageKey: String { "user_routine_\(userId)" }

    init(
        userId: String,
        displayName: String,
        remote: RoutineRemote? = nil,
        storage: KeyValueStorage = UserDefaultsStorage.standard,
        bundledProvider: RoutineProvider = BundledRoutineProvider()
    ) {
        self.userId = userId
        self.displayName = displayName
        self.remote = remote
        self.storage = storage
        self.bundledProvider = bundledProvider

        let loaded = Self.loadCache(from: storage, key: "user_routine_\(userId)")
        self.cache = loaded
        let effective = RoutineSyncLogic.getEffectiveRoutine(
            cache: loaded,
            displayName: displayName,
            provider: bundledProvider
        )
        self.rutina = effective.rutina
        self.isCustom = effective.isCustom
        self.syncStatus = loaded.pendingAction != nil ? .pending : .synced
    }

    // MARK: - RoutineProvider Conformance

    nonisolated func loadRoutine() throws -> RutinaData {
        // En Swift 5/6, lectura segura sincronizada o valor actual
        MainActor.assumeIsolated {
            rutina
        }
    }

    // MARK: - Ciclo de vida y Sincronización

    func start() {
        Task { await sync() }
    }

    func trySync() {
        Task { await sync() }
    }

    func saveRoutine(_ newRutina: RutinaData) async throws {
        let validation = RoutineValidator.validateRutina(newRutina)
        guard validation.isValid else {
            throw DataLayerError.invalidInput
        }

        let normalized = RoutineNormalizer.normalizeRutina(newRutina)
        let nowIso = SupabaseDate.format(Date())
        let next = RoutineCacheState(
            customRoutine: normalized,
            updatedAt: nowIso,
            pendingAction: .save
        )

        commit(next)
        syncStatus = .pending
        await sync()
    }

    func resetRoutine() async throws {
        let nowIso = SupabaseDate.format(Date())
        let next = RoutineCacheState(
            customRoutine: nil,
            updatedAt: nowIso,
            pendingAction: .delete
        )

        commit(next)
        syncStatus = .pending
        await sync()
    }

    func sync() async {
        guard let remote else {
            isLoaded = true
            syncStatus = .synced
            return
        }

        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        syncStatus = .syncing

        do {
            // 1. Procesar borrado pendiente
            if cache.pendingAction == .delete {
                do {
                    try await remote.delete(userId: userId)
                    if cache.pendingAction == .delete {
                        var updated = cache
                        updated.pendingAction = nil
                        commit(updated)
                    }
                } catch {
                    AppLog.sync.error("deleteRoutine failed: \(ErrorSummary.describe(error), privacy: .public)")
                    syncStatus = .pending
                    isLoaded = true
                    return
                }
            }

            // 2. Procesar guardado pendiente
            if cache.pendingAction == .save, let custom = cache.customRoutine {
                let toPush = custom
                do {
                    let remoteUpdatedAt = try await remote.push(userId: userId, data: toPush)
                    if cache.pendingAction == .save && cache.customRoutine == toPush {
                        var updated = cache
                        updated.pendingAction = nil
                        if let remoteUpdatedAt {
                            updated.updatedAt = SupabaseDate.format(remoteUpdatedAt)
                        }
                        commit(updated)
                    }
                } catch {
                    AppLog.sync.error("pushRoutine failed: \(ErrorSummary.describe(error), privacy: .public)")
                    syncStatus = .pending
                    isLoaded = true
                    return
                }
            }

            // 3. Descargar y resolver remoto si no hay acciones pendientes
            if cache.pendingAction == nil {
                let remoteRoutine = try await remote.fetch(userId: userId)
                let resolved = RoutineSyncLogic.resolveRoutineConflict(local: cache, remote: remoteRoutine)
                if resolved != cache {
                    commit(resolved)
                }
            }

            syncStatus = cache.pendingAction != nil ? .pending : .synced
        } catch {
            AppLog.sync.error("routineSync failed: \(ErrorSummary.describe(error), privacy: .public)")
            syncStatus = cache.pendingAction != nil ? .pending : .error
        }

        isLoaded = true
    }

    private func commit(_ next: RoutineCacheState) {
        self.cache = next
        let effective = RoutineSyncLogic.getEffectiveRoutine(
            cache: next,
            displayName: displayName,
            provider: bundledProvider
        )
        self.rutina = effective.rutina
        self.isCustom = effective.isCustom
        Self.saveCache(next, to: storage, key: storageKey)
    }

    private static func loadCache(from storage: KeyValueStorage, key: String) -> RoutineCacheState {
        let raw = storage.string(forKey: key)
        return RoutineSyncLogic.parseAndValidateRoutineCache(raw)
    }

    private static func saveCache(_ state: RoutineCacheState, to storage: KeyValueStorage, key: String) {
        if let data = try? JSONEncoder().encode(state),
           let string = String(data: data, encoding: .utf8) {
            storage.set(string, forKey: key)
        }
    }
}
