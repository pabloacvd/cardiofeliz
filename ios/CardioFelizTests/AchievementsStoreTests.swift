import XCTest
@testable import CardioFeliz

@MainActor
final class AchievementsStoreTests: XCTestCase {
    private final class MockAchievementsRemote: AchievementsRemote, @unchecked Sendable {
        var remoteUnlocks: [AchievementUnlock] = []
        var pushed: [[AchievementUnlock]] = []

        func fetchAll() async throws -> [AchievementUnlock] {
            remoteUnlocks
        }

        func push(_ items: [AchievementUnlock], userId: String) async throws {
            pushed.append(items)
            remoteUnlocks.append(contentsOf: items)
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
