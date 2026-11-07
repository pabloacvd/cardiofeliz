import XCTest
@testable import CardioFeliz

@MainActor
final class VacationsStoreTests: XCTestCase {
    private final class MockVacationsRemote: VacationsRemote, @unchecked Sendable {
        var remoteVacations: [VacationPeriod] = []
        var pushed: [VacationPeriod] = []
        var deletedIds: [String] = []

        func fetchAll() async throws -> [VacationPeriod] {
            remoteVacations
        }

        func push(_ vacation: VacationPeriod, userId: String) async throws {
            pushed.append(vacation)
            if let idx = remoteVacations.firstIndex(where: { $0.id == vacation.id }) {
                remoteVacations[idx] = vacation
            } else {
                remoteVacations.insert(vacation, at: 0)
            }
        }

        func delete(id: String) async throws {
            deletedIds.append(id)
            remoteVacations.removeAll { $0.id == id }
        }
    }

    func testStartVacationAddsLocallyAndPushesToRemote() async throws {
        let remote = MockVacationsRemote()
        let storage = InMemoryKeyValueStorage()
        let store = VacationsStore(userId: "user_1", remote: remote, storage: storage)

        try await store.startVacation(startOn: "2026-06-01")

        XCTAssertEqual(store.vacations.count, 1)
        XCTAssertEqual(store.vacations.first?.startOn, "2026-06-01")
        XCTAssertNil(store.vacations.first?.endOn)
        XCTAssertEqual(remote.pushed.count, 1)
    }

    func testEndActiveVacationSetsEndOn() async throws {
        let remote = MockVacationsRemote()
        let storage = InMemoryKeyValueStorage()
        let store = VacationsStore(userId: "user_1", remote: remote, storage: storage)

        try await store.startVacation(startOn: "2026-06-01")
        try await store.endActiveVacation(today: "2026-06-10")

        XCTAssertEqual(store.vacations.count, 1)
        XCTAssertEqual(store.vacations.first?.startOn, "2026-06-01")
        XCTAssertEqual(store.vacations.first?.endOn, "2026-06-10")
        XCTAssertEqual(remote.pushed.count, 2)
    }

    func testDeleteVacationRemovesFromStoreAndRemote() async throws {
        let remote = MockVacationsRemote()
        let storage = InMemoryKeyValueStorage()
        let store = VacationsStore(userId: "user_1", remote: remote, storage: storage)

        try await store.startVacation(startOn: "2026-06-01")
        let id = store.vacations.first!.id

        try await store.deleteVacation(id: id)

        XCTAssertTrue(store.vacations.isEmpty)
        XCTAssertEqual(remote.deletedIds, [id])
    }

    func testSyncFetchesAndCachesRemoteVacations() async throws {
        let remote = MockVacationsRemote()
        remote.remoteVacations = [
            VacationPeriod(id: "v1", startOn: "2026-05-01", endOn: "2026-05-05")
        ]
        let storage = InMemoryKeyValueStorage()
        let store = VacationsStore(userId: "user_1", remote: remote, storage: storage)

        await store.sync()

        XCTAssertEqual(store.vacations.count, 1)
        XCTAssertEqual(store.vacations.first?.id, "v1")

        // Relaunch store with same storage
        let store2 = VacationsStore(userId: "user_1", remote: remote, storage: storage)
        XCTAssertEqual(store2.vacations.count, 1)
        XCTAssertEqual(store2.vacations.first?.id, "v1")
    }
}
