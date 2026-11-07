import Foundation

// Port de `src/utils/timerConfig.ts`. Defaults y validación idénticos: un valor ausente,
// no entero o no positivo (según el campo) se descarta y cae al default histórico.

public enum TimerDefaults {
    public static let triserieRounds = 4
    public static let triserieRestSeconds = 45
    public static let tabataRounds = 8
    public static let tabataWorkSeconds = 20
    public static let tabataRestSeconds = 10
    public static let finisherRounds = 3
    /// Duración de un paso de descanso del Finisher/HIIT que no define `segundos`.
    public static let finisherRestSeconds = 30
    /// Peso (en segundos) que un paso manual aporta a la barra de progreso.
    public static let manualPhaseWeightSeconds = 30
    /// AMRAP y FOR_TIME usan 15 min si el bloque no define duración válida (`|| 15` en la PWA).
    public static let defaultCapMinutes = 15
}

public struct TriserieConfig: Equatable {
    public let rounds: Int
    public let restSeconds: Int
}

public struct TabataConfig: Equatable {
    public let rounds: Int
    public let workSeconds: Int
    public let restSeconds: Int
}

public enum FinisherStepKind: String, Equatable {
    case work
    case transition
    case rest
    case manual
}

public struct FinisherStep: Equatable {
    public let kind: FinisherStepKind
    /// Ronda 1-based.
    public let round: Int
    /// Índice 0-based del ejercicio dentro de la ronda.
    public let exerciseIndex: Int
    public let detalle: String
    /// nil en pasos manuales.
    public let seconds: Int?
}

public enum TimerConfig {
    static func positiveInt(_ value: Int?) -> Int? {
        guard let v = value, v > 0 else { return nil }
        return v
    }

    static func nonNegativeInt(_ value: Int?) -> Int? {
        guard let v = value, v >= 0 else { return nil }
        return v
    }

    /// Extrae segundos de textos como "45 seg", "45s" o "1 min". Regex idéntica a la de la PWA:
    /// `/(\d+)\s*(min|m\b)?/i`.
    public static func parseRestSeconds(_ text: String?) -> Int? {
        guard let text else { return nil }
        guard let regex = try? NSRegularExpression(pattern: #"(\d+)\s*(min|m\b)?"#, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let numberRange = Range(match.range(at: 1), in: text),
              let value = Int(text[numberRange]) else { return nil }
        let hasMinutes = match.range(at: 2).location != NSNotFound
        return hasMinutes ? value * 60 : value
    }

    public static func triserieConfig(for bloque: Bloque) -> TriserieConfig {
        TriserieConfig(
            rounds: positiveInt(bloque.rondas) ?? TimerDefaults.triserieRounds,
            restSeconds: nonNegativeInt(bloque.descansoSeg)
                ?? parseRestSeconds(bloque.descansoEntreRondas)
                ?? TimerDefaults.triserieRestSeconds
        )
    }

    public static func tabataConfig(for bloque: Bloque) -> TabataConfig {
        TabataConfig(
            rounds: positiveInt(bloque.rondas) ?? TimerDefaults.tabataRounds,
            workSeconds: positiveInt(bloque.trabajoSeg) ?? TimerDefaults.tabataWorkSeconds,
            restSeconds: positiveInt(bloque.descansoTabataSeg) ?? TimerDefaults.tabataRestSeconds
        )
    }

    public static func finisherRounds(for bloque: Bloque) -> Int {
        positiveInt(bloque.rondas) ?? TimerDefaults.finisherRounds
    }

    /// Secuencia completa de pasos (todas las rondas) de un Finisher o HIIT_INTERVALS.
    public static func finisherSteps(for bloque: Bloque) -> [FinisherStep] {
        let rounds = finisherRounds(for: bloque)
        let trabajoSeg = positiveInt(bloque.trabajoSeg)
        var steps: [FinisherStep] = []

        for round in 1...rounds {
            for (exerciseIndex, ej) in bloque.ejercicios.enumerated() {
                let segundos = positiveInt(ej.segundos)
                func step(_ kind: FinisherStepKind, _ seconds: Int?) -> FinisherStep {
                    FinisherStep(kind: kind, round: round, exerciseIndex: exerciseIndex, detalle: ej.detalle, seconds: seconds)
                }

                if ej.esDescanso {
                    steps.append(step(.rest, segundos ?? TimerDefaults.finisherRestSeconds))
                } else if let segundos {
                    if let trabajoSeg, segundos > trabajoSeg {
                        steps.append(step(.work, trabajoSeg))
                        steps.append(step(.transition, segundos - trabajoSeg))
                    } else {
                        steps.append(step(.work, segundos))
                    }
                } else {
                    steps.append(step(.manual, nil))
                }
            }
        }
        return steps
    }

    /// Duración total en segundos; nil si hay pasos manuales (duración desconocida).
    public static func finisherTotalSeconds(_ steps: [FinisherStep]) -> Int? {
        var total = 0
        for s in steps {
            guard let sec = s.seconds else { return nil }
            total += sec
        }
        return total
    }
}
