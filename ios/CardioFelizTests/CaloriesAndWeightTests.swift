import XCTest

final class CaloriesAndWeightTests: XCTestCase {

    // MARK: - CaloriesEstimator Tests (port of PWA xp-levels-calories.test.ts)

    func testSanitizeWeight() {
        XCTAssertNil(CaloriesEstimator.sanitizeWeight(nil))
        XCTAssertNil(CaloriesEstimator.sanitizeWeight(5))
        XCTAssertNil(CaloriesEstimator.sanitizeWeight(500))
        XCTAssertNil(CaloriesEstimator.sanitizeWeight(Double.nan))
        XCTAssertNil(CaloriesEstimator.sanitizeWeight(Double.infinity))
        XCTAssertEqual(CaloriesEstimator.sanitizeWeight(60), 60)
        XCTAssertEqual(CaloriesEstimator.sanitizeWeight(20), 20)
        XCTAssertEqual(CaloriesEstimator.sanitizeWeight(300), 300)
    }

    func testEstimateCaloriesWorkoutDay() {
        // 1 hour at 60 kg -> MET 8 * 60 * 1 = 480 kcal
        XCTAssertEqual(CaloriesEstimator.estimateCalories(type: .workoutDay, durationSeconds: 3600, weightKg: 60), 480)
        // 30 min at 70 kg -> MET 8 * 70 * 0.5 = 280 kcal
        XCTAssertEqual(CaloriesEstimator.estimateCalories(type: .workoutDay, durationSeconds: 1800, weightKg: 70), 280)
    }

    func testEstimateCaloriesActiveRest() {
        // 1 hour at 60 kg -> MET 3 * 60 * 1 = 180 kcal
        XCTAssertEqual(CaloriesEstimator.estimateCalories(type: .activeRest, durationSeconds: 3600, weightKg: 60), 180)
    }

    func testEstimateCaloriesRunDefaultMet() {
        // Run without distance -> default MET 8.3
        XCTAssertEqual(CaloriesEstimator.metForRun(distanceKm: nil, minutes: 30), 8.3)
        // 30 min at 60 kg -> 8.3 * 60 * 0.5 = 249 kcal
        XCTAssertEqual(CaloriesEstimator.estimateCalories(type: .run, durationSeconds: 1800, distanceKm: nil, weightKg: 60), 249)
    }

    func testEstimateCaloriesRunInterpolation() {
        // 4 km in 30 min = 8 km/h -> MET 8.3
        XCTAssertEqual(CaloriesEstimator.metForRun(distanceKm: 4, minutes: 30), 8.3, accuracy: 0.00001)
        // 5 km in 30 min = 10 km/h -> between 9.8 and 11.0
        let met = CaloriesEstimator.metForRun(distanceKm: 5, minutes: 30)
        XCTAssertGreaterThan(met, 9.8)
        XCTAssertLessThan(met, 11.0)
    }

    func testFasterRunBurnsMore() {
        XCTAssertGreaterThan(
            CaloriesEstimator.metForRun(distanceKm: 6, minutes: 30),
            CaloriesEstimator.metForRun(distanceKm: 4, minutes: 30)
        )
    }

    func testImplausibleRunSpeedsFallbackToDefault() {
        XCTAssertEqual(CaloriesEstimator.metForRun(distanceKm: 50, minutes: 10), 8.3) // 300 km/h
        XCTAssertEqual(CaloriesEstimator.metForRun(distanceKm: 0.1, minutes: 60), 8.3) // 0.1 km/h
        XCTAssertEqual(CaloriesEstimator.metForRun(distanceKm: -3, minutes: 30), 8.3)
        XCTAssertEqual(CaloriesEstimator.metForRun(distanceKm: 5, minutes: 0), 8.3)
    }

    func testInvalidDurationReturnsZeroCalories() {
        XCTAssertEqual(CaloriesEstimator.estimateCalories(type: .workoutDay, durationSeconds: -10, weightKg: 60), 0)
        XCTAssertEqual(CaloriesEstimator.estimateCalories(type: .workoutDay, durationSeconds: 0, weightKg: 60), 0)
    }

    func testWithoutValidWeightReturnsNil() {
        XCTAssertNil(CaloriesEstimator.estimateCalories(type: .run, durationSeconds: 1800, weightKg: nil))
        XCTAssertNil(CaloriesEstimator.estimateCalories(type: .run, durationSeconds: 1800, weightKg: 10))
    }

    // MARK: - ProfileWeightStore Tests

    @MainActor
    func testProfileWeightStoreLocalFirst() async {
        let storage = InMemoryKeyValueStorage()
        let store = ProfileWeightStore(userId: "u1", remote: nil, storage: storage)

        XCTAssertNil(store.weightKg)
        XCTAssertFalse(store.isLoaded)
        XCTAssertFalse(store.promptDismissed)
        XCTAssertFalse(store.isPending)

        // Invalid weight rejected
        XCTAssertFalse(store.setWeightKg(10))
        XCTAssertNil(store.weightKg)

        // Valid weight accepted
        XCTAssertTrue(store.setWeightKg(62.5))
        XCTAssertEqual(store.weightKg, 62.5)
        XCTAssertTrue(store.isPending)

        store.dismissPrompt()
        XCTAssertTrue(store.promptDismissed)

        // Recreate from same storage to check persistence
        let reloaded = ProfileWeightStore(userId: "u1", remote: nil, storage: storage)
        XCTAssertEqual(reloaded.weightKg, 62.5)
        XCTAssertTrue(reloaded.promptDismissed)
        XCTAssertTrue(reloaded.isLoaded)
        XCTAssertTrue(reloaded.isPending)
    }

    @MainActor
    func testProfileWeightStoreRemoteSync() async {
        final class MockProfileRemote: ProfileRemote, @unchecked Sendable {
            var remoteWeight: Double? = 70.0
            var pushedWeights: [(userId: String, weight: Double)] = []

            func fetchProfile(userId: String) async throws -> UserProfile? { nil }
            func fetchWeightKg(userId: String) async throws -> Double? { remoteWeight }
            func pushWeightKg(userId: String, weightKg: Double) async throws {
                pushedWeights.append((userId: userId, weight: weightKg))
                remoteWeight = weightKg
            }
        }

        let storage = InMemoryKeyValueStorage()
        let remote = MockProfileRemote()
        let store = ProfileWeightStore(userId: "u1", remote: remote, storage: storage)

        // 1. Initial sync fetches remote weight 70 kg
        await store.syncWeight()
        XCTAssertEqual(store.weightKg, 70.0)
        XCTAssertFalse(store.isPending)
        XCTAssertTrue(store.isLoaded)

        // 2. Setting weight marks pending and pushes to remote
        XCTAssertTrue(store.setWeightKg(68.5))
        XCTAssertEqual(store.weightKg, 68.5)
        try? await Task.sleep(for: .milliseconds(50))
        await store.syncWeight()
        XCTAssertFalse(store.isPending)
        XCTAssertEqual(remote.pushedWeights.count, 1)
        XCTAssertEqual(remote.pushedWeights.first?.weight, 68.5)
    }

    // MARK: - UserDefaultsStorage

    /// Cubre la ruta real con `UserDefaults` (la usa la app); antes recursaba sin fin.
    @MainActor
    func testUserDefaultsStorageRoundTripAndPersistence() throws {
        let suite = "cf.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let storage = UserDefaultsStorage(defaults)
        XCTAssertNil(storage.string(forKey: "k"))
        storage.set("v", forKey: "k")
        XCTAssertEqual(storage.string(forKey: "k"), "v")
        storage.set(nil, forKey: "k")
        XCTAssertNil(storage.string(forKey: "k"))

        let store = ProfileWeightStore(userId: "u1", remote: nil, storage: storage)
        XCTAssertTrue(store.setWeightKg(61))
        let reloaded = ProfileWeightStore(userId: "u1", remote: nil, storage: UserDefaultsStorage(defaults))
        XCTAssertEqual(reloaded.weightKg, 61)
        XCTAssertTrue(reloaded.isPending)
    }
}
