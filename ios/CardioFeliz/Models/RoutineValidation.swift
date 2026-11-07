import Foundation

// MARK: - Constantes de validación (espejo de `src/utils/routine.ts`)

public enum RoutineValidationRules {
    public static let maxDias = 10
    public static let maxBloquesPorDia = 8
    public static let maxEjerciciosPorBloque = 20
    public static let maxLenNombre = 120
    public static let maxLenTextoLargo = 300
    public static let maxDuracionMin = 120
    public static let maxCapMin = 120
    public static let maxRondas = 99
    public static let maxSeg = 600 // 10 min
    public static let maxLenId = 80
    public static let maxLenObjetivo = 300
    public static let maxEdad = 120
}

public struct RoutineValidationResult: Equatable, Sendable {
    public let isValid: Bool
    public let errors: [String]

    public init(isValid: Bool, errors: [String]) {
        self.isValid = isValid
        self.errors = errors
    }

    public static let valid = RoutineValidationResult(isValid: true, errors: [])
}

// MARK: - Generador de IDs

public enum RoutineIdGenerator {
    /// Genera un ID corto de 12 caracteres hexadecimales.
    public static func generateId() -> String {
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        return String(uuid.prefix(12))
    }
}

// MARK: - Fábrica de bloque con defaults

public enum RoutineBlockFactory {
    public static func newBloqueDefaults(tipo: TipoBloque) -> Bloque {
        let id = RoutineIdGenerator.generateId()
        switch tipo {
        case .emom:
            return Bloque(id: id, tipo: .emom, nombre: "", duracionMinutos: 16, ejercicios: [])
        case .amrap:
            return Bloque(id: id, tipo: .amrap, nombre: "", duracionMinutos: 12, ejercicios: [])
        case .triserie:
            return Bloque(id: id, tipo: .triserie, nombre: "", descansoEntreRondas: "45 seg", rondas: 4, descansoSeg: 45, ejercicios: [])
        case .density:
            return Bloque(id: id, tipo: .density, nombre: "", descansoEntreRondas: "45 seg", rondas: 4, descansoSeg: 45, ejercicios: [])
        case .forTime:
            return Bloque(id: id, tipo: .forTime, nombre: "", capMinutos: 15, ejercicios: [])
        case .tabata:
            return Bloque(id: id, tipo: .tabata, nombre: "", estructura: "20 seg trabajo / 10 seg descanso x 8 rondas", rondas: 8, trabajoSeg: 20, descansoTabataSeg: 10, ejercicios: [])
        case .finisher:
            return Bloque(id: id, tipo: .finisher, nombre: "", rondas: 3, ejercicios: [])
        case .hiitIntervals:
            return Bloque(id: id, tipo: .hiitIntervals, nombre: "", duracionMinutos: 12, rondas: 4, ejercicios: [])
        }
    }
}

// MARK: - Normalización

public enum RoutineNormalizer {
    /// Asigna IDs a los bloques que no lo tengan o lo tengan vacío.
    public static func normalizeRutina(_ rutina: RutinaData) -> RutinaData {
        var copy = rutina
        copy.diasEntrenamiento = rutina.diasEntrenamiento.enumerated().map { dIdx, dia in
            normalizeDia(dia, diaIndex: dIdx)
        }
        return copy
    }

    private static func normalizeDia(_ dia: DiaEntrenamiento, diaIndex: Int) -> DiaEntrenamiento {
        var copy = dia
        let diaId = dia.id.isEmpty ? "dia_\(diaIndex)" : dia.id
        copy.bloques = dia.bloques.enumerated().map { bIdx, bloque in
            normalizeBloque(bloque, diaId: diaId, blockIndex: bIdx)
        }
        return copy
    }

    private static func normalizeBloque(_ bloque: Bloque, diaId: String, blockIndex: Int) -> Bloque {
        var copy = bloque
        if let id = bloque.id, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return copy
        }
        copy.id = "\(diaId)_bloque_\(blockIndex)_\(RoutineIdGenerator.generateId())"
        return copy
    }
}

// MARK: - Validación

public enum RoutineValidator {
    public static func validateRutina(_ rutina: RutinaData) -> RoutineValidationResult {
        var errors: [String] = []

        if rutina.usuario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("El campo 'usuario' debe ser una cadena no vacia.")
        }

        if rutina.edad < 1 || rutina.edad > RoutineValidationRules.maxEdad {
            errors.append("El campo 'edad' debe ser un entero entre 1 y \(RoutineValidationRules.maxEdad).")
        }

        let objetivo = rutina.objetivo.trimmingCharacters(in: .whitespacesAndNewlines)
        if objetivo.isEmpty {
            errors.append("El campo 'objetivo' debe ser una cadena no vacia.")
        } else if rutina.objetivo.count > RoutineValidationRules.maxLenObjetivo {
            errors.append("El campo 'objetivo' no puede superar \(RoutineValidationRules.maxLenObjetivo) caracteres.")
        }

        if rutina.diasEntrenamiento.isEmpty {
            errors.append("La rutina debe tener al menos un dia de entrenamiento.")
        } else if rutina.diasEntrenamiento.count > RoutineValidationRules.maxDias {
            errors.append("La rutina no puede tener mas de \(RoutineValidationRules.maxDias) dias de entrenamiento.")
        }

        var diaIds = Set<String>()
        for (dIdx, dia) in rutina.diasEntrenamiento.enumerated() {
            validateDia(dia, index: dIdx, diaIds: &diaIds, errors: &errors)
        }

        return RoutineValidationResult(isValid: errors.isEmpty, errors: errors)
    }

    private static func validateDia(
        _ dia: DiaEntrenamiento,
        index: Int,
        diaIds: inout Set<String>,
        errors: inout [String]
    ) {
        let prefix = "Dia \(index + 1)"

        let id = dia.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty {
            errors.append(prefix + ": el campo 'id' debe ser una cadena no vacia.")
        } else if dia.id.count > RoutineValidationRules.maxLenId {
            errors.append(prefix + ": el 'id' no puede superar \(RoutineValidationRules.maxLenId) caracteres.")
        } else if diaIds.contains(dia.id) {
            errors.append(prefix + ": el id '\(dia.id)' esta duplicado.")
        } else {
            diaIds.insert(dia.id)
        }

        if dia.nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(prefix + ": el campo 'nombre' debe ser una cadena no vacia.")
        } else if dia.nombre.count > RoutineValidationRules.maxLenNombre {
            errors.append(prefix + ": 'nombre' no puede superar \(RoutineValidationRules.maxLenNombre) caracteres.")
        }

        if dia.ubicacion.count > RoutineValidationRules.maxLenNombre {
            errors.append(prefix + ": 'ubicacion' no puede superar \(RoutineValidationRules.maxLenNombre) caracteres.")
        }

        if dia.calentamiento.count > RoutineValidationRules.maxLenTextoLargo {
            errors.append(prefix + ": 'calentamiento' no puede superar \(RoutineValidationRules.maxLenTextoLargo) caracteres.")
        }

        if let calMin = dia.calentamientoMinutos {
            if calMin < 0 || calMin > RoutineValidationRules.maxDuracionMin {
                errors.append(prefix + ": 'calentamiento_minutos' debe ser un entero entre 0 y \(RoutineValidationRules.maxDuracionMin) (recibido: \(calMin)).")
            }
        }

        if dia.bloques.isEmpty {
            errors.append(prefix + ": debe tener al menos un bloque.")
        } else if dia.bloques.count > RoutineValidationRules.maxBloquesPorDia {
            errors.append(prefix + ": no puede tener mas de \(RoutineValidationRules.maxBloquesPorDia) bloques.")
        }

        for (bIdx, bloque) in dia.bloques.enumerated() {
            validateBloque(bloque, prefix: prefix + " - Bloque \(bIdx + 1)", errors: &errors)
        }
    }

    private static func validateBloque(_ bloque: Bloque, prefix: String, errors: inout [String]) {
        if bloque.nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(prefix + ": el campo 'nombre' debe ser una cadena no vacia.")
        } else if bloque.nombre.count > RoutineValidationRules.maxLenNombre {
            errors.append(prefix + ": 'nombre' no puede superar \(RoutineValidationRules.maxLenNombre) caracteres.")
        }

        if let id = bloque.id {
            if id.isEmpty {
                errors.append(prefix + ": el campo 'id' debe ser una cadena no vacia si esta presente.")
            } else if id.count > RoutineValidationRules.maxLenId {
                errors.append(prefix + ": 'id' no puede superar \(RoutineValidationRules.maxLenId) caracteres.")
            }
        }

        validateOptionalInt(bloque.duracionMinutos, label: prefix + ": 'duracion_minutos'", min: 1, max: RoutineValidationRules.maxDuracionMin, errors: &errors)
        validateOptionalInt(bloque.capMinutos, label: prefix + ": 'cap_minutos'", min: 1, max: RoutineValidationRules.maxCapMin, errors: &errors)
        validateOptionalInt(bloque.rondas, label: prefix + ": 'rondas'", min: 1, max: RoutineValidationRules.maxRondas, errors: &errors)
        validateOptionalInt(bloque.descansoSeg, label: prefix + ": 'descanso_seg'", min: 0, max: RoutineValidationRules.maxSeg, errors: &errors)
        validateOptionalInt(bloque.trabajoSeg, label: prefix + ": 'trabajo_seg'", min: 1, max: RoutineValidationRules.maxSeg, errors: &errors)
        validateOptionalInt(bloque.descansoTabataSeg, label: prefix + ": 'descanso_tabata_seg'", min: 1, max: RoutineValidationRules.maxSeg, errors: &errors)

        if bloque.ejercicios.count > RoutineValidationRules.maxEjerciciosPorBloque {
            errors.append(prefix + ": no puede tener mas de \(RoutineValidationRules.maxEjerciciosPorBloque) ejercicios.")
        }

        for (eIdx, ej) in bloque.ejercicios.enumerated() {
            validateEjercicio(ej, prefix: prefix + " - Ejercicio \(eIdx + 1)", errors: &errors)
        }
    }

    private static func validateEjercicio(_ ej: Ejercicio, prefix: String, errors: inout [String]) {
        if ej.detalle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(prefix + ": el campo 'detalle' debe ser una cadena no vacia.")
        } else if ej.detalle.count > RoutineValidationRules.maxLenTextoLargo {
            errors.append(prefix + ": 'detalle' no puede superar \(RoutineValidationRules.maxLenTextoLargo) caracteres.")
        }

        if let seg = ej.segundos {
            validateOptionalInt(seg, label: prefix + ": 'segundos'", min: 1, max: RoutineValidationRules.maxSeg, errors: &errors)
        }

        if let min = ej.minuto {
            validateOptionalInt(min, label: prefix + ": 'minuto'", min: 1, max: 60, errors: &errors)
        }
    }

    private static func validateOptionalInt(
        _ value: Int?,
        label: String,
        min: Int,
        max: Int,
        errors: inout [String]
    ) {
        guard let value else { return }
        if value < min || value > max {
            errors.append(label + " debe ser un entero entre \(min) y \(max) (recibido: \(value)).")
        }
    }
}
