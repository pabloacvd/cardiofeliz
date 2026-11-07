import Foundation

// Convierte un `Bloque` (o el calentamiento de un día) en una lista ordenada de fases.
// Es la traducción de los seis timers de React (`src/components/timers/*`) a datos:
// el motor (`WorkoutClock`) solo conoce fases, no tipos de bloque.
//
// Solo Foundation: lo usan los tests y, a futuro, el Watch.

public struct WorkoutPlan: Codable, Hashable {
    public let title: String
    public let phases: [WorkoutPhase]

    public init(title: String, phases: [WorkoutPhase]) {
        self.title = title
        self.phases = phases
    }

    public var isEmpty: Bool { phases.isEmpty }

    /// Segundos en los que suena el tic de cuenta regresiva antes del fin de una fase con tiempo.
    /// La PWA pita cuando quedan 3, 2 y 1 segundos (`useAudioBeeps.playCountdown`).
    public static let countdownTickSeconds: [Int] = [3, 2, 1]

    /// Duración total planificada. nil si hay fases manuales (duración desconocida).
    public var plannedDuration: TimeInterval? {
        var total: TimeInterval = 0
        for p in phases {
            if p.isManual { return nil }
            total += p.duration
        }
        return total
    }

    /// Plan de 3 fases de 20 s del prototipo de la Fase 0.
    public static let prototype = WorkoutPlan(title: "CardioFeliz Prototipo", phases: [
        WorkoutPhase(name: "Calentamiento", duration: 20, order: 0, kind: .warmup),
        WorkoutPhase(name: "Esfuerzo", duration: 20, order: 1, kind: .work),
        WorkoutPhase(name: "Descanso", duration: 20, order: 2, kind: .rest, startCue: .rest),
    ])
}

// MARK: - Calentamiento

extension WorkoutPlan {
    /// Una sola fase con cuenta regresiva (`WarmupView`). nil si el día no define minutos > 0.
    /// No suena al empezar; solo tics al final y el aviso de fin lo da el motor.
    public static func warmup(for dia: DiaEntrenamiento) -> WorkoutPlan? {
        guard let minutes = TimerConfig.positiveInt(dia.calentamientoMinutos) else { return nil }
        let phase = WorkoutPhase(
            name: "Calentamiento",
            duration: TimeInterval(minutes * 60),
            order: 0,
            kind: .warmup,
            detail: dia.calentamiento.isEmpty ? nil : dia.calentamiento,
            startCue: .none
        )
        return WorkoutPlan(title: "Calentamiento", phases: [phase])
    }
}

// MARK: - Bloques

extension WorkoutPlan {
    public init(bloque: Bloque) {
        var b = PlanBuilder()
        switch bloque.tipo {
        case .emom: Self.buildEmom(bloque, &b)
        case .amrap: Self.buildAmrap(bloque, &b)
        case .forTime: Self.buildForTime(bloque, &b)
        case .tabata: Self.buildTabata(bloque, &b)
        case .triserie, .density: Self.buildTriserie(bloque, &b)
        case .finisher, .hiitIntervals: Self.buildFinisher(bloque, &b)
        }
        self.init(title: bloque.nombre, phases: b.phases)
    }

    // EMOM: un minuto por fase. El ejercicio se elige por posición `(minuto-1) % n`, NO por el campo
    // `minuto` del JSON (igual que `EmomTimer`). Sin `duracion_minutos` válido no hay plan
    // (la PWA mostraría NaN).
    private static func buildEmom(_ bloque: Bloque, _ b: inout PlanBuilder) {
        guard let minutes = TimerConfig.positiveInt(bloque.duracionMinutos) else { return }
        let n = bloque.ejercicios.count
        let denom = max(n, 1)
        let totalRounds = Int((Double(minutes) / Double(denom)).rounded(.up))

        for m in 1...minutes {
            let idx = (m - 1) % denom
            let ejercicio = n > 0 ? bloque.ejercicios[idx] : nil
            b.add(
                name: "Minuto \(m)",
                duration: 60,
                kind: ejercicio?.esDescanso == true ? .rest : .work,
                detail: ejercicio?.detalle ?? "Ejercicio activo",
                round: (m - 1) / denom + 1,
                totalRounds: totalRounds,
                exerciseIndex: idx,
                cue: .go
            )
        }
    }

    // AMRAP: una fase con el tiempo total. `duracion_minutos || 15` en la PWA. Los últimos 60 s
    // se marcan como "poco tiempo". El conteo de rondas es estado de UI, no del motor.
    private static func buildAmrap(_ bloque: Bloque, _ b: inout PlanBuilder) {
        let minutes = TimerConfig.positiveInt(bloque.duracionMinutos) ?? TimerDefaults.defaultCapMinutes
        b.add(name: "AMRAP", duration: TimeInterval(minutes * 60), kind: .work, cue: .go, lowTimeWarning: 60)
    }

    // FOR_TIME: una fase que cuenta hacia arriba hasta el tope `cap_minutos || 15`.
    private static func buildForTime(_ bloque: Bloque, _ b: inout PlanBuilder) {
        let minutes = TimerConfig.positiveInt(bloque.capMinutos) ?? TimerDefaults.defaultCapMinutes
        b.add(name: "For Time", duration: TimeInterval(minutes * 60), kind: .work, cue: .go, countsUp: true)
    }

    // TABATA: trabajo/descanso alternados. Tras el último trabajo NO hay descanso: el bloque termina.
    // Por eso dura rondas*trabajo + (rondas-1)*descanso, no `rondas*ciclo` como dice la etiqueta de la PWA.
    private static func buildTabata(_ bloque: Bloque, _ b: inout PlanBuilder) {
        let cfg = TimerConfig.tabataConfig(for: bloque)
        let detail = bloque.ejercicios.first?.detalle ?? "Trabajo por intervalos"
        for round in 1...cfg.rounds {
            b.add(name: "Trabajo", duration: TimeInterval(cfg.workSeconds), kind: .work, detail: detail,
                  round: round, totalRounds: cfg.rounds, cue: .go)
            if round < cfg.rounds {
                b.add(name: "Descanso", duration: TimeInterval(cfg.restSeconds), kind: .rest, detail: detail,
                      round: round, totalRounds: cfg.rounds, cue: .rest)
            }
        }
    }

    // TRISERIE / DENSITY: cada ejercicio es manual (el usuario toca "siguiente"). Entre rondas hay un
    // descanso con cuenta regresiva (omitido si vale 0) y no hay descanso tras la última ronda.
    private static func buildTriserie(_ bloque: Bloque, _ b: inout PlanBuilder) {
        guard !bloque.ejercicios.isEmpty else { return }
        let cfg = TimerConfig.triserieConfig(for: bloque)
        for round in 1...cfg.rounds {
            for (i, ej) in bloque.ejercicios.enumerated() {
                b.add(name: "Ejercicio \(i + 1)", duration: 0, kind: .work, detail: ej.detalle,
                      round: round, totalRounds: cfg.rounds, exerciseIndex: i, manual: true, cue: .go)
            }
            if round < cfg.rounds, cfg.restSeconds > 0 {
                b.add(name: "Descanso", duration: TimeInterval(cfg.restSeconds), kind: .rest,
                      detail: "Descanso entre rondas", round: round, totalRounds: cfg.rounds, cue: .rest)
            }
        }
    }

    // FINISHER / HIIT_INTERVALS: pasos de `TimerConfig.finisherSteps`.
    private static func buildFinisher(_ bloque: Bloque, _ b: inout PlanBuilder) {
        let rounds = TimerConfig.finisherRounds(for: bloque)
        for step in TimerConfig.finisherSteps(for: bloque) {
            let common: (String, PhaseKind, SoundCue, Bool) = {
                switch step.kind {
                case .work: return ("Intervalo", .work, .go, false)
                case .manual: return ("Ejercicio \(step.exerciseIndex + 1)", .work, .go, true)
                case .transition: return ("Transición", .transition, .rest, false)
                case .rest: return ("Descanso", .rest, .rest, false)
                }
            }()
            b.add(name: common.0, duration: TimeInterval(step.seconds ?? 0), kind: common.1, detail: step.detalle,
                  round: step.round, totalRounds: rounds, exerciseIndex: step.exerciseIndex,
                  manual: common.3, cue: common.2)
        }
    }
}

// MARK: - Builder

private struct PlanBuilder {
    var phases: [WorkoutPhase] = []

    mutating func add(
        name: String,
        duration: TimeInterval,
        kind: PhaseKind,
        detail: String? = nil,
        round: Int? = nil,
        totalRounds: Int? = nil,
        exerciseIndex: Int? = nil,
        manual: Bool = false,
        cue: SoundCue,
        lowTimeWarning: TimeInterval? = nil,
        countsUp: Bool = false
    ) {
        phases.append(WorkoutPhase(
            name: name, duration: duration, order: phases.count, kind: kind, detail: detail,
            round: round, totalRounds: totalRounds, exerciseIndex: exerciseIndex, isManual: manual,
            startCue: cue, lowTimeWarning: lowTimeWarning, countsUp: countsUp
        ))
    }
}
