import Foundation
import WatchConnectivity
import Combine
import WatchKit

/// Lado Watch de la comunicación con el iPhone. El protocolo está en `WatchProtocol.swift`.
///
/// - Recibe el estado completo del entrenamiento (contexto o mensaje) y lo entrega a `WorkoutManager`.
///   Descarta estados más viejos que el último recibido y los mal formados.
/// - Los comandos van solo por `sendMessage` con respuesta: sin iPhone al alcance fallan de inmediato
///   en vez de quedar en cola y ejecutarse minutos después.
/// - El resumen de Salud va por `transferUserInfo` (cola con entrega garantizada).
public final class PhoneConnector: NSObject, WCSessionDelegate, ObservableObject {
    public static let shared = PhoneConnector()

    @Published public private(set) var isPhoneReachable = false
    /// El último comando no llegó o el iPhone lo rechazó. Se apaga solo.
    @Published public private(set) var commandFailed = false

    private var lastSentAt: Date = .distantPast
    private static let maxStateBytes = 64 * 1024

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    /// Activa la sesión desde el arranque, para recibir el contexto pendiente.
    public static func activate() {
        _ = shared
    }

    // MARK: - WCSessionDelegate

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            WatchLog.workout.error("Activación de WCSession falló: \(WatchLog.describe(error), privacy: .public)")
        }
        let reachable = session.isReachable
        let context = activationState == .activated ? session.receivedApplicationContext : [:]
        DispatchQueue.main.async {
            self.isPhoneReachable = reachable
            // Un Watch que abre la app a mitad de entrenamiento recoge el último estado enviado.
            self.ingest(context)
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        DispatchQueue.main.async { self.isPhoneReachable = reachable }
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.ingest(applicationContext) }
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.ingest(message) }
    }

    private func ingest(_ payload: [String: Any]) {
        guard let data = payload[WatchMessageKey.state] as? Data, data.count <= Self.maxStateBytes else { return }
        guard let state = try? WatchWorkoutState(data: data), state.isWellFormed else {
            WatchLog.workout.error("Estado del iPhone ilegible o incoherente; descartado")
            return
        }
        // El mismo estado llega por contexto y por mensaje, y un contexto viejo puede reaparecer.
        guard state.sentAt > lastSentAt else { return }
        lastSentAt = state.sentAt
        WorkoutManager.shared.apply(state)
    }

    // MARK: - Envío

    public func send(_ command: WatchCommand) {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isReachable else {
            fail()
            return
        }
        session.sendMessage(
            [WatchMessageKey.command: command.rawValue],
            replyHandler: { [weak self] reply in
                if (reply[WatchMessageKey.accepted] as? Bool) != true { self?.fail() }
            },
            errorHandler: { [weak self] error in
                WatchLog.workout.error("Comando no entregado: \(WatchLog.describe(error), privacy: .public)")
                self?.fail()
            }
        )
    }

    /// Cola garantizada: llega aunque el iPhone no esté al alcance ahora.
    public func send(_ summary: WatchSummary) {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated else {
            WatchLog.workout.error("Resumen no enviado: WCSession inactiva")
            return
        }
        do {
            session.transferUserInfo([WatchMessageKey.summary: try summary.encoded()])
        } catch {
            WatchLog.workout.error("Resumen no codificable: \(WatchLog.describe(error), privacy: .public)")
        }
    }

    private func fail() {
        DispatchQueue.main.async {
            WKInterfaceDevice.current().play(.failure)
            self.commandFailed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.commandFailed = false }
        }
    }
}
