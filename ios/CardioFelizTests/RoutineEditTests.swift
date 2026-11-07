import XCTest

final class RoutineEditTests: XCTestCase {
    private func makeBaseRoutine() -> RutinaData {
        let ej1 = Ejercicio(detalle: "Burpees", minuto: 1)
        let ej2 = Ejercicio(detalle: "Pushups", minuto: 2)
        let b1 = Bloque(id: "b1", tipo: .emom, nombre: "Bloque A", duracionMinutos: 16, ejercicios: [ej1, ej2])
        let d1 = DiaEntrenamiento(id: "d1", nombre: "Día 1", ubicacion: "Gym", calentamiento: "5 min trote", calentamientoMinutos: 5, bloques: [b1])
        return RutinaData(usuario: "User", edad: 30, objetivo: "Salud", diasEntrenamiento: [d1])
    }

    func testMetaEditing() {
        let r = makeBaseRoutine()
        let updated = RoutineEditorOperations.updateRoutineMeta(rutina: r, objetivo: "Nuevo objetivo", edad: 35)
        XCTAssertEqual(updated.objetivo, "Nuevo objetivo")
        XCTAssertEqual(updated.edad, 35)
        XCTAssertTrue(RoutineEditorOperations.hasRoutineChanges(a: r, b: updated))
    }

    func testDayOperations() {
        var r = makeBaseRoutine()

        // Agregar día
        r = RoutineEditorOperations.addDay(r)
        XCTAssertEqual(r.diasEntrenamiento.count, 2)
        XCTAssertEqual(r.diasEntrenamiento[1].nombre, "Día 2")

        // Modificar día
        r = RoutineEditorOperations.updateDay(rutina: r, diaId: r.diasEntrenamiento[1].id, nombre: "Día 2 Modificado", ubicacion: "Casa")
        XCTAssertEqual(r.diasEntrenamiento[1].nombre, "Día 2 Modificado")
        XCTAssertEqual(r.diasEntrenamiento[1].ubicacion, "Casa")

        // Reordenar días
        let firstId = r.diasEntrenamiento[0].id
        r = RoutineEditorOperations.moveDay(r, fromIndex: 0, toIndex: 1)
        XCTAssertEqual(r.diasEntrenamiento[1].id, firstId)

        // Eliminar día
        r = RoutineEditorOperations.removeDay(r, diaId: firstId)
        XCTAssertEqual(r.diasEntrenamiento.count, 1)
    }

    func testBlockOperations() {
        var r = makeBaseRoutine()
        let dayId = r.diasEntrenamiento[0].id

        // Agregar bloque
        r = RoutineEditorOperations.addBlock(r, diaId: dayId, tipo: .tabata)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques.count, 2)
        let tabataBlock = r.diasEntrenamiento[0].bloques[1]
        XCTAssertEqual(tabataBlock.tipo, .tabata)
        XCTAssertEqual(tabataBlock.rondas, 8)
        XCTAssertEqual(tabataBlock.trabajoSeg, 20)

        // Duplicar bloque
        r = RoutineEditorOperations.duplicateBlock(r, diaId: dayId, bloqueId: tabataBlock.id!)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques.count, 3)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[2].nombre, "\(tabataBlock.nombre) (Copia)")

        // Modificar bloque Tabata (regenera estructura automáticamente)
        let dupId = r.diasEntrenamiento[0].bloques[2].id!
        r = RoutineEditorOperations.updateBlock(r, diaId: dayId, bloqueId: dupId) { b in
            b.rondas = 10
            b.trabajoSeg = 30
            b.descansoTabataSeg = 15
        }
        let updatedDup = r.diasEntrenamiento[0].bloques[2]
        XCTAssertEqual(updatedDup.estructura, "30 seg trabajo / 15 seg descanso x 10 rondas")

        // Cambiar tipo de bloque de EMOM a AMRAP (debe remover 'minuto' de los ejercicios)
        let emomId = r.diasEntrenamiento[0].bloques[0].id!
        r = RoutineEditorOperations.changeBlockType(r, diaId: dayId, bloqueId: emomId, newTipo: .amrap)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[0].tipo, .amrap)
        XCTAssertNil(r.diasEntrenamiento[0].bloques[0].ejercicios[0].minuto)

        // Reconvertir a EMOM (debe renumerar minutos 1, 2...)
        r = RoutineEditorOperations.changeBlockType(r, diaId: dayId, bloqueId: emomId, newTipo: .emom)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[0].ejercicios[0].minuto, 1)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[0].ejercicios[1].minuto, 2)
    }

    func testExerciseOperations() {
        var r = makeBaseRoutine()
        let dayId = r.diasEntrenamiento[0].id
        let blockId = r.diasEntrenamiento[0].bloques[0].id!

        // Agregar ejercicio a EMOM
        r = RoutineEditorOperations.addExercise(r, diaId: dayId, bloqueId: blockId, detalle: "Jumping Jacks")
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[0].ejercicios.count, 3)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[0].ejercicios[2].minuto, 3)

        // Mover ejercicio
        r = RoutineEditorOperations.moveExercise(r, diaId: dayId, bloqueId: blockId, fromIndex: 2, toIndex: 0)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[0].ejercicios[0].detalle, "Jumping Jacks")
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[0].ejercicios[0].minuto, 1)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[0].ejercicios[1].minuto, 2)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[0].ejercicios[2].minuto, 3)

        // Eliminar ejercicio
        r = RoutineEditorOperations.removeExercise(r, diaId: dayId, bloqueId: blockId, exerciseIndex: 1)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[0].ejercicios.count, 2)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[0].ejercicios[0].minuto, 1)
        XCTAssertEqual(r.diasEntrenamiento[0].bloques[0].ejercicios[1].minuto, 2)
    }
}
