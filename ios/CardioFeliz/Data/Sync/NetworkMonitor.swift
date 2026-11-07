import Foundation
import Network
import Combine

/// Estado de conectividad (equivale a `navigator.onLine` y al evento `online` de la PWA).
/// `isOnline` es solo una pista: si es true y la red falla igual, la sincronización lo reintenta.
@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isOnline = true
    /// Se llama cuando la red pasa de no disponible a disponible.
    var onReconnect: (() -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.cardiofeliz.network-monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in self?.update(online: online) }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }

    private func update(online: Bool) {
        let wasOnline = isOnline
        isOnline = online
        if online, !wasOnline { onReconnect?() }
    }
}
