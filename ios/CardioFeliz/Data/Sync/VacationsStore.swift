import Foundation
import Combine

/// Orquestador local-first de períodos de vacaciones.
/// Equivale a `src/hooks/useVacations.ts`.
@MainActor
final class VacationsStore: ObservableObject {
    @Published private(set) var vacations: [VacationPeriod] = []
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var isSyncing: Bool = false

    private let userId: String
    private let remote: VacationsRemote
    private let storage: KeyValueStorage
    private let storageKey: String

    private struct CachePayload: Codable {
        var vacations: [VacationPeriod]
    }

    init(
        userId: String,
        remote: VacationsRemote,
        storage: KeyValueStorage = UserDefaultsStorage.standard
    ) {
        self.userId = userId
        self.remote = remote
        self.storage = storage
        self.storageKey = "user_vacations_\(userId)"
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
        self.vacations = GameActivities.cleanVacations(payload.vacations)
        self.isLoaded = true
    }

    private func saveToCache() {
        let payload = CachePayload(vacations: vacations)
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else { return }
        storage.set(json, forKey: storageKey)
    }

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let remoteVacations = try await remote.fetchAll()
            let cleaned = GameActivities.cleanVacations(remoteVacations)
            self.vacations = cleaned
            self.isLoaded = true
            saveToCache()
        } catch {
            AppLog.sync.error("Fallo al sincronizar vacaciones: \(ErrorSummary.describe(error), privacy: .public)")
        }
    }

    func startVacation(startOn: DateKey) async throws {
        let id = UUID().uuidString.lowercased()
        let newVacation = VacationPeriod(id: id, startOn: startOn, endOn: nil)
        vacations.insert(newVacation, at: 0)
        vacations = GameActivities.cleanVacations(vacations)
        saveToCache()

        do {
            try await remote.push(newVacation, userId: userId)
        } catch {
            AppLog.sync.error("Fallo al iniciar vacación en servidor: \(ErrorSummary.describe(error), privacy: .public)")
        }
    }

    func endActiveVacation(today: DateKey) async throws {
        guard let idx = vacations.firstIndex(where: { $0.endOn == nil }) else { return }
        var updated = vacations[idx]
        let endOn = max(updated.startOn, today)
        updated.endOn = endOn
        vacations[idx] = updated
        vacations = GameActivities.cleanVacations(vacations)
        saveToCache()

        do {
            try await remote.push(updated, userId: userId)
        } catch {
            AppLog.sync.error("Fallo al finalizar vacación en servidor: \(ErrorSummary.describe(error), privacy: .public)")
        }
    }

    func deleteVacation(id: String) async throws {
        vacations.removeAll { $0.id == id }
        saveToCache()

        do {
            try await remote.delete(id: id)
        } catch {
            AppLog.sync.error("Fallo al eliminar vacación en servidor: \(ErrorSummary.describe(error), privacy: .public)")
        }
    }
}
