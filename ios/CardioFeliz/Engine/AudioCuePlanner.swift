import Foundation

// Calcula, a partir del reloj, qué sonidos deben sonar y en qué instante exacto. Es lo que
// permite programar los tonos con antelación (el motor de audio los emite con precisión de
// muestra) en lugar de depender de que un timer de 10 Hz siga vivo en segundo plano.
//
// Puro: solo Foundation. `SoundManager` lo traduce a buffers de audio.

public enum AudioCueKind: String, Equatable {
    case tick
    case go
    case rest
    case victory
}

public struct ScheduledCue: Equatable {
    public let date: Date
    public let kind: AudioCueKind

    public init(date: Date, kind: AudioCueKind) {
        self.date = date
        self.kind = kind
    }
}

public enum AudioCuePlanner {
    /// Cues futuros (estrictamente posteriores a `now`) en orden cronológico.
    ///
    /// - Solo con el reloj en marcha: en pausa las fechas no son fiables.
    /// - Se planifica hasta la primera fase manual (su inicio sí es fiable, lo fija la fase
    ///   anterior; nada posterior lo es). Si no hay fases manuales por delante se añade el
    ///   sonido de victoria al fin del plan.
    /// - Los tics (3, 2, 1) siguen la misma regla que `WorkoutClock.tick`: solo si el tic es
    ///   menor que la duración de la fase.
    public static func cues(for clock: WorkoutClock, after now: Date) -> [ScheduledCue] {
        guard clock.state == .running else { return [] }
        let phases = clock.plan.phases
        guard clock.currentIndex < phases.count,
              clock.startDates.count == phases.count,
              clock.endDates.count == phases.count else { return [] }

        var result: [ScheduledCue] = []
        var reachedEnd = true

        for i in clock.currentIndex..<phases.count {
            let phase = phases[i]

            if i > clock.currentIndex, let kind = kind(for: phase.startCue) {
                append(kind, at: clock.startDates[i], after: now, to: &result)
            }

            if phase.isManual {
                reachedEnd = false
                break
            }

            for seconds in WorkoutPlan.countdownTickSeconds where Double(seconds) < phase.duration {
                append(.tick, at: clock.endDates[i].addingTimeInterval(-Double(seconds)), after: now, to: &result)
            }
        }

        if reachedEnd, let last = clock.endDates.last {
            append(.victory, at: last, after: now, to: &result)
        }
        return result
    }

    private static func kind(for cue: SoundCue) -> AudioCueKind? {
        switch cue {
        case .go: return .go
        case .rest: return .rest
        case .none: return nil
        }
    }

    private static func append(_ kind: AudioCueKind, at date: Date, after now: Date, to list: inout [ScheduledCue]) {
        guard date > now else { return }
        list.append(ScheduledCue(date: date, kind: kind))
    }
}
