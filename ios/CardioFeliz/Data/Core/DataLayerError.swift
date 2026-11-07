import Foundation
import os

// Errores de la capa de datos. Hacia el usuario solo se muestran mensajes genéricos
// (`userMessage`); el detalle técnico va a `Logger` mediante `ErrorSummary`, que nunca
// incluye mensajes del servidor, tokens, contraseñas ni emails.

enum DataLayerError: Error, Equatable {
    /// Faltan SUPABASE_URL / SUPABASE_ANON_KEY (equivale a `unconfigured` de AuthContext.tsx).
    case notConfigured
    case notAuthenticated
    case invalidCredentials
    /// Entrada rechazada por la validación local (antes de guardar o enviar).
    case invalidInput
    case network
    case server(code: String?)
    case decoding
    case unknown

    /// Mensaje apto para mostrar al usuario. Sin detalles técnicos.
    var userMessage: String {
        switch self {
        case .notConfigured: return "El servicio no está disponible."
        case .notAuthenticated: return "Tu sesión no está activa. Inicia sesión de nuevo."
        case .invalidCredentials: return "Usuario o contraseña incorrectos."
        case .invalidInput: return "Los datos introducidos no son válidos."
        case .network: return "No se pudo conectar. Revisa tu conexión e inténtalo de nuevo."
        case .server, .decoding, .unknown: return "Ocurrió un problema. Inténtalo de nuevo más tarde."
        }
    }
}

enum ErrorSummary {
    /// Descripción corta y segura para logs: solo el tipo y un código, nunca el mensaje.
    static func describe(_ error: Error) -> String {
        switch error {
        case let e as DataLayerError:
            if case .server(let code) = e { return "DataLayerError.server(code: \(code ?? "nil"))" }
            return "DataLayerError.\(e)"
        case let e as URLError:
            return "URLError(\(e.code.rawValue))"
        case is DecodingError:
            return "DecodingError"
        default:
            let ns = error as NSError
            return "\(ns.domain)#\(ns.code)"
        }
    }
}

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "CardioFeliz"
    static let config = Logger(subsystem: subsystem, category: "config")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let workout = Logger(subsystem: subsystem, category: "workout")
}
