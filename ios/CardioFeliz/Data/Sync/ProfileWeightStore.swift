import Foundation
import Combine

/// Cache local de peso por usuario.
struct WeightCache: Codable, Equatable, Sendable {
    var weightKg: Double?
    var pending: Bool

    init(weightKg: Double?, pending: Bool) {
        self.weightKg = weightKg
        self.pending = pending
    }
}

/// Almacén local de clave-valor para desacoplar `UserDefaults` en tests.
protocol KeyValueStorage: Sendable {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
}

/// Envoltorio sobre `UserDefaults`. No se usa una extensión de `UserDefaults` porque sus
/// métodos `string(forKey:)`/`set(_:forKey:)` ya existen y la extensión acabaría llamándose
/// a sí misma (recursión infinita).
final class UserDefaultsStorage: KeyValueStorage, @unchecked Sendable {
    static let standard = UserDefaultsStorage(UserDefaults.standard)

    private let defaults: UserDefaults

    init(_ defaults: UserDefaults) {
        self.defaults = defaults
    }

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func set(_ value: String?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Almacén en memoria para tests.
final class InMemoryKeyValueStorage: KeyValueStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var dict: [String: String] = [:]

    init(dict: [String: String] = [:]) {
        self.dict = dict
    }

    func string(forKey key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return dict[key]
    }

    func set(_ value: String?, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        if let value {
            dict[key] = value
        } else {
            dict.removeValue(forKey: key)
        }
    }
}

/// Orquestador local-first del peso del usuario. Equivale a `useProfileWeight` en la PWA.
/// El peso se lee/guarda al instante en cache local y se sincroniza en segundo plano con Supabase.
@MainActor
final class ProfileWeightStore: ObservableObject {
    @Published private(set) var weightKg: Double?
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var promptDismissed: Bool = false
    @Published private(set) var isPending: Bool = false

    private let userId: String
    private let remote: ProfileRemote?
    private let storage: KeyValueStorage

    private var isSyncing: Bool = false
    private var weightKey: String { "user_weight_\(userId)" }
    private var promptKey: String { "user_weight_prompt_dismissed_\(userId)" }

    init(
        userId: String,
        remote: ProfileRemote? = nil,
        storage: KeyValueStorage = UserDefaultsStorage.standard
    ) {
        self.userId = userId
        self.remote = remote
        self.storage = storage

        let cached = Self.loadCache(from: storage, key: weightKey)
        self.weightKg = cached.weightKg
        self.isPending = cached.pending
        self.promptDismissed = storage.string(forKey: promptKey) == "true"
        self.isLoaded = cached.weightKg != nil
    }

    /// Inicia la sincronización remota del peso.
    func start() {
        Task { await syncWeight() }
    }

    /// Guarda el peso al instante de forma local-first. Devuelve false si el valor no está en el rango válido (20–300 kg).
    @discardableResult
    func setWeightKg(_ value: Double) -> Bool {
        guard let sanitized = CaloriesEstimator.sanitizeWeight(value) else {
            return false
        }
        let next = WeightCache(weightKg: sanitized, pending: true)
        commit(next)
        Task { await syncWeight() }
        return true
    }

    /// Descarta el aviso inicial para no volver a pedir el peso automáticamente.
    func dismissPrompt() {
        promptDismissed = true
        storage.set("true", forKey: promptKey)
    }

    /// Sincroniza el peso con el servidor.
    func syncWeight() async {
        guard let remote else {
            isLoaded = true
            return
        }
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            if isPending, let current = weightKg {
                try await remote.pushWeightKg(userId: userId, weightKg: current)
                if weightKg == current {
                    commit(WeightCache(weightKg: current, pending: false))
                }
                isLoaded = true
                return
            }

            if let remoteWeight = try await remote.fetchWeightKg(userId: userId) {
                let sanitized = CaloriesEstimator.sanitizeWeight(remoteWeight)
                if sanitized != nil && !isPending {
                    commit(WeightCache(weightKg: sanitized, pending: false))
                }
            }
        } catch {
            // Error de red: se reintentará en el próximo inicio
            AppLog.sync.error("syncWeight failed: \(ErrorSummary.describe(error), privacy: .public)")
        }

        isLoaded = true
    }

    private func commit(_ cache: WeightCache) {
        self.weightKg = cache.weightKg
        self.isPending = cache.pending
        Self.saveCache(cache, to: storage, key: weightKey)
    }

    private static func loadCache(from storage: KeyValueStorage, key: String) -> WeightCache {
        guard let raw = storage.string(forKey: key),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(WeightCache.self, from: data) else {
            return WeightCache(weightKg: nil, pending: false)
        }
        return WeightCache(
            weightKg: CaloriesEstimator.sanitizeWeight(decoded.weightKg),
            pending: decoded.pending
        )
    }

    private static func saveCache(_ cache: WeightCache, to storage: KeyValueStorage, key: String) {
        if let data = try? JSONEncoder().encode(cache),
           let string = String(data: data, encoding: .utf8) {
            storage.set(string, forKey: key)
        }
    }
}
