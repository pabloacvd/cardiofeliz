import Foundation

// MARK: - Manipulación y edición de rutinas (espejo de `src/utils/routineEdit.ts`)

public enum RoutineEditorOperations {
    // MARK: - Comparación

    public static func hasRoutineChanges(a: RutinaData, b: RutinaData) -> Bool {
        a != b
    }

    // MARK: - Metadatos

    public static func updateRoutineMeta(
        rutina: RutinaData,
        objetivo: String? = nil,
        edad: Int? = nil
    ) -> RutinaData {
        var next = rutina
        if let objetivo { next.objetivo = objetivo }
        if let edad { next.edad = edad }
        return next
    }

    // MARK: - Tabata y EMOM

    public static func regenerateTabataStructure(rondas: Int, trabajoSeg: Int, descansoSeg: Int) -> String {
        "\(trabajoSeg) seg trabajo / \(descansoSeg) seg descanso x \(rondas) rondas"
    }

    public static func renumberEmomExercises(_ ejercicios: [Ejercicio]) -> [Ejercicio] {
        ejercicios.enumerated().map { idx, ej in
            Ejercicio(detalle: ej.detalle, minuto: idx + 1, segundos: nil)
        }
    }

    public static func stripEmomMinutes(_ ejercicios: [Ejercicio]) -> [Ejercicio] {
        ejercicios.map { ej in
            Ejercicio(detalle: ej.detalle, minuto: nil, segundos: ej.segundos)
        }
    }

    private static func moveArrayItem<T>(_ arr: [T], fromIndex: Int, toIndex: Int) -> [T] {
        guard fromIndex >= 0, fromIndex < arr.count, toIndex >= 0, toIndex < arr.count else {
            return arr
        }
        guard fromIndex != toIndex else { return arr }
        var copy = arr
        let item = copy.remove(at: fromIndex)
        copy.insert(item, at: toIndex)
        return copy
    }

    // MARK: - Días

    public static func addDay(_ rutina: RutinaData) -> RutinaData {
        var next = rutina
        let nextNumber = next.diasEntrenamiento.count + 1
        let newDayId = "dia_\(RoutineIdGenerator.generateId())"
        var defaultBlock = RoutineBlockFactory.newBloqueDefaults(tipo: .amrap)
        defaultBlock.nombre = "Bloque A"

        let newDay = DiaEntrenamiento(
            id: newDayId,
            nombre: "Día \(nextNumber)",
            ubicacion: "Gym / Casa",
            calentamiento: "5 min caminata inclinada o trote suave",
            calentamientoMinutos: 5,
            bloques: [defaultBlock]
        )

        next.diasEntrenamiento.append(newDay)
        return next
    }

    public static func updateDay(
        rutina: RutinaData,
        diaId: String,
        nombre: String? = nil,
        ubicacion: String? = nil,
        calentamiento: String? = nil,
        calentamientoMinutos: Int?? = nil
    ) -> RutinaData {
        var next = rutina
        guard let idx = next.diasEntrenamiento.firstIndex(where: { $0.id == diaId }) else {
            return next
        }

        var day = next.diasEntrenamiento[idx]
        if let nombre { day.nombre = nombre }
        if let ubicacion { day.ubicacion = ubicacion }
        if let calentamiento { day.calentamiento = calentamiento }
        if let calMin = calentamientoMinutos {
            day.calentamientoMinutos = calMin
        }

        next.diasEntrenamiento[idx] = day
        return next
    }

    public static func removeDay(_ rutina: RutinaData, diaId: String) -> RutinaData {
        var next = rutina
        next.diasEntrenamiento.removeAll { $0.id == diaId }
        return next
    }

    public static func moveDay(_ rutina: RutinaData, fromIndex: Int, toIndex: Int) -> RutinaData {
        var next = rutina
        next.diasEntrenamiento = moveArrayItem(next.diasEntrenamiento, fromIndex: fromIndex, toIndex: toIndex)
        return next
    }

    // MARK: - Bloques

    public static func addBlock(
        _ rutina: RutinaData,
        diaId: String,
        tipo: TipoBloque = .amrap
    ) -> RutinaData {
        var next = rutina
        guard let dayIdx = next.diasEntrenamiento.firstIndex(where: { $0.id == diaId }) else {
            return next
        }

        var day = next.diasEntrenamiento[dayIdx]
        var newBlock = RoutineBlockFactory.newBloqueDefaults(tipo: tipo)
        let letterIndex = day.bloques.count % 26
        let letter = UnicodeScalar(65 + letterIndex).map { String(Character($0)) } ?? "A"
        newBlock.nombre = "Bloque \(letter)"

        day.bloques.append(newBlock)
        next.diasEntrenamiento[dayIdx] = day
        return next
    }

    public static func updateBlock(
        _ rutina: RutinaData,
        diaId: String,
        bloqueId: String,
        mutate: (inout Bloque) -> Void
    ) -> RutinaData {
        var next = rutina
        guard let dayIdx = next.diasEntrenamiento.firstIndex(where: { $0.id == diaId }) else {
            return next
        }
        var day = next.diasEntrenamiento[dayIdx]
        guard let blockIdx = day.bloques.firstIndex(where: { $0.id == bloqueId }) else {
            return next
        }

        var block = day.bloques[blockIdx]
        mutate(&block)

        if block.tipo == .tabata {
            let rondas = block.rondas ?? 8
            let trabajo = block.trabajoSeg ?? 20
            let descanso = block.descansoTabataSeg ?? 10
            block.estructura = regenerateTabataStructure(rondas: rondas, trabajoSeg: trabajo, descansoSeg: descanso)
        }

        if block.tipo == .triserie || block.tipo == .density {
            if block.descansoSeg != nil {
                block.descansoEntreRondas = nil
            }
        }

        day.bloques[blockIdx] = block
        next.diasEntrenamiento[dayIdx] = day
        return next
    }

    public static func changeBlockType(
        _ rutina: RutinaData,
        diaId: String,
        bloqueId: String,
        newTipo: TipoBloque
    ) -> RutinaData {
        var next = rutina
        guard let dayIdx = next.diasEntrenamiento.firstIndex(where: { $0.id == diaId }) else {
            return next
        }
        var day = next.diasEntrenamiento[dayIdx]
        guard let blockIdx = day.bloques.firstIndex(where: { $0.id == bloqueId }) else {
            return next
        }

        let oldBlock = day.bloques[blockIdx]
        var template = RoutineBlockFactory.newBloqueDefaults(tipo: newTipo)

        var ejercicios = oldBlock.ejercicios
        if newTipo == .emom {
            ejercicios = renumberEmomExercises(ejercicios)
        } else if oldBlock.tipo == .emom {
            ejercicios = stripEmomMinutes(ejercicios)
        }

        template.id = oldBlock.id ?? RoutineIdGenerator.generateId()
        template.nombre = oldBlock.nombre
        template.ejercicios = ejercicios

        day.bloques[blockIdx] = template
        next.diasEntrenamiento[dayIdx] = day
        return next
    }

    public static func duplicateBlock(
        _ rutina: RutinaData,
        diaId: String,
        bloqueId: String
    ) -> RutinaData {
        var next = rutina
        guard let dayIdx = next.diasEntrenamiento.firstIndex(where: { $0.id == diaId }) else {
            return next
        }
        var day = next.diasEntrenamiento[dayIdx]
        guard let blockIdx = day.bloques.firstIndex(where: { $0.id == bloqueId }) else {
            return next
        }

        let original = day.bloques[blockIdx]
        var copy = original
        copy.id = RoutineIdGenerator.generateId()
        copy.nombre = "\(original.nombre) (Copia)"

        day.bloques.insert(copy, at: blockIdx + 1)
        next.diasEntrenamiento[dayIdx] = day
        return next
    }

    public static func removeBlock(
        _ rutina: RutinaData,
        diaId: String,
        bloqueId: String
    ) -> RutinaData {
        var next = rutina
        guard let dayIdx = next.diasEntrenamiento.firstIndex(where: { $0.id == diaId }) else {
            return next
        }
        var day = next.diasEntrenamiento[dayIdx]
        day.bloques.removeAll { $0.id == bloqueId }
        next.diasEntrenamiento[dayIdx] = day
        return next
    }

    public static func moveBlock(
        _ rutina: RutinaData,
        diaId: String,
        fromIndex: Int,
        toIndex: Int
    ) -> RutinaData {
        var next = rutina
        guard let dayIdx = next.diasEntrenamiento.firstIndex(where: { $0.id == diaId }) else {
            return next
        }
        var day = next.diasEntrenamiento[dayIdx]
        day.bloques = moveArrayItem(day.bloques, fromIndex: fromIndex, toIndex: toIndex)
        next.diasEntrenamiento[dayIdx] = day
        return next
    }

    // MARK: - Ejercicios

    public static func addExercise(
        _ rutina: RutinaData,
        diaId: String,
        bloqueId: String,
        detalle: String = "",
        segundos: Int? = nil
    ) -> RutinaData {
        var next = rutina
        guard let dayIdx = next.diasEntrenamiento.firstIndex(where: { $0.id == diaId }) else {
            return next
        }
        var day = next.diasEntrenamiento[dayIdx]
        guard let blockIdx = day.bloques.firstIndex(where: { $0.id == bloqueId }) else {
            return next
        }
        var block = day.bloques[blockIdx]

        if block.tipo == .emom {
            let minuto = block.ejercicios.count + 1
            block.ejercicios.append(Ejercicio(detalle: detalle, minuto: minuto))
        } else {
            block.ejercicios.append(Ejercicio(detalle: detalle, minuto: nil, segundos: segundos))
        }

        day.bloques[blockIdx] = block
        next.diasEntrenamiento[dayIdx] = day
        return next
    }

    public static func updateExercise(
        _ rutina: RutinaData,
        diaId: String,
        bloqueId: String,
        exerciseIndex: Int,
        detalle: String? = nil,
        segundos: Int?? = nil
    ) -> RutinaData {
        var next = rutina
        guard let dayIdx = next.diasEntrenamiento.firstIndex(where: { $0.id == diaId }) else {
            return next
        }
        var day = next.diasEntrenamiento[dayIdx]
        guard let blockIdx = day.bloques.firstIndex(where: { $0.id == bloqueId }) else {
            return next
        }
        var block = day.bloques[blockIdx]
        guard exerciseIndex >= 0, exerciseIndex < block.ejercicios.count else {
            return next
        }

        var ej = block.ejercicios[exerciseIndex]
        if let detalle { ej.detalle = detalle }
        if block.tipo != .emom, let segundos {
            ej.segundos = segundos
        }

        block.ejercicios[exerciseIndex] = ej
        day.bloques[blockIdx] = block
        next.diasEntrenamiento[dayIdx] = day
        return next
    }

    public static func removeExercise(
        _ rutina: RutinaData,
        diaId: String,
        bloqueId: String,
        exerciseIndex: Int
    ) -> RutinaData {
        var next = rutina
        guard let dayIdx = next.diasEntrenamiento.firstIndex(where: { $0.id == diaId }) else {
            return next
        }
        var day = next.diasEntrenamiento[dayIdx]
        guard let blockIdx = day.bloques.firstIndex(where: { $0.id == bloqueId }) else {
            return next
        }
        var block = day.bloques[blockIdx]
        guard exerciseIndex >= 0, exerciseIndex < block.ejercicios.count else {
            return next
        }

        block.ejercicios.remove(at: exerciseIndex)
        if block.tipo == .emom {
            block.ejercicios = renumberEmomExercises(block.ejercicios)
        }

        day.bloques[blockIdx] = block
        next.diasEntrenamiento[dayIdx] = day
        return next
    }

    public static func moveExercise(
        _ rutina: RutinaData,
        diaId: String,
        bloqueId: String,
        fromIndex: Int,
        toIndex: Int
    ) -> RutinaData {
        var next = rutina
        guard let dayIdx = next.diasEntrenamiento.firstIndex(where: { $0.id == diaId }) else {
            return next
        }
        var day = next.diasEntrenamiento[dayIdx]
        guard let blockIdx = day.bloques.firstIndex(where: { $0.id == bloqueId }) else {
            return next
        }
        var block = day.bloques[blockIdx]

        block.ejercicios = moveArrayItem(block.ejercicios, fromIndex: fromIndex, toIndex: toIndex)
        if block.tipo == .emom {
            block.ejercicios = renumberEmomExercises(block.ejercicios)
        }

        day.bloques[blockIdx] = block
        next.diasEntrenamiento[dayIdx] = day
        return next
    }
}
