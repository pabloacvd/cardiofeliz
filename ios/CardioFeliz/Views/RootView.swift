import SwiftUI

/// Raíz de la UI: decide qué mostrar según el estado de sesión.
struct RootView: View {
    @ObservedObject var env: AppEnvironment
    @ObservedObject var session: SessionManager
    @StateObject private var workflow = WorkoutWorkflowViewModel(defaults: .standard)

    #if DEBUG
    @State private var isDebugDemoMode = true
    #endif

    init(env: AppEnvironment) {
        self.env = env
        self.session = env.session
    }

    var body: some View {
        #if DEBUG
        if isDebugDemoMode {
            WorkoutFlowContainerView(
                workflow: workflow,
                activityStore: makeDebugActivityStore(),
                weightStore: makeDebugWeightStore(),
                routineStore: makeDebugRoutineStore(),
                vacationsStore: makeDebugVacationsStore(),
                achievementsStore: makeDebugAchievementsStore(),
                session: session
            )
        } else {
            rootContent
        }
        #else
        rootContent
        #endif
    }

    @ViewBuilder
    private var rootContent: some View {
        switch session.state {
        case .loading:
            ProgressView("Cargando…")
        case .unconfigured:
            #if DEBUG
            UnconfiguredView(onEnableDebugDemo: { isDebugDemoMode = true })
            #else
            UnconfiguredView()
            #endif
        case .signedOut:
            #if DEBUG
            LoginView(session: session, onEnableDebugDemo: { isDebugDemoMode = true })
            #else
            LoginView(session: session)
            #endif
        case .signedIn:
            if let store = env.activityStore,
               let weightStore = env.profileWeightStore,
               let routineStore = env.routineStore,
               let vacationsStore = env.vacationsStore,
               let achievementsStore = env.achievementsStore {
                WorkoutFlowContainerView(
                    workflow: workflow,
                    activityStore: store,
                    weightStore: weightStore,
                    routineStore: routineStore,
                    vacationsStore: vacationsStore,
                    achievementsStore: achievementsStore,
                    session: session
                )
            } else {
                ProgressView("Iniciando…")
            }
        }
    }

    #if DEBUG
    private func makeDebugActivityStore() -> ActivityStore {
        final class MockActivitiesRemote: ActivitiesRemote, @unchecked Sendable {
            func fetchAll() async throws -> [ActivityRecord] { [] }
            func push(_ activity: ActivityRecord, userId: String) async throws {}
            func delete(id: String) async throws {}
        }
        return ActivityStore(
            userId: "debug_user",
            remote: MockActivitiesRemote(),
            store: InMemoryActivityCacheStore(),
            derivation: .withCalories
        )
    }

    private func makeDebugWeightStore() -> ProfileWeightStore {
        final class MockProfileRemote: ProfileRemote, @unchecked Sendable {
            func fetchProfile(userId: String) async throws -> UserProfile? { nil }
            func fetchWeightKg(userId: String) async throws -> Double? { 62.5 }
            func pushWeightKg(userId: String, weightKg: Double) async throws {}
        }
        return ProfileWeightStore(
            userId: "debug_user",
            remote: MockProfileRemote(),
            storage: InMemoryKeyValueStorage(dict: [
                "user_weight_debug_user": "{\"weightKg\":62.5,\"pending\":false}"
            ])
        )
    }

    private func makeDebugRoutineStore() -> RoutineStore {
        final class MockRoutineRemote: RoutineRemote, @unchecked Sendable {
            func fetch(userId: String) async throws -> RemoteRoutine? { nil }
            func push(userId: String, data: RutinaData) async throws -> Date? { Date() }
            func delete(userId: String) async throws {}
        }
        return RoutineStore(
            userId: "debug_user",
            displayName: "Debug User",
            remote: MockRoutineRemote(),
            storage: InMemoryKeyValueStorage()
        )
    }

    private func makeDebugVacationsStore() -> VacationsStore {
        final class MockVacationsRemote: VacationsRemote, @unchecked Sendable {
            func fetchAll() async throws -> [VacationPeriod] { [] }
            func push(_ vacation: VacationPeriod, userId: String) async throws {}
            func delete(id: String) async throws {}
        }
        return VacationsStore(
            userId: "debug_user",
            remote: MockVacationsRemote(),
            storage: InMemoryKeyValueStorage()
        )
    }

    private func makeDebugAchievementsStore() -> AchievementsStore {
        final class MockAchievementsRemote: AchievementsRemote, @unchecked Sendable {
            func fetchAll() async throws -> [AchievementUnlock] { [] }
            func push(_ items: [AchievementUnlock], userId: String) async throws {}
        }
        return AchievementsStore(
            userId: "debug_user",
            remote: MockAchievementsRemote(),
            storage: InMemoryKeyValueStorage()
        )
    }
    #endif
}
