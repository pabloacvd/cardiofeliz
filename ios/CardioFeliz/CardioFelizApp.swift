import SwiftUI

@main
struct CardioFelizApp: App {
    @StateObject private var env = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Los resúmenes del Watch pueden llegar con la app cerrada: activar WatchConnectivity desde el arranque.
        WatchConnector.activate()
        // Un cierre forzado durante un entrenamiento deja la Live Activity y los avisos pendientes.
        // Al lanzar no hay ningún entrenamiento en memoria, así que son huérfanos.
        TimerManager.endOrphanedLiveActivities()
        NotificationManager.shared.cancelAllNotifications()
    }

    var body: some Scene {
        WindowGroup {
            RootView(env: env)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                env.appBecameActive()
                SoundManager.shared.recoverIfNeeded()
            }
        }
    }
}
