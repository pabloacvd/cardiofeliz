import Foundation
import Combine

/// Orquestador de logros e insignias del usuario.
/// Equivale a `src/hooks/useAchievements.ts`.
@MainActor
final class AchievementsStore: ObservableObject {
    @Published private(set) var unlockedAt: [String: String] = [:]
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var isSyncing: Bool = false

    private let userId: String
    private let remote: AchievementsRemote
    private let storage: KeyValueStorage
    private let storageKey: String

    private struct CachePayload: Codable {
        var unlockedAt: [String: String]
    }

    init(
        userId: String,
        remote: AchievementsRemote,
        storage: KeyValueStorage = UserDefaultsStorage.standard
    ) {
        self.userId = userId
        self.remote = remote
        self.storage = storage
        self.storageKey = "user_achievements_\(userId)"
        loadFromCache()
    }

    func start() {
        Task { [weak self] in
            await self?.sync()
        }
    }

    private func loadFromCache() {
        guard let json = storage.string(forKey: storageKey),
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(CachePayload.self, from: data) else {
            return
        }
        self.unlockedAt = payload.unlockedAt
        self.isLoaded = true
    }

    private func saveToCache() {
        let payload = CachePayload(unlockedAt: unlockedAt)
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else { return }
        storage.set(json, forKey: storageKey)
    }

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let remoteUnlocks = try await remote.fetchAll()
            var map = unlockedAt
            for u in remoteUnlocks {
                if map[u.achievementId] == nil {
                    map[u.achievementId] = SupabaseDate.format(u.unlockedAt)
                }
            }
            self.unlockedAt = map
            self.isLoaded = true
            saveToCache()
        } catch {
            AppLog.sync.error("Fallo al sincronizar logros: \(ErrorSummary.describe(error), privacy: .public)")
        }
    }

    /// Registra localmente los logros que acaban de desbloquearse y los sube en segundo plano.
    /// Devuelve los IDs que realmente eran nuevos (para celebrar solo una vez).
    @discardableResult
    func claimNew(ids: [String]) -> [String] {
        guard !ids.isEmpty else { return [] }
        let now = Date()
        let nowIso = SupabaseDate.format(now)
        var newlyClaimed: [String] = []
        var toPush: [AchievementUnlock] = []

        for id in ids {
            if unlockedAt[id] == nil {
                unlockedAt[id] = nowIso
                newlyClaimed.append(id)
                toPush.append(AchievementUnlock(achievementId: id, unlockedAt: now))
            }
        }

        guard !newlyClaimed.isEmpty else { return [] }
        saveToCache()

        Task { [userId, remote] in
            do {
                try await remote.push(toPush, userId: userId)
            } catch {
                AppLog.sync.error("Fallo al guardar logros en servidor: \(ErrorSummary.describe(error), privacy: .public)")
            }
        }

        return newlyClaimed
    }
}
