import XCTest
import SwiftData

@MainActor
final class SwiftDataCacheTests: XCTestCase {
    /// El contenedor debe seguir vivo mientras se usa su contexto (si se libera, SwiftData se cierra de golpe).
    private var container: ModelContainer?

    private func makeStore() throws -> (SwiftDataActivityCacheStore, ModelContainer) {
        let container = try SwiftDataActivityCacheStore.makeContainer(inMemory: true)
        self.container = container
        return (SwiftDataActivityCacheStore(context: container.mainContext), container)
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    func testEmptyLoad() throws {
        let (store, _) = try makeStore()
        XCTAssertEqual(store.load(userId: "u1"), ActivityCache())
    }

    func testRoundTripPreservesAllFieldsAndQueueOrder() throws {
        let (store, _) = try makeStore()
        var full = makeActivity("b", day: "2026-03-05", type: .workoutDay, duration: 1234, xp: 77, calories: 321.5)
        full.startedAt = Date(timeIntervalSince1970: 1_772_619_630)
        full.dayId = "dia_2"
        full.blocksCompleted = 4
        full.roundsTotal = 6
        full.distanceKm = 5.25
        full.runLocation = .cinta
        full.feeling = 3
        full.createdAt = Date(timeIntervalSince1970: 1_772_620_000)
        let other = makeActivity("a", day: "2026-03-01")
        let third = makeActivity("c", day: "2026-03-02")

        let cache = ActivityCache(activities: ActivitySync.sort([full, other, third]),
                                  pending: ["c", "b"], deleted: ["z2", "z1"])
        store.save(cache, userId: "u1")
        let loaded = store.load(userId: "u1")

        XCTAssertEqual(loaded.activities, cache.activities)
        XCTAssertEqual(loaded.pending, ["c", "b"], "el orden de la cola se conserva")
        XCTAssertEqual(loaded.deleted, ["z2", "z1"])
        XCTAssertEqual(loaded.activities.first { $0.id == "b" }, full)
    }

    func testSaveUpdatesInPlaceAndRemovesStaleRows() throws {
        let (store, container) = try makeStore()
        store.save(ActivityCache(activities: [makeActivity("a"), makeActivity("b", day: "2026-03-05")], pending: ["a"], deleted: ["x"]), userId: "u1")

        var edited = makeActivity("a")
        edited.durationSeconds = 4242
        store.save(ActivityCache(activities: [edited], pending: [], deleted: []), userId: "u1")

        let loaded = store.load(userId: "u1")
        XCTAssertEqual(loaded.activities.map(\.id), ["a"])
        XCTAssertEqual(loaded.activities.first?.durationSeconds, 4242)
        XCTAssertTrue(loaded.pending.isEmpty)
        XCTAssertTrue(loaded.deleted.isEmpty)
        let rows = try container.mainContext.fetch(FetchDescriptor<CachedActivity>())
        XCTAssertEqual(rows.count, 1, "sin duplicados por id")
    }

    func testUsersAreIsolated() throws {
        let (store, _) = try makeStore()
        store.save(ActivityCache(activities: [makeActivity("a")], pending: ["a"], deleted: []), userId: "u1")
        store.save(ActivityCache(activities: [makeActivity("b")], pending: [], deleted: ["q"]), userId: "u2")
        XCTAssertEqual(store.load(userId: "u1").activities.map(\.id), ["a"])
        XCTAssertEqual(store.load(userId: "u1").deleted, [])
        XCTAssertEqual(store.load(userId: "u2").activities.map(\.id), ["b"])
        XCTAssertEqual(store.load(userId: "u2").pending, [])
    }

    func testPendingIdsWithoutActivityAreDiscarded() throws {
        // Equivale a `known.has(id)` de loadActivityCache.
        let (store, _) = try makeStore()
        store.save(ActivityCache(activities: [makeActivity("a")], pending: ["ghost", "a"], deleted: []), userId: "u1")
        XCTAssertEqual(store.load(userId: "u1").pending, ["a"])
    }

    func testActivityStoreRunsOnTopOfSwiftData() async throws {
        let (swiftData, container) = try makeStore()
        let remote = FakeActivitiesRemote()
        let first = ActivityStore(userId: "u1", remote: remote, store: swiftData, isOnline: { false })
        let a = try first.addActivity(makeDraft())

        // "Reinicio": nuevo ModelContext sobre el mismo almacén.
        let second = ActivityStore(userId: "u1", remote: remote,
                                   store: SwiftDataActivityCacheStore(context: ModelContext(container)),
                                   isOnline: { true })
        XCTAssertEqual(second.activities.map(\.id), [a.id])
        XCTAssertEqual(second.pendingCount, 1)
        await second.sync()
        XCTAssertEqual(second.syncStatus, .synced)
        let server = await remote.server
        XCTAssertNotNil(server[a.id])
    }
}
