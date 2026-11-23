import XCTest

@MainActor
final class AchievementsStoreTests: XCTestCase {
    private final class MockAchievementsRemote: AchievementsRemote, @unchecked Sendable {
        // `claimNew` lanza una subida por llamada y se ejecutan en paralelo: el estado se protege con un lock.
        private let lock = NSLock()
        private var _remoteUnlocks: [AchievementUnlock] = []
        private var _pushed: [[AchievementUnlock]] = []

        var remoteUnlocks: [AchievementUnlock] {
            get { lock.withLock { _remoteUnlocks } }
            set { lock.withLock { _remoteUnlocks = newValue } }
        }
        var pushed: [[AchievementUnlock]] { lock.withLock { _pushed } }

        func fetchAll() async throws -> [AchievementUnlock] {
            remoteUnlocks
        }

        func push(_ items: [AchievementUnlock], userId: String) async throws {
            lock.withLock {
                _pushed.append(items)
                _remoteUnlocks.append(contentsOf: items)
            }
        }
    }

    func testClaimNewUnlocksAndReturnsOnlyTrulyNew() {
        let remote = MockAchievementsRemote()
        let storage = InMemoryKeyValueStorage()
        let store = AchievementsStore(userId: "user_1", remote: remote, storage: storage)

        let claimed1 = store.claimNew(ids: ["first_workout", "first_run"])
        XCTAssertEqual(claimed1.count, 2)
        XCTAssertNotNil(store.unlockedAt["first_workout"])
        XCTAssertNotNil(store.unlockedAt["first_run"])

        let claimed2 = store.claimNew(ids: ["first_workout", "streak_3"])
        XCTAssertEqual(claimed2, ["streak_3"])
    }

    func testSyncLoadsRemoteAchievements() async throws {
        let remote = MockAchievementsRemote()
        let date = Date()
        remote.remoteUnlocks = [
            AchievementUnlock(achievementId: "first_workout", unlockedAt: date)
        ]
        let storage = InMemoryKeyValueStorage()
        let store = AchievementsStore(userId: "user_1", remote: remote, storage: storage)

        await store.sync()

        XCTAssertEqual(store.unlockedAt.count, 1)
        XCTAssertNotNil(store.unlockedAt["first_workout"])

        // Test persistence across store reload
        let store2 = AchievementsStore(userId: "user_1", remote: remote, storage: storage)
        XCTAssertEqual(store2.unlockedAt.count, 1)
        XCTAssertNotNil(store2.unlockedAt["first_workout"])
    }
}
