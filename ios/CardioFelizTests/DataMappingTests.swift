import XCTest

final class MapperTests: XCTestCase {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testActivityRowToRecord() throws {
        let row = try decode(ActivityRow.self, """
        {"id":"a1","user_id":"u1","type":"run","occurred_on":"2026-03-04","started_at":"2026-03-04T10:20:30.5+00:00",
         "duration_seconds":1800,"day_id":null,"blocks_completed":null,"rounds_total":null,"distance_km":"5.25",
         "run_location":"calle","feeling":4,"calories_kcal":310.5,"xp_earned":42,"created_at":"2026-03-04T11:00:00Z"}
        """)
        let a = Mappers.activity(row)
        XCTAssertEqual(a.id, "a1")
        XCTAssertEqual(a.userId, "u1")
        XCTAssertEqual(a.type, .run)
        XCTAssertEqual(a.occurredOn, "2026-03-04")
        XCTAssertNotNil(a.startedAt)
        XCTAssertEqual(a.distanceKm, 5.25)          // numeric llegó como cadena
        XCTAssertEqual(a.caloriesKcal, 310.5)
        XCTAssertEqual(a.runLocation, .calle)
        XCTAssertEqual(a.feeling, 4)
        XCTAssertEqual(a.xpEarned, 42)
        XCTAssertNotNil(a.createdAt)
    }

    func testActivityRowWithNullsAndBadTimestamp() throws {
        let row = try decode(ActivityRow.self, """
        {"id":"a1","user_id":"u1","type":"workout_day","occurred_on":"2026-03-04","started_at":null,
         "duration_seconds":0,"day_id":"dia_1","blocks_completed":3,"rounds_total":null,"distance_km":null,
         "run_location":null,"feeling":null,"calories_kcal":null,"xp_earned":0,"created_at":"no-es-fecha"}
        """)
        let a = Mappers.activity(row)
        XCTAssertNil(a.startedAt)
        XCTAssertNil(a.distanceKm)
        XCTAssertNil(a.caloriesKcal)
        XCTAssertNil(a.createdAt)
        XCTAssertEqual(a.dayId, "dia_1")
        XCTAssertEqual(a.blocksCompleted, 3)
    }

    func testActivityInsertEncodesExplicitNullsAndSnakeCase() throws {
        // Igual que toDbActivity: los opcionales vacíos viajan como null para poder BORRAR valores al editar.
        let a = ActivityRecord(id: "a1", userId: nil, type: .activeRest, occurredOn: "2026-03-04", startedAt: nil,
                               durationSeconds: 300, dayId: nil, blocksCompleted: nil, roundsTotal: nil, distanceKm: nil,
                               runLocation: nil, feeling: nil, caloriesKcal: nil, xpEarned: 5, createdAt: Date())
        let obj = try json(Mappers.insert(a, userId: "u-session"))
        XCTAssertEqual(obj["user_id"] as? String, "u-session")   // domain.userId ?? userId
        XCTAssertEqual(obj["type"] as? String, "active_rest")
        XCTAssertEqual(obj["occurred_on"] as? String, "2026-03-04")
        XCTAssertEqual(obj["duration_seconds"] as? Int, 300)
        XCTAssertEqual(obj["xp_earned"] as? Int, 5)
        for key in ["started_at", "day_id", "blocks_completed", "rounds_total", "distance_km", "run_location", "feeling", "calories_kcal"] {
            XCTAssertTrue(obj[key] is NSNull, "\(key) debe enviarse como null")
        }
        XCTAssertNil(obj["created_at"], "created_at lo asigna el servidor")
        XCTAssertEqual(Set(obj.keys).count, 14)
    }

    func testActivityInsertKeepsOwnUserIdAndFormatsStartedAt() throws {
        var a = makeActivity("a1")
        a.userId = "u-own"
        a.startedAt = Date(timeIntervalSince1970: 1_772_619_630)
        a.distanceKm = 5.25
        a.runLocation = .cinta
        let obj = try json(Mappers.insert(a, userId: "u-session"))
        XCTAssertEqual(obj["user_id"] as? String, "u-own")
        XCTAssertEqual((obj["started_at"] as? String)?.hasSuffix("Z"), true)
        XCTAssertEqual(obj["distance_km"] as? Double, 5.25)
        XCTAssertEqual(obj["run_location"] as? String, "cinta")
    }

    func testProfileRowAndWeightInsert() throws {
        let row = try decode(ProfileRow.self, """
        {"user_id":"u1","display_name":"Juli","weight_kg":"62.50","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00.5Z"}
        """)
        let p = Mappers.profile(row)
        XCTAssertEqual(p.userId, "u1")
        XCTAssertEqual(p.displayName, "Juli")
        XCTAssertEqual(p.weightKg, 62.5)
        XCTAssertNotNil(p.createdAt)
        XCTAssertNotNil(p.updatedAt)

        // pushWeightKg NO envía display_name: no pisa el nombre existente.
        let obj = try json(ProfileWeightInsert(userId: "u1", weightKg: 63))
        XCTAssertEqual(Set(obj.keys), ["user_id", "weight_kg"])
    }

    func testAchievementMapping() throws {
        let row = try decode(AchievementRow.self, #"{"user_id":"u1","achievement_id":"first_run","unlocked_at":"2026-03-04T10:20:30+00:00"}"#)
        let a = try XCTUnwrap(Mappers.achievement(row))
        XCTAssertEqual(a.achievementId, "first_run")

        let bad = try decode(AchievementRow.self, #"{"user_id":"u1","achievement_id":"x","unlocked_at":"???"}"#)
        XCTAssertNil(Mappers.achievement(bad))

        let obj = try json(Mappers.insert(a, userId: "u-session"))
        XCTAssertEqual(obj["user_id"] as? String, "u1")
        XCTAssertEqual(obj["achievement_id"] as? String, "first_run")
        XCTAssertEqual(obj["unlocked_at"] as? String, "2026-03-04T10:20:30.000Z")
    }

    func testVacationMappingKeepsNullEndOn() throws {
        let row = try decode(VacationRow.self, #"{"id":"v1","user_id":"u1","start_on":"2026-03-01","end_on":null,"created_at":"2026-03-01T08:00:00Z"}"#)
        let v = Mappers.vacation(row)
        XCTAssertEqual(v.startOn, "2026-03-01")
        XCTAssertNil(v.endOn)
        let obj = try json(Mappers.insert(v, userId: "u-session"))
        XCTAssertEqual(obj["id"] as? String, "v1")
        XCTAssertEqual(obj["user_id"] as? String, "u1")
        XCTAssertEqual(obj["start_on"] as? String, "2026-03-01")
        XCTAssertTrue(obj["end_on"] is NSNull, "end_on null cierra/reabre el período activo")
    }

    func testRoutineMappingAndInsert() throws {
        let rutina = try Fixtures.defaultRoutine()
        let remote = Mappers.routine(data: rutina, updatedAt: "2026-03-04T10:20:30.123456+00:00")
        XCTAssertEqual(remote.data, rutina)
        XCTAssertNotNil(remote.updatedAt)
        XCTAssertNil(Mappers.routine(data: rutina, updatedAt: "mal").updatedAt)

        let obj = try json(RoutineInsert(userId: "u1", data: rutina))
        XCTAssertEqual(Set(obj.keys), ["user_id", "data"])
        let data = try XCTUnwrap(obj["data"] as? [String: Any])
        XCTAssertNotNil(data["dias_entrenamiento"])
    }
}

final class ActivitySyncMergeTests: XCTestCase {
    private func ids(_ list: [ActivityRecord]) -> [String] { list.map(\.id) }

    func testSortNewestFirstWithDescendingIdTieBreak() {
        let sorted = ActivitySync.sort([
            makeActivity("a", day: "2026-03-01"),
            makeActivity("b", day: "2026-03-03"),
            makeActivity("c", day: "2026-03-03"),
            makeActivity("d", day: "2026-03-02"),
        ])
        XCTAssertEqual(ids(sorted), ["c", "b", "d", "a"])
    }

    func testRemoteIsSourceOfTruthForSyncedItems() {
        let local = [makeActivity("a", duration: 100)]
        let remote = [makeActivity("a", duration: 999)]
        let merged = ActivitySync.merge(local: local, remote: remote, pendingIds: [])
        XCTAssertEqual(merged.first?.durationSeconds, 999)
    }

    func testPendingLocalWinsOverRemoteWithSameId() {
        let local = [makeActivity("a", duration: 100)]
        let remote = [makeActivity("a", duration: 999)]
        let merged = ActivitySync.merge(local: local, remote: remote, pendingIds: ["a"])
        XCTAssertEqual(merged.first?.durationSeconds, 100)
    }

    func testPendingLocalNotYetOnServerIsKept() {
        let local = [makeActivity("new", day: "2026-03-05")]
        let remote = [makeActivity("old", day: "2026-03-01")]
        let merged = ActivitySync.merge(local: local, remote: remote, pendingIds: ["new"])
        XCTAssertEqual(ids(merged), ["new", "old"])
    }

    func testSyncedLocalMissingOnServerIsDropped() {
        // Borrada desde otro dispositivo: ya no está en el servidor y no está pendiente.
        let merged = ActivitySync.merge(local: [makeActivity("gone")], remote: [], pendingIds: [])
        XCTAssertTrue(merged.isEmpty)
    }

    func testLocallyDeletedDoesNotReappear() {
        let remote = [makeActivity("a"), makeActivity("b", day: "2026-03-05")]
        let merged = ActivitySync.merge(local: [], remote: remote, pendingIds: [], deletedIds: ["a"])
        XCTAssertEqual(ids(merged), ["b"])
    }

    func testRemoteNewActivitiesFromAnotherDeviceAreHydrated() {
        let merged = ActivitySync.merge(local: [], remote: [makeActivity("pwa-1", day: "2026-03-02"), makeActivity("pwa-2", day: "2026-03-03")], pendingIds: [])
        XCTAssertEqual(ids(merged), ["pwa-2", "pwa-1"])
    }

    func testNewIdIsLowercaseUUIDv4() throws {
        let id = ActivitySync.newId()
        XCTAssertEqual(id, id.lowercased())
        let uuid = try XCTUnwrap(UUID(uuidString: id))
        XCTAssertEqual(uuid.uuidString.lowercased(), id)
        XCTAssertEqual(id.split(separator: "-")[2].first, "4")
        XCTAssertNotEqual(ActivitySync.newId(), ActivitySync.newId())
    }
}

final class ActivityValidationTests: XCTestCase {
    func testAcceptsValidDraft() {
        XCTAssertNoThrow(try ActivityValidation.validate(makeDraft()))
        XCTAssertNoThrow(try ActivityValidation.validate(ActivityDraft(type: .run, occurredOn: "2028-02-29", durationSeconds: 0, distanceKm: 5, runLocation: .calle, feeling: 5)))
    }

    func testRejectsWhatTheSchemaWouldReject() {
        XCTAssertThrowsError(try ActivityValidation.validate(makeDraft(duration: -1)))
        XCTAssertThrowsError(try ActivityValidation.validate(makeDraft(day: "2026-02-30")))
        XCTAssertThrowsError(try ActivityValidation.validate(makeDraft(day: "04/03/2026")))
        XCTAssertThrowsError(try ActivityValidation.validate(ActivityDraft(type: .run, occurredOn: "2026-03-04", durationSeconds: 1, feeling: 6)))
        XCTAssertThrowsError(try ActivityValidation.validate(ActivityDraft(type: .run, occurredOn: "2026-03-04", durationSeconds: 1, feeling: 0)))
        XCTAssertThrowsError(try ActivityValidation.validate(ActivityDraft(type: .run, occurredOn: "2026-03-04", durationSeconds: 1, distanceKm: -1)))
        XCTAssertThrowsError(try ActivityValidation.validate(ActivityDraft(type: .run, occurredOn: "2026-03-04", durationSeconds: 1, distanceKm: .nan)))
        XCTAssertThrowsError(try ActivityValidation.validate(ActivityDraft(type: .workoutDay, occurredOn: "2026-03-04", durationSeconds: 1, dayId: String(repeating: "x", count: 65))))
        XCTAssertThrowsError(try ActivityValidation.validate(ActivityDraft(type: .workoutDay, occurredOn: "2026-03-04", durationSeconds: 1, blocksCompleted: -1)))
    }

    func testLocalDayFormat() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        // 2026-03-05 01:30 UTC sigue siendo 4 de marzo en Buenos Aires (UTC-3).
        let date = Date(timeIntervalSince1970: 1_772_674_200)
        XCTAssertEqual(ActivityValidation.localDay(date, calendar: cal), "2026-03-04")
    }
}
