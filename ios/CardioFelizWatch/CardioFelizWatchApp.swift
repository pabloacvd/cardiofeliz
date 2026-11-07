import SwiftUI

@main
struct CardioFelizWatchApp: App {
    init() {
        // Activar WatchConnectivity y el gestor desde el arranque: el contexto del iPhone puede esperar ya.
        PhoneConnector.activate()
        _ = WorkoutManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
