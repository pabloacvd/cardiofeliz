import XCTest

@MainActor
final class ActivityStoreTests: XCTestCase {
    private let userId = "u1"

    private func makeStore(
        remote: FakeActivitiesRemote,
        cache: InMemoryActivityCacheStore? = nil,
        online: Flag? = nil,
        derivation: ActivityDerivation = .none,
        retryInterval: Duration = .seconds(3600)
    ) -> ActivityStore {
        let cache = cache ?? InMemoryActivityCacheStore()
        let online = online ?? Flag(true)
        return ActivityStore(userId: userId, remote: remote, store: cache, derivation: derivation,
                      isOnline: { online.value }, retryInterval: retryInterval)
    }

    // MARK: Éxito

    func testAddActivityIsSavedLocallyImmediatelyAndMarkedPending() async throws {
        let remote = FakeActivitiesRemote()
        let online = Flag(false)                    // sin red: no sube, pero guarda
        let store = makeStore(remote: remote, online: online)

        let a = try store.addActivity(makeDraft())

        XCTAssertEqual(store.activities.map(\.id), [a.id])
        XCTAssertEqual(a.userId, userId)
        XCTAssertNotNil(a.createdAt)
        XCTAssertEqual(store.syncStatus, .pending)
        XCTAssertEqual(store.pendingCount, 1)
        let pushed = await remote.pushLog
        XCTAssertTrue(pushed.isEmpty)
    }

    func testSyncSuccessUploadsAndClearsQueue() async throws {
        let remote = FakeActivitiesRemote()
        let cache = InMemoryActivityCacheStore()
        let online = Flag(false)
        let store = makeStore(remote: remote, cache: cache, online: online)
        let a = try store.addActivity(makeDraft())

        online.value = true
        await store.sync()

        let server = await remote.server
        XCTAssertEqual(Array(server.keys), [a.id])
        let pushedUsers = await remote.pushedUserIds
        XCTAssertEqual(pushedUsers, [userId])
        XCTAssertEqual(store.syncStatus, .synced)
        XCTAssertEqual(store.pendingCount, 0)
        XCTAssertNotNil(store.lastSyncedAt)
        let persisted = cache.load(userId: userId)
        XCTAssertTrue(persisted.pending.isEmpty)
        XCTAssertEqual(persisted.activities.map(\.id), [a.id])
    }

    func testAddActivityTriggersBackgroundSyncWhenOnline() async throws {
        let remote = FakeActivitiesRemote()
        let store = makeStore(remote: remote)
        let a = try store.addActivity(makeDraft())
        let done = await eventually { store.syncStatus == .synced && store.pendingCount == 0 }
        XCTAssertTrue(done)
        let server = await remote.server
        XCTAssertNotNil(server[a.id])
    }

    func testSyncHydratesFromServerActivitiesCreatedElsewhere() async {
        let remote = FakeActivitiesRemote()
        await remote.seed([makeActivity("pwa-1", day: "2026-03-01"), makeActivity("pwa-2", day: "2026-03-02")])
        let store = makeStore(remote: remote)
        await store.sync()
        XCTAssertEqual(store.activities.map(\.id), ["pwa-2", "pwa-1"])
        XCTAssertEqual(store.syncStatus, .synced)
    }

    func testOrderOfOperationsDeletesThenPushesThenFetches() async throws {
        let remote = FakeActivitiesRemote()
        await remote.seed([makeActivity("old")])
        let online = Flag(false)
        let store = makeStore(remote: remote, online: online)
        await store.sync()                                      // sin red real: el fake responde; hidrata "old"
        online.value = false
        store.removeActivity(id: "old")
        let added = try store.addActivity(makeDraft())
        online.value = true
        await store.sync()
        let server = await remote.server
        XCTAssertNil(server["old"])
        XCTAssertNotNil(server[added.id])
        XCTAssertEqual(store.activities.map(\.id), [added.id])
    }

    // MARK: Fallo de red con reintento

    func testNetworkFailureKeepsItemPendingThenRetrySucceeds() async throws {
        let remote = FakeActivitiesRemote()
        await remote.setOffline(true)
        let store = makeStore(remote: remote)
        let a = try store.addActivity(makeDraft())
        await store.sync()

        XCTAssertEqual(store.syncStatus, .pending, "con pendientes se muestra pending aunque falle")
        XCTAssertEqual(store.pendingCount, 1)
        XCTAssertEqual(store.activities.map(\.id), [a.id], "la actividad local no se pierde")

        await remote.setOffline(false)
        await store.sync()

        XCTAssertEqual(store.syncStatus, .synced)
        let server = await remote.server
        XCTAssertNotNil(server[a.id])
    }

    func testFailureWithoutPendingShowsOffline() async {
        let remote = FakeActivitiesRemote()
        await remote.setFailing(fetch: true)
        let store = makeStore(remote: remote)
        await store.sync()
        XCTAssertEqual(store.syncStatus, .offline)
        await remote.setFailing(fetch: false)
        await store.sync()
        XCTAssertEqual(store.syncStatus, .synced)
    }

    func testKnownOfflineMarksErrorWithoutCallingTheServer() async {
        let remote = FakeActivitiesRemote()
        let store = makeStore(remote: remote, online: Flag(false))
        store.trySync()
        XCTAssertEqual(store.syncStatus, .offline)
        let fetches = await remote.fetchCount
        XCTAssertEqual(fetches, 0)
    }

    func testFailedDeleteStaysQueuedAndIsRetried() async throws {
        let remote = FakeActivitiesRemote()
        await remote.seed([makeActivity("a")])
        let store = makeStore(remote: remote, online: Flag(false))
        store.removeActivity(id: "a")
        XCTAssertEqual(store.pendingCount, 1)

        await remote.setFailing(delete: true)
        await store.sync()
        XCTAssertEqual(store.pendingCount, 1)
        var server = await remote.server
        XCTAssertNotNil(server["a"])

        await remote.setFailing(delete: false)
        await store.sync()
        XCTAssertEqual(store.pendingCount, 0)
        server = await remote.server
        XCTAssertNil(server["a"])
        XCTAssertTrue(store.activities.isEmpty)
    }

    func testPendingItemsUploadInOrderEvenIfOneFailsFirst() async throws {
        let remote = FakeActivitiesRemote()
        let online = Flag(false)
        let store = makeStore(remote: remote, online: online)
        let first = try store.addActivity(makeDraft(day: "2026-03-01"))
        let second = try store.addActivity(makeDraft(day: "2026-03-02"))
        online.value = true
        await store.sync()
        let log = await remote.pushLog
        XCTAssertEqual(log, [first.id, second.id])
    }

    func testPeriodicRetryWhilePending() async throws {
        let remote = FakeActivitiesRemote()
        await remote.setOffline(true)
        let store = makeStore(remote: remote, retryInterval: .milliseconds(30))
        let a = try store.addActivity(makeDraft())
        await store.sync()
        XCTAssertEqual(store.pendingCount, 1)

        await remote.setOffline(false)
        let done = await eventually { store.pendingCount == 0 }
        XCTAssertTrue(done, "el reintento periódico debe subir lo pendiente sin intervención")
        let server = await remote.server
        XCTAssertNotNil(server[a.id])
    }

    // MARK: Idempotencia

    func testResendingAfterLostResponseNeverDuplicates() async throws {
        let remote = FakeActivitiesRemote()
        // El servidor guarda la fila pero la respuesta "se pierde": la app cree que falló y reintenta.
        await remote.setFailing(pushAfterApply: true)
        let store = makeStore(remote: remote)
        let a = try store.addActivity(makeDraft())
        await store.sync()
        XCTAssertEqual(store.pendingCount, 1)
        var server = await remote.server
        XCTAssertEqual(server.count, 1)

        await remote.setFailing(pushAfterApply: false)
        await store.sync()
        await store.sync()
        server = await remote.server
        XCTAssertEqual(server.count, 1, "mismo id, misma fila: no se duplica")
        XCTAssertEqual(server[a.id]?.id, a.id)
        let log = await remote.pushLog
        XCTAssertGreaterThanOrEqual(log.count, 2)
        XCTAssertEqual(Set(log), [a.id])
        XCTAssertEqual(store.activities.count, 1)
        XCTAssertEqual(store.syncStatus, .synced)
    }

    func testEditingPendingActivityKeepsSingleQueueEntryAndUploadsLatestVersion() async throws {
        let remote = FakeActivitiesRemote()
        let online = Flag(false)
        let store = makeStore(remote: remote, online: online)
        let a = try store.addActivity(makeDraft(duration: 100))
        _ = try store.updateActivity(id: a.id) { $0.durationSeconds = 200 }
        _ = try store.updateActivity(id: a.id) { $0.durationSeconds = 300 }
        XCTAssertEqual(store.pendingCount, 1)

        online.value = true
        await store.sync()
        let server = await remote.server
        XCTAssertEqual(server[a.id]?.durationSeconds, 300)
        let log = await remote.pushLog
        XCTAssertEqual(log, [a.id])
    }

    func testEditWhileUploadingStaysPendingWithNewVersion() async throws {
        let remote = FakeActivitiesRemote()
        let online = Flag(false)
        let store = makeStore(remote: remote, online: online)
        let a = try store.addActivity(makeDraft(duration: 100))

        // Mientras sube la versión 1, el usuario edita (se simula dentro del push).
        let editedStore = store
        await remote.setOnPush { _ in
            await MainActor.run {
                _ = try? editedStore.updateActivity(id: a.id) { $0.durationSeconds = 999 }
            }
        }
        online.value = true
        await store.sync()
        await remote.setOnPush(nil)

        // La versión 2 sigue pendiente; la siguiente pasada la sube.
        XCTAssertEqual(store.activities.first?.durationSeconds, 999)
        await store.sync()
        let server = await remote.server
        XCTAssertEqual(server[a.id]?.durationSeconds, 999)
        XCTAssertEqual(store.pendingCount, 0)
    }

    func testUpdatingUnknownIdReturnsNil() throws {
        let store = makeStore(remote: FakeActivitiesRemote(), online: Flag(false))
        XCTAssertNil(try store.updateActivity(id: "nope") { $0.durationSeconds = 1 })
    }

    func testConcurrentSyncCallsAreCoalesced() async throws {
        let remote = FakeActivitiesRemote()
        let store = makeStore(remote: remote, online: Flag(false))
        _ = try store.addActivity(makeDraft())
        async let s1: Void = store.sync()
        async let s2: Void = store.sync()
        async let s3: Void = store.sync()
        _ = await (s1, s2, s3)
        let log = await remote.pushLog
        XCTAssertEqual(log.count, 1, "una sola subida aunque se pida sincronizar varias veces a la vez")
        XCTAssertEqual(store.syncStatus, .synced)
    }

    // MARK: Borrado y merge

    func testRemovedActivityDoesNotReappearWhileDeletionPending() async throws {
        let remote = FakeActivitiesRemote()
        await remote.seed([makeActivity("a")])
        let store = makeStore(remote: remote)
        await store.sync()
        XCTAssertEqual(store.activities.map(\.id), ["a"])

        await remote.setFailing(delete: true)
        store.removeActivity(id: "a")
        await store.sync()                            // el borrado falla: no se llega a hidratar
        XCTAssertTrue(store.activities.isEmpty)

        await remote.setFailing(delete: false)
        await store.sync()
        XCTAssertTrue(store.activities.isEmpty)
        XCTAssertEqual(store.syncStatus, .synced)
    }

    func testRemovingPendingUnsyncedActivityDropsItFromQueueButStillSendsDelete() async throws {
        let remote = FakeActivitiesRemote()
        let online = Flag(false)
        let store = makeStore(remote: remote, online: online)
        let a = try store.addActivity(makeDraft())
        store.removeActivity(id: a.id)
        XCTAssertEqual(store.pendingCount, 1)         // solo el borrado
        online.value = true
        await store.sync()
        let pushLog = await remote.pushLog
        let deleteLog = await remote.deleteLog
        XCTAssertTrue(pushLog.isEmpty)
        XCTAssertEqual(deleteLog, [a.id])             // por si una subida previa se aplicó sin confirmarse
    }

    // MARK: Persistencia entre sesiones de la app

    func testQueueSurvivesRelaunch() async throws {
        let remote = FakeActivitiesRemote()
        let cache = InMemoryActivityCacheStore()
        let first = makeStore(remote: remote, cache: cache, online: Flag(false))
        let a = try first.addActivity(makeDraft())

        let relaunched = makeStore(remote: remote, cache: cache)
        XCTAssertEqual(relaunched.activities.map(\.id), [a.id])
        XCTAssertEqual(relaunched.pendingCount, 1)
        XCTAssertEqual(relaunched.syncStatus, .pending)
        await relaunched.sync()
        let server = await remote.server
        XCTAssertNotNil(server[a.id])
    }

    func testCachesAreIsolatedPerUser() async throws {
        let cache = InMemoryActivityCacheStore()
        let alice = ActivityStore(userId: "alice", remote: FakeActivitiesRemote(), store: cache, isOnline: { false })
        _ = try alice.addActivity(makeDraft())
        let bob = ActivityStore(userId: "bob", remote: FakeActivitiesRemote(), store: cache, isOnline: { false })
        XCTAssertTrue(bob.activities.isEmpty)
    }

    // MARK: Validación y valores derivados

    func testInvalidDraftIsRejectedAndNothingIsQueued() {
        let store = makeStore(remote: FakeActivitiesRemote(), online: Flag(false))
        XCTAssertThrowsError(try store.addActivity(makeDraft(duration: -5))) {
            XCTAssertEqual($0 as? DataLayerError, .invalidInput)
        }
        XCTAssertTrue(store.activities.isEmpty)
        XCTAssertEqual(store.pendingCount, 0)
    }

    func testDerivationFillsXpAndCaloriesAndFillMissingCalories() async throws {
        let derivation = ActivityDerivation(
            derive: { activity, others, options in
                var a = activity
                a.xpEarned = 100 + others.count
                a.caloriesKcal = options.weightKg.map { $0 * 2 }
                return a
            },
            estimateCalories: { activity, weight in Double(activity.durationSeconds) * weight / 1000 }
        )
        let store = makeStore(remote: FakeActivitiesRemote(), online: Flag(false), derivation: derivation)

        let noWeight = try store.addActivity(makeDraft(duration: 1000))
        XCTAssertEqual(noWeight.xpEarned, 100)
        XCTAssertNil(noWeight.caloriesKcal)
        let withWeight = try store.addActivity(makeDraft(day: "2026-03-05"), options: AddActivityOptions(weightKg: 60))
        XCTAssertEqual(withWeight.xpEarned, 101)
        XCTAssertEqual(withWeight.caloriesKcal, 120)

        store.fillMissingCalories(weightKg: 70)
        let filled = store.activities.first { $0.id == noWeight.id }
        XCTAssertEqual(filled?.caloriesKcal, 70)
        let untouched = store.activities.first { $0.id == withWeight.id }
        XCTAssertEqual(untouched?.caloriesKcal, 120)
    }

    func testFillMissingCaloriesWithoutAnythingToFillDoesNothing() async throws {
        let cache = InMemoryActivityCacheStore()
        let store = makeStore(remote: FakeActivitiesRemote(), cache: cache, online: Flag(false))
        let before = cache.saveCount
        store.fillMissingCalories(weightKg: 70)        // derivación .none: no estima nada
        XCTAssertEqual(cache.saveCount, before)
    }
}

@MainActor
final class SessionManagerTests: XCTestCase {
    final class FakeAuth: AuthBackend, @unchecked Sendable {
        var signInResult: Result<AuthUser, Error> = .success(AuthUser(id: "u1", email: "juli@app.local"))
        var signOutError: Error?
        private(set) var signInEmails: [String] = []
        private(set) var signOutCalls = 0
        var continuation: AsyncStream<AuthEvent>.Continuation?

        func signIn(email: String, password: String) async throws -> AuthUser {
            signInEmails.append(email)
            return try signInResult.get()
        }
        func signOut() async throws {
            signOutCalls += 1
            if let signOutError { throw signOutError }
        }
        func authEvents() -> AsyncStream<AuthEvent> {
            AsyncStream { self.continuation = $0 }
        }
    }

    func testUnconfiguredWhenThereIsNoBackend() async {
        let s = SessionManager(backend: nil)
        XCTAssertEqual(s.state, .unconfigured)
        XCTAssertNil(s.currentUserId)
        do {
            try await s.signIn(username: "juli", password: "x")
            XCTFail("Debía lanzar")
        } catch {
            XCTAssertEqual(error as? DataLayerError, .notConfigured)
        }
        s.start()
        XCTAssertEqual(s.state, .unconfigured)
    }

    func testStartsLoadingThenInitialSessionDecides() async {
        let auth = FakeAuth()
        let s = SessionManager(backend: auth)
        XCTAssertEqual(s.state, .loading)
        s.start()
        auth.continuation?.yield(.initialSession(AuthUser(id: "u1", email: "juli@app.local")))
        let ok = await eventually { s.state != .loading }
        XCTAssertTrue(ok)
        XCTAssertEqual(s.state, .signedIn(userId: "u1", username: "juli"))
        XCTAssertEqual(s.currentUserId, "u1")
    }

    func testInitialSessionWithoutUserGoesToSignedOut() {
        let s = SessionManager(backend: FakeAuth())
        s.handle(.initialSession(nil))
        XCTAssertEqual(s.state, .signedOut)
    }

    func testTransientEventsAreIgnored() {
        let s = SessionManager(backend: FakeAuth())
        s.handle(.initialSession(AuthUser(id: "u1", email: "a@app.local")))
        s.handle(.transient)
        XCTAssertEqual(s.state, .signedIn(userId: "u1", username: "a"))
        s.handle(.signedOut)
        XCTAssertEqual(s.state, .signedOut)
        s.handle(.transient)
        XCTAssertEqual(s.state, .signedOut)
    }

    func testSignInNormalizesUsernameAndNeverSendsInvalidInputToTheServer() async throws {
        let auth = FakeAuth()
        let s = SessionManager(backend: auth)
        try await s.signIn(username: "  Juli ", password: "secreto")
        XCTAssertEqual(auth.signInEmails, ["juli@app.local"])
        XCTAssertEqual(s.state, .signedIn(userId: "u1", username: "juli"))

        for (u, p) in [("", "x"), ("a b", "x"), ("juli", ""), ("juli", String(repeating: "x", count: 257))] {
            do {
                try await s.signIn(username: u, password: p)
                XCTFail("Debía lanzar para \(u)")
            } catch {
                XCTAssertEqual(error as? DataLayerError, .invalidCredentials)
            }
        }
        XCTAssertEqual(auth.signInEmails.count, 1, "las entradas inválidas no llegan al backend")
    }

    func testSignInFailureLeavesStateAndSurfacesGenericError() async {
        let auth = FakeAuth()
        auth.signInResult = .failure(DataLayerError.invalidCredentials)
        let s = SessionManager(backend: auth)
        s.handle(.initialSession(nil))
        do {
            try await s.signIn(username: "juli", password: "mala")
            XCTFail("Debía lanzar")
        } catch {
            XCTAssertEqual(error as? DataLayerError, .invalidCredentials)
            XCTAssertEqual((error as? DataLayerError)?.userMessage, "Usuario o contraseña incorrectos.")
        }
        XCTAssertEqual(s.state, .signedOut)
        XCTAssertFalse(s.isSigningIn)
    }

    func testUnexpectedErrorsAreWrappedAsUnknown() async {
        let auth = FakeAuth()
        auth.signInResult = .failure(NSError(domain: "x", code: 1, userInfo: [NSLocalizedDescriptionKey: "secret detail"]))
        let s = SessionManager(backend: auth)
        do {
            try await s.signIn(username: "juli", password: "x")
            XCTFail("Debía lanzar")
        } catch {
            XCTAssertEqual(error as? DataLayerError, .unknown)
            XCTAssertFalse((error as? DataLayerError)!.userMessage.contains("secret"))
        }
    }

    func testSignOutEndsSessionEvenIfNetworkFails() async {
        let auth = FakeAuth()
        auth.signOutError = DataLayerError.network
        let s = SessionManager(backend: auth)
        s.handle(.initialSession(AuthUser(id: "u1", email: "a@app.local")))
        await s.signOut()
        XCTAssertEqual(auth.signOutCalls, 1)
        XCTAssertEqual(s.state, .signedOut)
        XCTAssertNil(s.currentUserId)
    }

    func testSignedInEventForSameUserDoesNotRepublish() {
        let s = SessionManager(backend: FakeAuth())
        var changes = 0
        let c = s.$state.dropFirst().sink { _ in changes += 1 }
        s.handle(.signedIn(AuthUser(id: "u1", email: "a@app.local")))
        s.handle(.sessionUpdated(AuthUser(id: "u1", email: "a@app.local")))
        XCTAssertEqual(changes, 1)
        c.cancel()
    }
}
