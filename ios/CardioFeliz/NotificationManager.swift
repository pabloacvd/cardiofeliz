import Foundation
import UserNotifications

/// Avisos locales de respaldo. Ver `NotificationPlanner` para la lógica de cuándo se agenda cada uno.
public class NotificationManager {
    public static let shared = NotificationManager()

    private init() {}

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                AppLog.workout.error("Autorización de notificaciones fallida: \(String(describing: type(of: error)), privacy: .public)")
            } else {
                AppLog.workout.info("Autorización de notificaciones concedida: \(granted, privacy: .public)")
            }
        }
    }

    /// - Parameter notifyCompletion: con `false` no se agenda el aviso de fin (el último `endDate`
    ///   recibido no es el fin real, p. ej. cuando el bloque tiene pasos manuales por delante).
    public func scheduleWorkoutNotifications(phases: [WorkoutPhase], startDates: [Date], endDates: [Date], notifyCompletion: Bool = true) {
        // Cancelar cualquier notificación previamente agendada de CardioFeliz
        cancelAllNotifications()

        let planned = NotificationPlanner.plan(
            phases: phases,
            startDates: startDates,
            endDates: endDates,
            notifyCompletion: notifyCompletion,
            now: Date()
        )
        for item in planned {
            schedule(item)
        }
    }

    public func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Cancela avisos concretos (pendientes y ya entregados). La app lo usa cuando sigue viva y ya
    /// anunció el cambio de fase por sonido, para que la notificación de respaldo no se duplique.
    public func cancel(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func schedule(_ item: PlannedNotification) {
        let interval = item.fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                AppLog.workout.error("No se pudo agendar un aviso: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
    }
}
