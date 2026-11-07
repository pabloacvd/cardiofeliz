import Foundation
import Supabase

/// Implementación de `AuthBackend` sobre supabase-swift.
///
/// - La sesión se guarda en el Keychain con `KeychainLocalStorage` (almacenamiento por defecto de
///   supabase-swift en Apple; usa `kSecAttrAccessibleAfterFirstUnlock`). Aquí se fija un `service`
///   propio para aislar los items del resto de apps con el mismo SDK.
/// - `emitLocalSessionAsInitialSession: true` emite la sesión guardada sin esperar a la red, para que
///   la app funcione offline (local-first); el token se renueva en segundo plano.
/// - Nunca se registran emails, tokens ni mensajes del servidor.
final class SupabaseAuthBackend: AuthBackend {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return AuthUser(session.user)
        } catch {
            throw SupabaseErrorMapper.map(error, duringSignIn: true)
        }
    }

    /// Cierra solo esta sesión (`.local`). La PWA usa el alcance global de supabase-js; aquí no se
    /// expulsa a otros dispositivos del mismo usuario.
    func signOut() async throws {
        do {
            try await client.auth.signOut(scope: .local)
        } catch {
            throw SupabaseErrorMapper.map(error, duringSignIn: false)
        }
    }

    func authEvents() -> AsyncStream<AuthEvent> {
        let auth = client.auth
        return AsyncStream { continuation in
            let task = Task {
                for await (event, session) in auth.authStateChanges {
                    continuation.yield(Self.map(event: event, session: session))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func map(event: AuthChangeEvent, session: Session?) -> AuthEvent {
        switch event {
        case .initialSession:
            return .initialSession(session.map { AuthUser($0.user) })
        case .signedOut:
            return .signedOut
        case .signedIn:
            return session.map { .signedIn(AuthUser($0.user)) } ?? .transient
        default:
            return session.map { .sessionUpdated(AuthUser($0.user)) } ?? .transient
        }
    }
}

extension AuthUser {
    init(_ user: User) {
        // Postgres devuelve los uuid en minúsculas; se normaliza para comparar ids de forma estable.
        self.init(id: user.id.uuidString.lowercased(), email: user.email)
    }
}
