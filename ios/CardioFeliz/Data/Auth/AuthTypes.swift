import Foundation

// Contrato de autenticación independiente de supabase-swift, para poder probar `SessionManager`
// con dobles de prueba. La implementación real está en `Data/Supabase/SupabaseAuthBackend.swift`.

struct AuthUser: Equatable, Sendable {
    let id: String
    let email: String?

    /// Equivale a `usernameFromEmail` de AuthContext.tsx.
    var username: String {
        email?.split(separator: "@").first.map(String.init) ?? "usuario"
    }
}

enum AuthEvent: Equatable, Sendable {
    /// Primera emisión al empezar a observar: la sesión guardada en Keychain (o nil).
    case initialSession(AuthUser?)
    case signedIn(AuthUser)
    case signedOut
    /// Cualquier otro evento con sesión (token renovado, usuario actualizado...).
    case sessionUpdated(AuthUser)
    /// Evento sin sesión que no es un cierre real; es transitorio y se ignora (como en la PWA).
    case transient
}

protocol AuthBackend: Sendable {
    /// Inicia sesión con email y contraseña. Lanza `DataLayerError` (nunca detalles del servidor).
    func signIn(email: String, password: String) async throws -> AuthUser
    func signOut() async throws
    /// Flujo de eventos de sesión. Emite `.initialSession` al empezar.
    func authEvents() -> AsyncStream<AuthEvent>
}

/// Estados de sesión visibles para la UI. Equivale a `AuthState` de AuthContext.tsx.
enum AuthState: Equatable, Sendable {
    case loading
    /// Faltan URL o clave de Supabase.
    case unconfigured
    case signedOut
    case signedIn(userId: String, username: String)

    var userId: String? {
        if case .signedIn(let id, _) = self { return id }
        return nil
    }

    var username: String? {
        if case .signedIn(_, let name) = self { return name }
        return nil
    }
}

/// Validación de credenciales idéntica a `signIn` de `src/lib/supabase.ts`.
enum Credentials {
    static let usernameMaxLength = 64
    static let passwordMaxLength = 256

    /// Devuelve el email `usuario@app.local` o nil si el usuario o la contraseña no son válidos.
    static func email(username: String, password: String) -> String? {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidUsername(normalized), !password.isEmpty, password.count <= passwordMaxLength else { return nil }
        return "\(normalized)@app.local"
    }

    /// `^[a-z0-9._-]{1,64}$`
    static func isValidUsername(_ username: String) -> Bool {
        guard (1...usernameMaxLength).contains(username.count) else { return false }
        return username.unicodeScalars.allSatisfy { scalar in
            (scalar.value >= 0x61 && scalar.value <= 0x7A)   // a-z
                || (scalar.value >= 0x30 && scalar.value <= 0x39)   // 0-9
                || scalar == "." || scalar == "_" || scalar == "-"
        }
    }
}
