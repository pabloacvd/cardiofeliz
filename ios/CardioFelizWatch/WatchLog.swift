import Foundation
import os

/// Logs del Watch. Nunca incluyen datos de Salud ni mensajes de error: solo el dominio y el código.
enum WatchLog {
    static let workout = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CardioFelizWatch", category: "workout")

    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        return "\(ns.domain)#\(ns.code)"
    }
}
