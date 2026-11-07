import XCTest

final class RoutineValidationTests: XCTestCase {
    private func makeValidRoutine() -> RutinaData {
        let ej = Ejercicio(detalle: "Sentadillas", segundos: 30)
        let bloque = Bloque(id: "b1", tipo: .amrap, nombre: "Bloque A", duracionMinutos: 12, ejercicios: [ej])
        let dia = DiaEntrenamiento(id: "d1", nombre: "Día 1", ubicacion: "Gym", calentamiento: "5 min trote", calentamientoMinutos: 5, bloques: [bloque])
        return RutinaData(usuario: "TestUser", edad: 30, objetivo: "Mejorar salud", diasEntrenamiento: [dia])
    }

    func testValidRoutinePasses() {
        let r = makeValidRoutine()
        let result = RoutineValidator.validateRutina(r)
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testEmptyUserFails() {
        var r = makeValidRoutine()
        r.usuario = "   "
        let result = RoutineValidator.validateRutina(r)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("usuario") })
    }

    func testInvalidAgeFails() {
        var r = makeValidRoutine()
        r.edad = 0
        XCTAssertFalse(RoutineValidator.validateRutina(r).isValid)

        r.edad = 121
        XCTAssertFalse(RoutineValidator.validateRutina(r).isValid)

        r.edad = 25
        XCTAssertTrue(RoutineValidator.validateRutina(r).isValid)
    }

    func testInvalidGoalFails() {
        var r = makeValidRoutine()
        r.objetivo = ""
        XCTAssertFalse(RoutineValidator.validateRutina(r).isValid)

        r.objetivo = String(repeating: "A", count: 301)
        XCTAssertFalse(RoutineValidator.validateRutina(r).isValid)
    }

    func testDaysCountLimits() {
        var r = makeValidRoutine()
        r.diasEntrenamiento = []
        XCTAssertFalse(RoutineValidator.validateRutina(r).isValid)

        r.diasEntrenamiento = (1...11).map { idx in
            let b = Bloque(id: "b_\(idx)", tipo: .amrap, nombre: "Bloque", duracionMinutos: 10, ejercicios: [Ejercicio(detalle: "Ej")])
            return DiaEntrenamiento(id: "d_\(idx)", nombre: "Día \(idx)", bloques: [b])
        }
        XCTAssertFalse(RoutineValidator.validateRutina(r).isValid)
    }

    func testDuplicateDayIdFails() {
        var r = makeValidRoutine()
        let b1 = Bloque(id: "b1", tipo: .amrap, nombre: "B1", duracionMinutos: 10, ejercicios: [Ejercicio(detalle: "Ej")])
        let b2 = Bloque(id: "b2", tipo: .amrap, nombre: "B2", duracionMinutos: 10, ejercicios: [Ejercicio(detalle: "Ej")])
        r.diasEntrenamiento = [
            DiaEntrenamiento(id: "same_id", nombre: "Día 1", bloques: [b1]),
            DiaEntrenamiento(id: "same_id", nombre: "Día 2", bloques: [b2])
        ]
        let res = RoutineValidator.validateRutina(r)
        XCTAssertFalse(res.isValid)
        XCTAssertTrue(res.errors.contains { $0.contains("duplicado") })
    }

    func testBlockLimitsAndValidation() {
        var r = makeValidRoutine()
        // Bloque sin nombre
        r.diasEntrenamiento[0].bloques[0].nombre = "   "
        XCTAssertFalse(RoutineValidator.validateRutina(r).isValid)

        // Rondas fuera de rango
        r = makeValidRoutine()
        r.diasEntrenamiento[0].bloques[0].rondas = 100
        XCTAssertFalse(RoutineValidator.validateRutina(r).isValid)

        // Descanso negativo
        r = makeValidRoutine()
        r.diasEntrenamiento[0].bloques[0].descansoSeg = -1
        XCTAssertFalse(RoutineValidator.validateRutina(r).isValid)

        // Duración minutos fuera de rango
        r = makeValidRoutine()
        r.diasEntrenamiento[0].bloques[0].duracionMinutos = 150
        XCTAssertFalse(RoutineValidator.validateRutina(r).isValid)
    }

    func testExerciseLimitsAndValidation() {
        var r = makeValidRoutine()
        r.diasEntrenamiento[0].bloques[0].ejercicios = [
            Ejercicio(detalle: "   ")
        ]
        XCTAssertFalse(RoutineValidator.validateRutina(r).isValid)

        r = makeValidRoutine()
        r.diasEntrenamiento[0].bloques[0].ejercicios = [
            Ejercicio(detalle: "Válido", segundos: 700)
        ]
        XCTAssertFalse(RoutineValidator.validateRutina(r).isValid)
    }

    func testNormalizerAssignsMissingIds() {
        let b1 = Bloque(id: nil, tipo: .amrap, nombre: "B1", duracionMinutos: 10, ejercicios: [])
        let b2 = Bloque(id: "", tipo: .emom, nombre: "B2", duracionMinutos: 16, ejercicios: [])
        let d = DiaEntrenamiento(id: "d1", nombre: "Día 1", bloques: [b1, b2])
        let r = RutinaData(usuario: "User", edad: 25, objetivo: "Cardio", diasEntrenamiento: [d])

        let normalized = RoutineNormalizer.normalizeRutina(r)
        XCTAssertNotNil(normalized.diasEntrenamiento[0].bloques[0].id)
        XCTAssertFalse(normalized.diasEntrenamiento[0].bloques[0].id!.isEmpty)
        XCTAssertNotNil(normalized.diasEntrenamiento[0].bloques[1].id)
        XCTAssertFalse(normalized.diasEntrenamiento[0].bloques[1].id!.isEmpty)
        XCTAssertNotEqual(normalized.diasEntrenamiento[0].bloques[0].id, normalized.diasEntrenamiento[0].bloques[1].id)
    }
}
