import Foundation

/// Protocolo de abstracción para obtener la rutina de entrenamiento vigente.
/// En la sub-tarea 4 devuelve la rutina empaquetada por defecto (`rutina.json`).
/// En la sub-tarea 7 permitirá alternar entre rutina empaquetada y rutina remota/personalizada.
public protocol RoutineProvider: Sendable {
    func loadRoutine() throws -> RutinaData
}

/// Proveedor que lee la rutina por defecto empaquetada en el bundle de la app o de recursos.
public struct BundledRoutineProvider: RoutineProvider {
    private let customData: Data?

    public init(data: Data? = nil) {
        self.customData = data
    }

    public func loadRoutine() throws -> RutinaData {
        if let data = customData {
            return try JSONDecoder().decode(RutinaData.self, from: data)
        }

        if let url = Bundle.main.url(forResource: "rutina", withExtension: "json") {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(RutinaData.self, from: data)
        }

        // Búsqueda en todos los bundles (p. ej. bundle de tests)
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: "rutina", withExtension: "json") {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(RutinaData.self, from: data)
            }
        }

        throw RoutineProviderError.bundledRoutineNotFound
    }
}

public enum RoutineProviderError: Error, LocalizedError, Sendable {
    case bundledRoutineNotFound

    public var errorDescription: String? {
        switch self {
        case .bundledRoutineNotFound:
            return "No se encontró el archivo de rutina por defecto (rutina.json)."
        }
    }
}
