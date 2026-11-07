import Foundation
import SwiftData
import Combine

/// Raíz de composición de la capa de datos. Lee la configuración, crea el cliente de Supabase (si
/// hay configuración válida), el gestor de sesión y, por cada usuario con sesión, un `ActivityStore`.
@MainActor
final class AppEnvironment: ObservableObject {
    let session: SessionManager
    let network = NetworkMonitor()
    /// nil si Supabase no está configurado.
    let remotes: DataRemotes?
    /// Se crea al iniciar sesión y se destruye al cerrarla. La cache local de cada usuario se conserva.
    @Published private(set) var activityStore: ActivityStore?
    @Published private(set) var profileWeightStore: ProfileWeightStore?
    @Published private(set) var routineStore: RoutineStore?
    @Published private(set) var vacationsStore: VacationsStore?
    @Published private(set) var achievementsStore: AchievementsStore?

    private let modelContainer: ModelContainer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let config = SupabaseConfig.fromBundle()
        if let config {
            let client = SupabaseClientFactory.make(config: config)
            remotes = .supabase(client: client)
            session = SessionManager(backend: SupabaseAuthBackend(client: client))
            AppLog.config.info("Supabase configurado: \(config.description, privacy: .public)")
        } else {
            remotes = nil
            session = SessionManager(backend: nil)
            AppLog.config.notice("Supabase sin configurar: faltan SUPABASE_URL o SUPABASE_ANON_KEY en Config.xcconfig")
        }

        do {
            modelContainer = try SwiftDataActivityCacheStore.makeContainer()
        } catch {
            modelContainer = nil
            AppLog.data.error("SwiftData no disponible, cache en memoria: \(ErrorSummary.describe(error), privacy: .public)")
        }

        session.$state
            .map(\.userId)
            .removeDuplicates()
            .sink { [weak self] userId in self?.userChanged(userId) }
            .store(in: &cancellables)

        network.onReconnect = { [weak self] in
            self?.activityStore?.trySync()
            self?.routineStore?.trySync()
            Task { @MainActor [weak self] in
                await self?.vacationsStore?.sync()
                await self?.achievementsStore?.sync()
            }
        }
        session.start()
    }

    /// Al volver la app a primer plano (equivale a `visibilitychange` de la PWA).
    func appBecameActive() {
        activityStore?.trySync()
        routineStore?.trySync()
        Task { @MainActor [weak self] in
            await self?.vacationsStore?.sync()
            await self?.achievementsStore?.sync()
        }
    }

    private func userChanged(_ userId: String?) {
        guard let userId, let remotes else {
            activityStore = nil
            profileWeightStore = nil
            routineStore = nil
            vacationsStore = nil
            achievementsStore = nil
            return
        }
        let cacheStore: ActivityCacheStore = modelContainer.map {
            SwiftDataActivityCacheStore(context: $0.mainContext)
        } ?? InMemoryActivityCacheStore()
        let network = self.network
        let weightStore = ProfileWeightStore(userId: userId, remote: remotes.profile)
        self.profileWeightStore = weightStore
        weightStore.start()

        let username = session.state.username ?? "Usuario"
        let rStore = RoutineStore(
            userId: userId,
            displayName: username,
            remote: remotes.routine,
            storage: UserDefaultsStorage.standard
        )
        self.routineStore = rStore
        rStore.start()

        let vStore = VacationsStore(
            userId: userId,
            remote: remotes.vacations,
            storage: UserDefaultsStorage.standard
        )
        self.vacationsStore = vStore
        vStore.start()

        let aStore = AchievementsStore(
            userId: userId,
            remote: remotes.achievements,
            storage: UserDefaultsStorage.standard
        )
        self.achievementsStore = aStore
        aStore.start()

        let store = ActivityStore(
            userId: userId,
            remote: remotes.activities,
            store: cacheStore,
            derivation: .withCalories,
            isOnline: { network.isOnline }
        )
        activityStore = store
        store.start()
    }
}
