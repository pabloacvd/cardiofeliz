import XCTest

final class RoutineImportExportTests: XCTestCase {
    func testSerializeAndParseRoundtrip() {
        let ej = Ejercicio(detalle: "Sentadilla Goblet", segundos: 45)
        let bloque = Bloque(id: "b1", tipo: .amrap, nombre: "Bloque 1", duracionMinutos: 15, ejercicios: [ej])
        let dia = DiaEntrenamiento(id: "d1", nombre: "Día 1", ubicacion: "Gimnasio", calentamiento: "Calentamiento", calentamientoMinutos: 5, bloques: [bloque])
        let rutina = RutinaData(usuario: "OriginalUser", edad: 28, objetivo: "Cardio", diasEntrenamiento: [dia])

        guard let serialized = try? RoutineImportExport.serializeRoutine(rutina) else {
            XCTFail("Falló serialización")
            return
        }

        XCTAssertTrue(serialized.contains("Sentadilla Goblet"))
        XCTAssertTrue(serialized.contains("dias_entrenamiento"))

        let parseResult = RoutineImportExport.parseImportedRoutine(text: serialized, usuario: "ImportUser")
        switch parseResult {
        case .success(let imported):
            XCTAssertEqual(imported.usuario, "ImportUser") // Se fuerza el usuario actual
            XCTAssertEqual(imported.edad, 28)
            XCTAssertEqual(imported.objetivo, "Cardio")
            XCTAssertEqual(imported.diasEntrenamiento.count, 1)
            XCTAssertEqual(imported.diasEntrenamiento[0].bloques[0].nombre, "Bloque 1")
        case .failure(let errors):
            XCTFail("Falló parseo: \(errors)")
        }
    }

    func testParseRejectsEmptyOrWhitespace() {
        let resEmpty = RoutineImportExport.parseImportedRoutine(text: "", usuario: "User")
        XCTAssertEqual(resEmpty, .failure(["El archivo o texto esta vacio."]))

        let resSpace = RoutineImportExport.parseImportedRoutine(text: "    \n\t  ", usuario: "User")
        XCTAssertEqual(resSpace, .failure(["El archivo o texto esta vacio."]))
    }

    func testParseRejectsOversizedContent() {
        let hugeString = String(repeating: "A", count: 600 * 1024)
        let res = RoutineImportExport.parseImportedRoutine(text: hugeString, usuario: "User")
        switch res {
        case .failure(let errors):
            XCTAssertTrue(errors.contains { $0.contains("500 KB") })
        case .success:
            XCTFail("Debió rechazar por tamaño")
        }
    }

    func testParseRejectsInvalidJson() {
        let res = RoutineImportExport.parseImportedRoutine(text: "{ invalid json here", usuario: "User")
        switch res {
        case .failure(let errors):
            XCTAssertTrue(errors.contains { $0.contains("JSON") })
        case .success:
            XCTFail("Debió rechazar json inválido")
        }
    }

    func testParseReportsValidationErrors() {
        let invalidDataJson = """
        {
            "usuario": "Test",
            "edad": 200,
            "objetivo": "Valido",
            "dias_entrenamiento": []
        }
        """
        let res = RoutineImportExport.parseImportedRoutine(text: invalidDataJson, usuario: "User")
        switch res {
        case .failure(let errors):
            XCTAssertTrue(errors.contains { $0.contains("edad") })
            XCTAssertTrue(errors.contains { $0.contains("dia de entrenamiento") })
        case .success:
            XCTFail("Debió reportar errores de validación")
        }
    }

    func testIsDefaultRoutineComparison() {
        let defaultRoutine = RoutineSyncLogic.getDefaultRoutine(displayName: "TestUser")
        XCTAssertTrue(RoutineImportExport.isDefaultRoutine(defaultRoutine))

        var modified = defaultRoutine
        modified.objetivo = "Objetivo modificado"
        XCTAssertFalse(RoutineImportExport.isDefaultRoutine(modified))
    }
}
