import Foundation

// Modelos de la rutina. Espejo de `src/types/workout.ts`.
// El JSON vive en `cf_routines.data` (jsonb) y usa claves en español.
// La decodificación es tolerante: los campos opcionales ausentes (o con tipo
// incorrecto) quedan en nil, igual que en la PWA, donde `getTriserieConfig`,
// `getTabataConfig` y `getFinisherRounds` validan cada valor con `positiveInt`.

// MARK: - Tipo de bloque

public enum TipoBloque: String, Codable, CaseIterable, Hashable, Sendable {
    case emom = "EMOM"
    case amrap = "AMRAP"
    case triserie = "TRISERIE"
    case density = "DENSITY"
    case forTime = "FOR_TIME"
    case tabata = "TABATA"
    case finisher = "FINISHER"
    case hiitIntervals = "HIIT_INTERVALS"
}

// MARK: - Ejercicio

/// Unifica `EjercicioEMOM` (con `minuto`) y `EjercicioGenerico` (con `segundos` opcional).
/// En el JSON real un EMOM solo trae `minuto`; el resto solo trae `segundos` o nada.
public struct Ejercicio: Codable, Hashable, Sendable {
    public var detalle: String
    /// Solo ejercicios EMOM.
    public var minuto: Int?
    /// Duración para pasos con temporizador automático (Finisher/HIIT).
    public var segundos: Int?

    public init(detalle: String, minuto: Int? = nil, segundos: Int? = nil) {
        self.detalle = detalle
        self.minuto = minuto
        self.segundos = segundos
    }

    enum CodingKeys: String, CodingKey {
        case detalle, minuto, segundos
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.detalle = try c.decodeIfPresent(String.self, forKey: .detalle) ?? ""
        self.minuto = c.lenientInt(.minuto)
        self.segundos = c.lenientInt(.segundos)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(detalle, forKey: .detalle)
        try c.encodeIfPresent(minuto, forKey: .minuto)
        try c.encodeIfPresent(segundos, forKey: .segundos)
    }

    /// Equivalente a `isRestExercise` de `timerConfig.ts`.
    public var esDescanso: Bool {
        detalle.lowercased().contains("descanso")
    }
}

// MARK: - Bloque

/// Un único struct con `tipo` como discriminador. La PWA modela los 8 tipos como
/// `BloqueBase` con campos opcionales; mantener la misma forma plana garantiza
/// que lo que se decodifica se vuelve a codificar sin perder campos.
public struct Bloque: Codable, Hashable, Identifiable, Sendable {
    public var id: String?
    public var tipo: TipoBloque
    public var nombre: String
    public var duracionMinutos: Int?
    public var capMinutos: Int?
    public var descansoEntreRondas: String?
    public var estructura: String?
    public var rondas: Int?
    public var descansoSeg: Int?
    public var trabajoSeg: Int?
    public var descansoTabataSeg: Int?
    public var ejercicios: [Ejercicio]

    public init(
        id: String? = nil,
        tipo: TipoBloque,
        nombre: String,
        duracionMinutos: Int? = nil,
        capMinutos: Int? = nil,
        descansoEntreRondas: String? = nil,
        estructura: String? = nil,
        rondas: Int? = nil,
        descansoSeg: Int? = nil,
        trabajoSeg: Int? = nil,
        descansoTabataSeg: Int? = nil,
        ejercicios: [Ejercicio] = []
    ) {
        self.id = id
        self.tipo = tipo
        self.nombre = nombre
        self.duracionMinutos = duracionMinutos
        self.capMinutos = capMinutos
        self.descansoEntreRondas = descansoEntreRondas
        self.estructura = estructura
        self.rondas = rondas
        self.descansoSeg = descansoSeg
        self.trabajoSeg = trabajoSeg
        self.descansoTabataSeg = descansoTabataSeg
        self.ejercicios = ejercicios
    }

    enum CodingKeys: String, CodingKey {
        case id, tipo, nombre, estructura, rondas, ejercicios
        case duracionMinutos = "duracion_minutos"
        case capMinutos = "cap_minutos"
        case descansoEntreRondas = "descanso_entre_rondas"
        case descansoSeg = "descanso_seg"
        case trabajoSeg = "trabajo_seg"
        case descansoTabataSeg = "descanso_tabata_seg"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id)
        // `tipo` es obligatorio: sin él no se puede elegir temporizador. Un tipo desconocido falla.
        self.tipo = try c.decode(TipoBloque.self, forKey: .tipo)
        self.nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        self.duracionMinutos = c.lenientInt(.duracionMinutos)
        self.capMinutos = c.lenientInt(.capMinutos)
        self.descansoEntreRondas = try? c.decodeIfPresent(String.self, forKey: .descansoEntreRondas)
        self.estructura = try? c.decodeIfPresent(String.self, forKey: .estructura)
        self.rondas = c.lenientInt(.rondas)
        self.descansoSeg = c.lenientInt(.descansoSeg)
        self.trabajoSeg = c.lenientInt(.trabajoSeg)
        self.descansoTabataSeg = c.lenientInt(.descansoTabataSeg)
        self.ejercicios = try c.decodeIfPresent([Ejercicio].self, forKey: .ejercicios) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encode(tipo, forKey: .tipo)
        try c.encode(nombre, forKey: .nombre)
        try c.encodeIfPresent(duracionMinutos, forKey: .duracionMinutos)
        try c.encodeIfPresent(capMinutos, forKey: .capMinutos)
        try c.encodeIfPresent(descansoEntreRondas, forKey: .descansoEntreRondas)
        try c.encodeIfPresent(estructura, forKey: .estructura)
        try c.encodeIfPresent(rondas, forKey: .rondas)
        try c.encodeIfPresent(descansoSeg, forKey: .descansoSeg)
        try c.encodeIfPresent(trabajoSeg, forKey: .trabajoSeg)
        try c.encodeIfPresent(descansoTabataSeg, forKey: .descansoTabataSeg)
        try c.encode(ejercicios, forKey: .ejercicios)
    }
}

// MARK: - Día y rutina

public struct DiaEntrenamiento: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var nombre: String
    public var ubicacion: String
    public var calentamiento: String
    /// Duración del calentamiento en minutos. Si es > 0 hay temporizador.
    public var calentamientoMinutos: Int?
    public var bloques: [Bloque]

    public init(
        id: String,
        nombre: String,
        ubicacion: String = "",
        calentamiento: String = "",
        calentamientoMinutos: Int? = nil,
        bloques: [Bloque] = []
    ) {
        self.id = id
        self.nombre = nombre
        self.ubicacion = ubicacion
        self.calentamiento = calentamiento
        self.calentamientoMinutos = calentamientoMinutos
        self.bloques = bloques
    }

    enum CodingKeys: String, CodingKey {
        case id, nombre, ubicacion, calentamiento, bloques
        case calentamientoMinutos = "calentamiento_minutos"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        self.ubicacion = try c.decodeIfPresent(String.self, forKey: .ubicacion) ?? ""
        self.calentamiento = try c.decodeIfPresent(String.self, forKey: .calentamiento) ?? ""
        self.calentamientoMinutos = c.lenientInt(.calentamientoMinutos)
        self.bloques = try c.decodeIfPresent([Bloque].self, forKey: .bloques) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(nombre, forKey: .nombre)
        try c.encode(ubicacion, forKey: .ubicacion)
        try c.encode(calentamiento, forKey: .calentamiento)
        try c.encodeIfPresent(calentamientoMinutos, forKey: .calentamientoMinutos)
        try c.encode(bloques, forKey: .bloques)
    }
}

public struct RutinaData: Codable, Hashable, Sendable {
    public var usuario: String
    public var edad: Int
    public var objetivo: String
    public var diasEntrenamiento: [DiaEntrenamiento]

    public init(usuario: String, edad: Int, objetivo: String, diasEntrenamiento: [DiaEntrenamiento]) {
        self.usuario = usuario
        self.edad = edad
        self.objetivo = objetivo
        self.diasEntrenamiento = diasEntrenamiento
    }

    enum CodingKeys: String, CodingKey {
        case usuario, edad, objetivo
        case diasEntrenamiento = "dias_entrenamiento"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.usuario = try c.decodeIfPresent(String.self, forKey: .usuario) ?? ""
        self.edad = c.lenientInt(.edad) ?? 0
        self.objetivo = try c.decodeIfPresent(String.self, forKey: .objetivo) ?? ""
        self.diasEntrenamiento = try c.decodeIfPresent([DiaEntrenamiento].self, forKey: .diasEntrenamiento) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(usuario, forKey: .usuario)
        try c.encode(edad, forKey: .edad)
        try c.encode(objetivo, forKey: .objetivo)
        try c.encode(diasEntrenamiento, forKey: .diasEntrenamiento)
    }
}

// MARK: - Decodificación tolerante de enteros

extension KeyedDecodingContainer {
    /// Decodifica un entero; devuelve nil si falta, es null o no es un entero válido
    /// (por ejemplo 1.5 o una cadena). Equivale al `positiveInt`/`nonNegativeInt` de la PWA,
    /// que descartan valores inválidos y caen al default.
    func lenientInt(_ key: Key) -> Int? {
        try? decodeIfPresent(Int.self, forKey: key)
    }
}
