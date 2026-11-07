import XCTest

actor FakeRoutineRemote: RoutineRemote {
    var stored: RemoteRoutine?
    var failPush = false
    var failFetch = false
    var failDelete = false
    var pushCallCount = 0
    var deleteCallCount = 0
    var fetchCallCount = 0

    func setStored(_ routine: RemoteRoutine?) {
        self.stored = routine
    }

    func setFailing(push: Bool? = nil, fetch: Bool? = nil, delete: Bool? = nil) {
        if let push { failPush = push }
        if let fetch { failFetch = fetch }
        if let delete { failDelete = delete }
    }

    func fetch(userId: String) async throws -> RemoteRoutine? {
        fetchCallCount += 1
        if failFetch { throw DataLayerError.network }
        return stored
    }

    func push(userId: String, data: RutinaData) async throws -> Date? {
        pushCallCount += 1
        if failPush { throw DataLayerError.network }
        let now = Date()
        self.stored = RemoteRoutine(data: data, updatedAt: now)
        return now
    }

    func delete(userId: String) async throws {
        deleteCallCount += 1
        if failDelete { throw DataLayerError.network }
        self.stored = nil
    }
}

final class RoutineSyncTests: XCTestCase {
    private func makeRoutine(goal: String = "Cardio") -> RutinaData {
        let ej = Ejercicio(detalle: "SkiErg", segundos: 30)
        let b = Bloque(id: "b1", tipo: .amrap, nombre: "Bloque 1", duracionMinutos: 12, ejercicios: [ej])
        let d = DiaEntrenamiento(id: "d1", nombre: "Día 1", bloques: [b])
        return RutinaData(usuario: "User", edad: 30, objetivo: goal, diasEntrenamiento: [d])
    }

    func testParseAndValidateRoutineCache() {
        // Cache nula o vacía
        XCTAssertEqual(RoutineSyncLogic.parseAndValidateRoutineCache(nil), .initial)
        XCTAssertEqual(RoutineSyncLogic.parseAndValidateRoutineCache(""), .initial)
        XCTAssertEqual(RoutineSyncLogic.parseAndValidateRoutineCache("invalid json"), .initial)

        // Cache con rutina válida
        let valid = makeRoutine()
        let cache = RoutineCacheState(customRoutine: valid, updatedAt: "2026-03-04T12:00:00.000Z", pendingAction: .save)
        let raw = try! JSONEncoder().encode(cache)
        let parsed = RoutineSyncLogic.parseAndValidateRoutineCache(String(data: raw, encoding: .utf8))
        XCTAssertNotNil(parsed.customRoutine)
        XCTAssertEqual(parsed.customRoutine?.objetivo, "Cardio")
        XCTAssertEqual(parsed.pendingAction, .save)
    }

    func testResolveRoutineConflict() {
        let r1 = makeRoutine(goal: "Local")
        let r2 = makeRoutine(goal: "Remote")

        // 1. Si hay pendingAction local, local gana siempre
        let localPending = RoutineCacheState(customRoutine: r1, updatedAt: "2026-03-04T10:00:00.000Z", pendingAction: .save)
        let remoteNewer = RemoteRoutine(data: r2, updatedAt: Date(timeIntervalSince1970: 2000000000))
        let res1 = RoutineSyncLogic.resolveRoutineConflict(local: localPending, remote: remoteNewer)
        XCTAssertEqual(res1.customRoutine?.objetivo, "Local")

        // 2. Si remoto es nil y no hay pendingAction, se limpia
        let localClean = RoutineCacheState(customRoutine: r1, updatedAt: "2026-03-04T10:00:00.000Z", pendingAction: nil)
        let res2 = RoutineSyncLogic.resolveRoutineConflict(local: localClean, remote: nil)
        XCTAssertNil(res2.customRoutine)

        // 3. Si remoto es más nuevo y no hay pendingAction, remoto gana
        let remoteObj = RemoteRoutine(data: r2, updatedAt: SupabaseDate.parse("2026-03-04T15:00:00.000Z"))
        let res3 = RoutineSyncLogic.resolveRoutineConflict(local: localClean, remote: remoteObj)
        XCTAssertEqual(res3.customRoutine?.objetivo, "Remote")

        // 4. Si local es más nuevo, local gana
        let localNewer = RoutineCacheState(customRoutine: r1, updatedAt: "2026-03-04T18:00:00.000Z", pendingAction: nil)
        let res4 = RoutineSyncLogic.resolveRoutineConflict(local: localNewer, remote: remoteObj)
        XCTAssertEqual(res4.customRoutine?.objetivo, "Local")
    }

    @MainActor
    func testRoutineStoreSaveAndReset() async throws {
        let storage = InMemoryKeyValueStorage()
        let remote = FakeRoutineRemote()
        let store = RoutineStore(userId: "u1", displayName: "Tester", remote: remote, storage: storage)

        XCTAssertFalse(store.isCustom)
        XCTAssertEqual(store.syncStatus, .synced)

        // Guardar rutina personalizada
        let custom = makeRoutine(goal: "Personalizada")
        try await store.saveRoutine(custom)

        XCTAssertTrue(store.isCustom)
        XCTAssertEqual(store.rutina.objetivo, "Personalizada")
        XCTAssertEqual(store.syncStatus, .synced)

        let pushed = await remote.stored
        XCTAssertNotNil(pushed)
        XCTAssertEqual(pushed?.data.objetivo, "Personalizada")

        // Restaurar rutina original
        try await store.resetRoutine()
        XCTAssertFalse(store.isCustom)
        XCTAssertEqual(store.syncStatus, .synced)

        let deleted = await remote.stored
        XCTAssertNil(deleted)
    }

    @MainActor
    func testRoutineStoreOfflineSaveKeepsPending() async throws {
        let storage = InMemoryKeyValueStorage()
        let remote = FakeRoutineRemote()
        await remote.setFailing(push: true)

        let store = RoutineStore(userId: "u1", displayName: "Tester", remote: remote, storage: storage)

        let custom = makeRoutine(goal: "Offline")
        try await store.saveRoutine(custom)

        // Se guarda en local pero queda pendiente
        XCTAssertTrue(store.isCustom)
        XCTAssertEqual(store.rutina.objetivo, "Offline")
        XCTAssertEqual(store.syncStatus, .pending)

        // Cuando la red vuelve y se llama a sync(), sube correctamente
        await remote.setFailing(push: false)
        await store.sync()

        XCTAssertEqual(store.syncStatus, .synced)
        let pushed = await remote.stored
        XCTAssertEqual(pushed?.data.objetivo, "Offline")
    }
}
