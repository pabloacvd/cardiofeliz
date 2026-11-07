import Foundation
import Supabase

/// Traduce errores de supabase-swift / URLSession a `DataLayerError` (sin conservar mensajes
/// del servidor, que podrían contener datos sensibles).
enum SupabaseErrorMapper {
    static func map(_ error: Error, duringSignIn: Bool) -> DataLayerError {
        if let e = error as? DataLayerError { return e }
        if error is CancellationError { return .network }
        if error is URLError { return .network }
        if error is DecodingError { return .decoding }
        if let e = error as? PostgrestError { return .server(code: e.code) }
        if let e = error as? AuthError {
            switch e {
            case .sessionMissing:
                return .notAuthenticated
            case .api(_, let errorCode, _, let response):
                if duringSignIn, (400...422).contains(response.statusCode) { return .invalidCredentials }
                if response.statusCode == 401 { return .notAuthenticated }
                return .server(code: errorCode.rawValue)
            default:
                return duringSignIn ? .invalidCredentials : .unknown
            }
        }
        return .unknown
    }
}

enum SupabaseClientFactory {
    /// Cliente con sesión efímera de URLSession (sin caché en disco ni cookies), TLS ≥ 1.2 y
    /// timeouts acotados. La validación de certificados queda por defecto (no se sobrescribe).
    static func make(config: SupabaseConfig, bundleID: String = Bundle.main.bundleIdentifier ?? "com.cardiofeliz.app") -> SupabaseClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 20
        sessionConfig.timeoutIntervalForResource = 60
        sessionConfig.waitsForConnectivity = false
        sessionConfig.tlsMinimumSupportedProtocolVersion = .TLSv12

        return SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: KeychainLocalStorage(service: "\(bundleID).supabase-auth"),
                    emitLocalSessionAsInitialSession: true
                ),
                global: .init(session: URLSession(configuration: sessionConfig))
            )
        )
    }
}
