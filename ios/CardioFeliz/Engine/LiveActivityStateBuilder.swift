import Foundation

// Arma el estado de la Live Activity a partir del reloj. Se separa de `TimerManager` para poder
// probarlo sin ActivityKit en ejecución.

public enum LiveActivityStateBuilder {
    /// nil si el reloj no está en marcha o en pausa.
    public static func state(for clock: WorkoutClock, now: Date = Date()) -> WorkoutAttributes.ContentState? {
        guard clock.isActive, let phase = clock.currentPhase else { return nil }
        let i = clock.currentIndex
        guard clock.startDates.indices.contains(i), clock.endDates.indices.contains(i) else { return nil }

        let paused = clock.state == .paused
        var frozen: TimeInterval?
        if paused {
            frozen = (phase.isManual || phase.countsUp)
                ? clock.elapsedInCurrentPhase(at: now)
                : clock.timeRemainingInCurrentPhase(at: now)
        }

        return WorkoutAttributes.ContentState(
            phaseName: phase.name,
            detail: phase.detail,
            phaseOrder: i,
            totalPhases: clock.plan.phases.count,
            currentPhaseStartDate: clock.startDates[i],
            currentPhaseEndDate: clock.endDates[i],
            isPaused: paused,
            isManual: phase.isManual,
            countsUp: phase.countsUp,
            frozenSeconds: frozen
        )
    }

    /// Fecha a partir de la cual el sistema marca la actividad como desactualizada si nadie la
    /// actualizó (la app suspendida no puede avanzar de fase). nil en pausa y en fases manuales,
    /// que no tienen un fin conocido.
    public static func staleDate(for state: WorkoutAttributes.ContentState) -> Date? {
        guard !state.isPaused, !state.isManual else { return nil }
        return state.currentPhaseEndDate.addingTimeInterval(2)
    }
}
