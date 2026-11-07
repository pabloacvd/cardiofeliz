import XCTest

final class RoutineDecodingTests: XCTestCase {

    func testDefaultRoutineDecodes() throws {
        let r = try Fixtures.defaultRoutine()
        XCTAssertEqual(r.usuario, "Juli")
        XCTAssertEqual(r.edad, 33)
        XCTAssertEqual(r.objetivo, "Quema máxima de grasa sin hipertrofia, bajo impacto articular")
        XCTAssertEqual(r.diasEntrenamiento.map(\.id), ["dia_1", "dia_2", "dia_3"])
        XCTAssertEqual(r.diasEntrenamiento.map { $0.bloques.count }, [5, 3, 3])
    }

    func testDefaultRoutineCoversAllBlockTypesExceptUnused() throws {
        let r = try Fixtures.defaultRoutine()
        let tipos = Set(r.diasEntrenamiento.flatMap(\.bloques).map(\.tipo))
        // La rutina por defecto no usa TRISERIE, FOR_TIME ni HIIT_INTERVALS; esos se cubren con JSON propio.
        XCTAssertEqual(tipos, [.emom, .tabata, .finisher, .density, .amrap])
    }

    func testDayFieldsUseSpanishKeys() throws {
        let dia = try XCTUnwrap(Fixtures.defaultRoutine().diasEntrenamiento.first)
        XCTAssertEqual(dia.calentamientoMinutos, 5)
        XCTAssertEqual(dia.ubicacion, "Rincón de cardio + Piso superior")
        XCTAssertTrue(dia.calentamiento.hasPrefix("5 min"))
    }

    func testEmomExercisesCarryMinuto() throws {
        let b = try Fixtures.bloque("dia_1", "dia_1_bloque_a")
        XCTAssertEqual(b.tipo, .emom)
        XCTAssertEqual(b.duracionMinutos, 15)
        XCTAssertEqual(b.ejercicios.count, 15)
        XCTAssertEqual(b.ejercicios[3].minuto, 4)
        XCTAssertNil(b.ejercicios[3].segundos)
        XCTAssertTrue(b.ejercicios[3].esDescanso)
    }

    func testGenericExercisesCarryOptionalSegundos() throws {
        let manual = try Fixtures.bloque("dia_1", "dia_1_bloque_c")
        XCTAssertNil(manual.ejercicios[0].segundos)
        XCTAssertNil(manual.ejercicios[0].minuto)
        XCTAssertEqual(manual.ejercicios[2].segundos, 30)

        let timed = try Fixtures.bloque("dia_2", "dia_2_bloque_c")
        XCTAssertEqual(timed.ejercicios.compactMap(\.segundos), [30, 30, 30])
    }

    func testTabataFields() throws {
        let b = try Fixtures.bloque("dia_3", "dia_3_bloque_c")
        XCTAssertEqual(b.tipo, .tabata)
        XCTAssertEqual(b.rondas, 8)
        XCTAssertEqual(b.trabajoSeg, 20)
        XCTAssertEqual(b.descansoTabataSeg, 10)
        XCTAssertEqual(b.estructura, "20 seg trabajo / 10 seg descanso x 8 rondas")
    }

    func testDensityHasBothRestRepresentations() throws {
        let b = try Fixtures.bloque("dia_2", "dia_2_bloque_a")
        XCTAssertEqual(b.tipo, .density)
        XCTAssertEqual(b.descansoSeg, 45)
        XCTAssertEqual(b.descansoEntreRondas, "45 seg")
    }

    func testMissingOptionalFieldsDecodeAsNil() throws {
        let b = try decode(Bloque.self, #"{"tipo":"AMRAP","nombre":"X","ejercicios":[]}"#)
        XCTAssertNil(b.id)
        XCTAssertNil(b.duracionMinutos)
        XCTAssertNil(b.rondas)
        XCTAssertNil(b.descansoSeg)
        XCTAssertNil(b.trabajoSeg)
    }

    func testMissingEjerciciosAndNombreDefault() throws {
        let b = try decode(Bloque.self, #"{"tipo":"FINISHER"}"#)
        XCTAssertEqual(b.nombre, "")
        XCTAssertTrue(b.ejercicios.isEmpty)
    }

    func testInvalidNumbersAreDiscardedLikeThePWA() throws {
        // La PWA descarta valores no enteros/no numéricos y cae al default.
        let b = try decode(Bloque.self, #"{"tipo":"TABATA","nombre":"X","rondas":1.5,"trabajo_seg":"20","ejercicios":[]}"#)
        XCTAssertNil(b.rondas)
        XCTAssertNil(b.trabajoSeg)
    }

    func testNullNumbersDecodeAsNil() throws {
        let b = try decode(Bloque.self, #"{"tipo":"EMOM","nombre":"X","duracion_minutos":null,"ejercicios":[]}"#)
        XCTAssertNil(b.duracionMinutos)
    }

    func testUnknownBlockTypeFails() {
        XCTAssertThrowsError(try decode(Bloque.self, #"{"tipo":"YOGA","nombre":"X","ejercicios":[]}"#))
    }

    func testUnknownExtraKeysAreIgnored() throws {
        let b = try decode(Bloque.self, #"{"tipo":"AMRAP","nombre":"X","ejercicios":[],"campo_futuro":123}"#)
        XCTAssertEqual(b.tipo, .amrap)
    }

    func testAllEightTypesDecode() throws {
        for tipo in TipoBloque.allCases {
            let b = try decode(Bloque.self, #"{"tipo":"\#(tipo.rawValue)","nombre":"X","ejercicios":[]}"#)
            XCTAssertEqual(b.tipo, tipo)
        }
        XCTAssertEqual(TipoBloque.allCases.count, 8)
    }

    func testRoutineRoundTripPreservesKeysAndValues() throws {
        let original = try Fixtures.defaultRoutine()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RutinaData.self, from: data)
        XCTAssertEqual(decoded, original)

        // El JSON reescrito conserva las claves en español de la PWA.
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(object["dias_entrenamiento"])
        let dia = try XCTUnwrap((object["dias_entrenamiento"] as? [[String: Any]])?.first)
        XCTAssertNotNil(dia["calentamiento_minutos"])
        let bloque = try XCTUnwrap((dia["bloques"] as? [[String: Any]])?.first)
        XCTAssertNotNil(bloque["duracion_minutos"])
        XCTAssertNil(bloque["rondas"], "No debe escribir claves nulas")
    }

    func testRoutineRowDecodesJsonbData() throws {
        let rutina = try String(data: Fixtures.rutinaData(), encoding: .utf8) ?? ""
        let json = #"{"user_id":"u1","data":\#(rutina),"updated_at":"2026-05-01T10:00:00+00:00"}"#
        let row = try decode(RoutineRow.self, json)
        XCTAssertEqual(row.userId, "u1")
        XCTAssertEqual(row.data.diasEntrenamiento.count, 3)
    }
}

final class DatabaseRowDecodingTests: XCTestCase {

    func testProfileRow() throws {
        let row = try decode(ProfileRow.self, """
        {"user_id":"u1","display_name":"Juli","weight_kg":62.5,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}
        """)
        XCTAssertEqual(row.displayName, "Juli")
        XCTAssertEqual(row.weightKg?.value, 62.5)
    }

    func testProfileRowWithNulls() throws {
        let row = try decode(ProfileRow.self, """
        {"user_id":"u1","display_name":null,"weight_kg":null,"created_at":"c","updated_at":"u"}
        """)
        XCTAssertNil(row.displayName)
        XCTAssertNil(row.weightKg)
    }

    func testNumericAsStringIsAccepted() throws {
        let row = try decode(ProfileRow.self, """
        {"user_id":"u1","weight_kg":"62.50","created_at":"c","updated_at":"u"}
        """)
        XCTAssertEqual(row.weightKg?.value, 62.5)
    }

    func testWorkoutActivityRow() throws {
        let row = try decode(ActivityRow.self, """
        {"id":"a1","user_id":"u1","type":"workout_day","occurred_on":"2026-05-01","started_at":"2026-05-01T10:00:00+00:00",
         "duration_seconds":2700,"day_id":"dia_1","blocks_completed":5,"rounds_total":null,"distance_km":null,
         "run_location":null,"feeling":4,"calories_kcal":310.5,"xp_earned":120,"created_at":"2026-05-01T11:00:00Z"}
        """)
        XCTAssertEqual(row.type, .workoutDay)
        XCTAssertEqual(row.occurredOn, "2026-05-01")
        XCTAssertEqual(row.durationSeconds, 2700)
        XCTAssertEqual(row.dayId, "dia_1")
        XCTAssertEqual(row.blocksCompleted, 5)
        XCTAssertNil(row.roundsTotal)
        XCTAssertEqual(row.caloriesKcal?.value, 310.5)
        XCTAssertEqual(row.xpEarned, 120)
    }

    func testRunActivityRow() throws {
        let row = try decode(ActivityRow.self, """
        {"id":"a2","user_id":"u1","type":"run","occurred_on":"2026-05-02","started_at":null,"duration_seconds":1800,
         "day_id":null,"blocks_completed":null,"rounds_total":null,"distance_km":5.25,"run_location":"calle",
         "feeling":null,"calories_kcal":null,"xp_earned":60,"created_at":"c"}
        """)
        XCTAssertEqual(row.type, .run)
        XCTAssertEqual(row.runLocation, .calle)
        XCTAssertEqual(row.distanceKm?.value, 5.25)
    }

    func testActiveRestActivityType() throws {
        let row = try decode(ActivityRow.self, """
        {"id":"a3","user_id":"u1","type":"active_rest","occurred_on":"2026-05-03","duration_seconds":600,"xp_earned":10,"created_at":"c"}
        """)
        XCTAssertEqual(row.type, .activeRest)
        XCTAssertNil(row.startedAt)
    }

    func testActivityRowEncodesSnakeCase() throws {
        let row = try decode(ActivityRow.self, """
        {"id":"a1","user_id":"u1","type":"run","occurred_on":"2026-05-02","duration_seconds":10,"xp_earned":1,"created_at":"c"}
        """)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any])
        XCTAssertEqual(object["occurred_on"] as? String, "2026-05-02")
        XCTAssertEqual(object["duration_seconds"] as? Int, 10)
        XCTAssertEqual(object["user_id"] as? String, "u1")
    }

    func testAchievementRow() throws {
        let row = try decode(AchievementRow.self, """
        {"user_id":"u1","achievement_id":"first_workout","unlocked_at":"2026-05-01T10:00:00Z"}
        """)
        XCTAssertEqual(row.achievementId, "first_workout")
        XCTAssertEqual(row.unlockedAt, "2026-05-01T10:00:00Z")
    }

    func testVacationRowActiveAndClosed() throws {
        let active = try decode(VacationRow.self, """
        {"id":"v1","user_id":"u1","start_on":"2026-06-01","end_on":null,"created_at":"c"}
        """)
        XCTAssertNil(active.endOn)
        let closed = try decode(VacationRow.self, """
        {"id":"v2","user_id":"u1","start_on":"2026-06-01","end_on":"2026-06-10","created_at":"c"}
        """)
        XCTAssertEqual(closed.endOn, "2026-06-10")
    }
}
