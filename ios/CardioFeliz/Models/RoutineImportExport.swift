import Foundation

// MARK: - Importación, exportación y comparación (espejo de `src/utils/routineImport.ts`)

public enum RoutineImportResult: Equatable, Sendable {
    case success(RutinaData)
    case failure([String])
}

public enum RoutineImportExport {
    public static let maxImportSizeBytes = 500 * 1024 // 500 KB

    public static func parseImportedRoutine(text: String, usuario: String) -> RoutineImportResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failure(["El archivo o texto esta vacio."])
        }

        if text.utf8.count > maxImportSizeBytes {
            return .failure(["El archivo o texto supera el tamano maximo permitido (500 KB)."])
        }

        guard let data = text.data(using: .utf8) else {
            return .failure(["El archivo no tiene una codificacion de texto valida (UTF-8)."])
        }

        let decoded: RutinaData
        do {
            decoded = try JSONDecoder().decode(RutinaData.self, from: data)
        } catch {
            return .failure(["El archivo no es un JSON valido o la estructura no corresponde a una rutina."])
        }

        let effectiveUser = usuario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Usuario" : usuario
        var dataWithUser = decoded
        dataWithUser.usuario = effectiveUser

        let validation = RoutineValidator.validateRutina(dataWithUser)
        if !validation.isValid {
            return .failure(validation.errors)
        }

        let normalized = RoutineNormalizer.normalizeRutina(dataWithUser)
        return .success(normalized)
    }

    public static func serializeRoutine(_ rutina: RutinaData) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(rutina)
        guard let string = String(data: data, encoding: .utf8) else {
            throw DataLayerError.invalidInput
        }
        return string
    }

    public static func isDefaultRoutine(
        _ rutina: RutinaData,
        bundledProvider: RoutineProvider = BundledRoutineProvider()
    ) -> Bool {
        guard let defaultRoutine = try? bundledProvider.loadRoutine() else {
            return false
        }
        let normalized = RoutineNormalizer.normalizeRutina(rutina)
        let normalizedDefault = RoutineNormalizer.normalizeRutina(defaultRoutine)

        var a = normalized
        a.usuario = ""
        var b = normalizedDefault
        b.usuario = ""

        return a == b
    }
}
