import Foundation

// Calcula las notificaciones locales de respaldo de un entrenamiento. Puro (solo Foundation).
//
// Las notificaciones son el plan B para cuando la app no puede seguir viva en segundo plano.
// Para no duplicar el aviso cuando sí sigue viva (el audio ya sonó), cada notificación se
// programa `backupGrace` segundos después del cambio de fase y la app la cancela al procesar
// el cambio (`NotificationManager.cancel(identifiers:)`). Si la app está suspendida nadie la
// cancela y el aviso llega con ese pequeño retraso.

public struct PlannedNotification: Equatable {
    public let identifier: String
    public let title: String
    public let body: String
    public let fireDate: Date
}

public enum NotificationPlanner {
    /// iOS conserva como máximo 64 notificaciones locales pendientes por app.
    public static let maxPending = 60
    /// Retraso del aviso de respaldo respecto del cambio real de fase.
    public static let backupGrace: TimeInterval = 1.5
    public static let completionIdentifier = "cf_workout_finished"

    public static func phaseStartIdentifier(_ index: Int) -> String { "cf_phase_start_\(index)" }

    /// - Parameter notifyCompletion: con `false` no se agenda el aviso de fin (el último `endDate`
    ///   recibido no es el fin real, p. ej. cuando el bloque tiene pasos manuales por delante).
    public static func plan(
        phases: [WorkoutPhase],
        startDates: [Date],
        endDates: [Date],
        notifyCompletion: Bool,
        now: Date
    ) -> [PlannedNotification] {
        guard phases.count == startDates.count, phases.count == endDates.count else { return [] }

        var result: [PlannedNotification] = []

        // El inicio de la fase 0 no se notifica: arranca de inmediato con la app abierta.
        for i in phases.indices where i > 0 {
            let fire = startDates[i].addingTimeInterval(backupGrace)
            guard fire > now else { continue }
            result.append(PlannedNotification(
                identifier: phaseStartIdentifier(i),
                title: "Nueva fase: \(phases[i].name)",
                body: "Fase \(i + 1) de \(phases.count). ¡Sigue así!",
                fireDate: fire
            ))
        }

        if notifyCompletion, let lastEnd = endDates.last {
            let fire = lastEnd.addingTimeInterval(backupGrace)
            if fire > now {
                result.append(PlannedNotification(
                    identifier: completionIdentifier,
                    title: "¡Entrenamiento Completado!",
                    body: "Felicidades, has completado tu entrenamiento de CardioFeliz.",
                    fireDate: fire
                ))
            }
        }

        // Si hay más de las que iOS admite, se conservan las más próximas.
        return Array(result.prefix(maxPending))
    }
}
