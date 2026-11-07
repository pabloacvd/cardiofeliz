import Foundation

// Este archivo se compila también en el target watchOS: solo Foundation, sin dependencias de iOS.

/// Tipo de fase. Es semántico (qué es la fase), no visual. `isManual` es independiente:
/// una fase manual (sin cuenta regresiva, avanza con "Listo"/"Siguiente") es de tipo `.work`.
public enum PhaseKind: String, Codable, Hashable {
    case warmup
    case work
    case rest
    /// Resto de un paso Finisher/HIIT dividido por `trabajo_seg`.
    case transition
}

/// Sonido de aviso al empezar una fase. Equivale a `playGo` / `playRest` de `useAudioBeeps.ts`.
public enum SoundCue: String, Codable, Hashable {
    case none
    case go
    case rest
}

public struct WorkoutPhase: Codable, Identifiable, Hashable {
    /// Único dentro de un plan. El prototipo usaba `name`, pero Tabata repite "Trabajo"/"Descanso".
    public var id: String { "\(order)-\(name)" }

    /// Etiqueta corta de la fase (título en Live Activity y Watch). Ej.: "Minuto 3", "Trabajo", "Descanso".
    public let name: String
    /// Segundos. 0 en fases manuales (no tienen fin conocido).
    public let duration: TimeInterval
    public let order: Int

    public let kind: PhaseKind
    /// Texto del ejercicio de la fase, si lo hay.
    public let detail: String?
    /// Ronda 1-based, si el bloque tiene rondas.
    public let round: Int?
    public let totalRounds: Int?
    /// Índice 0-based del ejercicio dentro de la ronda.
    public let exerciseIndex: Int?
    /// Sin cuenta regresiva: avanza cuando el usuario lo indica.
    public let isManual: Bool
    public let startCue: SoundCue
    /// Segundos restantes por debajo de los cuales la PWA marca "poco tiempo" (solo AMRAP: 60).
    public let lowTimeWarning: TimeInterval?
    /// La pantalla muestra el tiempo transcurrido en vez del restante (FOR_TIME). `duration` es el tope.
    public let countsUp: Bool

    public init(
        name: String,
        duration: TimeInterval,
        order: Int,
        kind: PhaseKind = .work,
        detail: String? = nil,
        round: Int? = nil,
        totalRounds: Int? = nil,
        exerciseIndex: Int? = nil,
        isManual: Bool = false,
        startCue: SoundCue = .go,
        lowTimeWarning: TimeInterval? = nil,
        countsUp: Bool = false
    ) {
        self.name = name
        self.duration = duration
        self.order = order
        self.kind = kind
        self.detail = detail
        self.round = round
        self.totalRounds = totalRounds
        self.exerciseIndex = exerciseIndex
        self.isManual = isManual
        self.startCue = startCue
        self.lowTimeWarning = lowTimeWarning
        self.countsUp = countsUp
    }

    enum CodingKeys: String, CodingKey {
        case name, duration, order, kind, detail, round, totalRounds, exerciseIndex, isManual, startCue, lowTimeWarning, countsUp
    }

    /// Tolerante: un payload del prototipo (solo `name`, `duration`, `order`) sigue decodificando.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.duration = try c.decode(TimeInterval.self, forKey: .duration)
        self.order = try c.decode(Int.self, forKey: .order)
        self.kind = try c.decodeIfPresent(PhaseKind.self, forKey: .kind) ?? .work
        self.detail = try c.decodeIfPresent(String.self, forKey: .detail)
        self.round = try c.decodeIfPresent(Int.self, forKey: .round)
        self.totalRounds = try c.decodeIfPresent(Int.self, forKey: .totalRounds)
        self.exerciseIndex = try c.decodeIfPresent(Int.self, forKey: .exerciseIndex)
        self.isManual = try c.decodeIfPresent(Bool.self, forKey: .isManual) ?? false
        self.startCue = try c.decodeIfPresent(SoundCue.self, forKey: .startCue) ?? .go
        self.lowTimeWarning = try c.decodeIfPresent(TimeInterval.self, forKey: .lowTimeWarning)
        self.countsUp = try c.decodeIfPresent(Bool.self, forKey: .countsUp) ?? false
    }
}
