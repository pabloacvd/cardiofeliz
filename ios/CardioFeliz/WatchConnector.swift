import Foundation
import WatchConnectivity

/// Lado iPhone de la comunicación con el Apple Watch. El protocolo está en `WatchProtocol.swift`.
///
/// - Estado del entrenamiento (iPhone → Watch): `updateApplicationContext` (el último gana; lo recibe un
///   Watch que abre la app tarde) y, si el Watch está al alcance, también `sendMessage` (inmediato).
/// - Comandos (Watch → iPhone): solo `sendMessage` con respuesta. Si el iPhone no puede ejecutarlo,
///   contesta `accepted = false`; nada se reentrega más tarde.
/// - Resumen de Salud (Watch → iPhone): `transferUserInfo`, que llega aunque el iPhone no estuviera cerca
///   al terminar.
public final class WatchConnector: NSObject, WCSessionDelegate, ObservableObject {
    public static let shared = WatchConnector()

    @Published public var isWatchReachable = false
    @Published public var isWatchPaired = false
    @Published public var isWatchAppInstalled = false
    @Published public var watchActivationState: WCSessionActivationState = .notActivated

    /// Lo fija el `TimerManager` que tiene el entrenamiento en curso. Devuelve si el comando se aplicó.
    /// Se invoca siempre en el hilo principal.
    public var commandHandler: ((WatchCommand) -> Bool)?

    /// Último estado en curso enviado, para reenviarlo si el Watch se activa o vuelve al alcance a mitad
    /// de sesión.
    private var lastState: WatchWorkoutState?

    /// Tamaño máximo aceptado de un resumen entrante; el real ocupa unos 150 bytes.
    private static let maxSummaryBytes = 4_096

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    /// Activa la sesión desde el arranque de la app, para recibir resúmenes que llegaron con la app cerrada.
    public static func activate() {
        _ = shared
    }

    // MARK: - Envío de estado

    public func send(_ state: WatchWorkoutState) {
        lastState = state.isRunning ? state : nil
        push(state)
    }

    private func push(_ state: WatchWorkoutState) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }

        let payload: [String: Any]
        do {
            payload = [WatchMessageKey.state: try state.encoded()]
        } catch {
            AppLog.workout.error("No se pudo codificar el estado para el Watch: \(ErrorSummary.describe(error), privacy: .public)")
            return
        }

        do {
            try session.updateApplicationContext(payload)
        } catch {
            AppLog.workout.error("updateApplicationContext falló: \(ErrorSummary.describe(error), privacy: .public)")
        }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                AppLog.workout.error("sendMessage al Watch falló: \(ErrorSummary.describe(error), privacy: .public)")
            }
        }
    }

    // MARK: - WCSessionDelegate

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            AppLog.workout.error("Activación de WCSession falló: \(ErrorSummary.describe(error), privacy: .public)")
        }
        DispatchQueue.main.async {
            self.refresh(from: session)
            self.watchActivationState = activationState
            if activationState == .activated, let state = self.lastState {
                self.push(state)
            }
        }
    }

    public func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.refresh(from: session) }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.refresh(from: session)
            if session.isReachable, let state = self.lastState {
                self.push(state)
            }
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        // El usuario cambió de reloj: reactivar para hablar con el nuevo.
        WCSession.default.activate()
    }

    private func refresh(from session: WCSession) {
        isWatchPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isWatchReachable = session.isReachable
    }

    // MARK: - Recepción

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let raw = message[WatchMessageKey.command] as? String, let command = WatchCommand(rawValue: raw) else {
            replyHandler([WatchMessageKey.accepted: false])
            return
        }
        DispatchQueue.main.async {
            let accepted = self.commandHandler?(command) ?? false
            replyHandler([WatchMessageKey.accepted: accepted])
        }
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchMessageKey.summary] as? Data, data.count <= Self.maxSummaryBytes else { return }
        do {
            let summary = try WatchSummary(data: data)
            Task { @MainActor in WatchSummaryStore.shared.record(summary) }
        } catch {
            AppLog.workout.error("Resumen del Watch ilegible: \(ErrorSummary.describe(error), privacy: .public)")
        }
    }
}
