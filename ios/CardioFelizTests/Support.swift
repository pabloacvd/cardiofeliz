import XCTest

/// Los fuentes del dominio y del motor se compilan dentro de este mismo bundle de tests,
/// por lo que no hay módulo que importar.

private final class BundleToken {}

enum Fixtures {
    /// Copia literal de `src/data/rutina.json` (la rutina por defecto de la PWA).
    static func rutinaData() throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        let url = try XCTUnwrap(bundle.url(forResource: "rutina", withExtension: "json"), "Falta rutina.json en el bundle de tests")
        return try Data(contentsOf: url)
    }

    static func defaultRoutine() throws -> RutinaData {
        try JSONDecoder().decode(RutinaData.self, from: rutinaData())
    }

    static func bloque(_ diaId: String, _ bloqueId: String) throws -> Bloque {
        let rutina = try defaultRoutine()
        let dia = try XCTUnwrap(rutina.diasEntrenamiento.first { $0.id == diaId })
        return try XCTUnwrap(dia.bloques.first { $0.id == bloqueId })
    }
}

func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

/// Instante fijo para tests deterministas.
let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

extension Date {
    func plus(_ seconds: TimeInterval) -> Date { addingTimeInterval(seconds) }
}
