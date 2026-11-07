import ActivityKit
import Foundation

// Compartido entre la app y la widget extension. Solo tipos de datos: la lógica que arma el
// estado a partir del reloj vive en `Engine/LiveActivityStateBuilder.swift` (solo la app).

public struct WorkoutAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var phaseName: String
        /// Ejercicio de la fase, si lo hay.
        public var detail: String?
        public var phaseOrder: Int
        public var totalPhases: Int
        public var currentPhaseStartDate: Date
        /// Fin de la fase. En fases manuales vale lo mismo que el inicio (no hay fin conocido).
        public var currentPhaseEndDate: Date
        public var isPaused: Bool
        /// Fase sin cuenta regresiva: avanza cuando el usuario toca "Siguiente".
        public var isManual: Bool
        /// Se muestra el tiempo transcurrido en vez del restante (FOR_TIME).
        public var countsUp: Bool
        /// Segundos a mostrar congelados mientras está en pausa (restante, o transcurrido si la
        /// fase es manual o cuenta hacia arriba). nil si no está en pausa.
        public var frozenSeconds: TimeInterval?

        public init(
            phaseName: String,
            detail: String? = nil,
            phaseOrder: Int,
            totalPhases: Int,
            currentPhaseStartDate: Date,
            currentPhaseEndDate: Date,
            isPaused: Bool,
            isManual: Bool = false,
            countsUp: Bool = false,
            frozenSeconds: TimeInterval? = nil
        ) {
            self.phaseName = phaseName
            self.detail = detail
            self.phaseOrder = phaseOrder
            self.totalPhases = totalPhases
            self.currentPhaseStartDate = currentPhaseStartDate
            self.currentPhaseEndDate = currentPhaseEndDate
            self.isPaused = isPaused
            self.isManual = isManual
            self.countsUp = countsUp
            self.frozenSeconds = frozenSeconds
        }
    }

    public var workoutName: String

    public init(workoutName: String) {
        self.workoutName = workoutName
    }
}
