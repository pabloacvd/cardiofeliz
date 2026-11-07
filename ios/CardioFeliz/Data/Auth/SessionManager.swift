import Foundation
import Combine

/// Estado de sesión observable. Equivale a `AuthProvider` de AuthContext.tsx: los eventos del
/// backend son la única fuente de verdad. Solo `signedOut` e `initialSession` sin sesión llevan
/// al login; otros eventos sin sesión son transitorios y se ignoran.
@MainActor
final class SessionManager: ObservableObject {
    @Published private(set) var state: AuthState
    @Published private(set) var isSigningIn = false

    private let backend: AuthBackend?
    private var observer: Task<Void, Never>?

    /// `backend == nil` significa "sin configurar".
    init(backend: AuthBackend?) {
        self.backend = backend
        self.state = backend == nil ? .unconfigured : .loading
    }

    deinit { observer?.cancel() }

    /// Id del usuario con sesión, o nil. Equivale a `getCurrentUserId`.
    var currentUserId: String? { state.userId }

    /// Empieza a observar los cambios de sesión (idempotente).
    func start() {
        guard let backend, observer == nil else { return }
        let events = backend.authEvents()
        observer = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                self.handle(event)
            }
        }
    }

    func stop() {
        observer?.cancel()
        observer = nil
    }

    /// Aplica un evento de sesión. Interno para poder probarlo sin concurrencia.
    func handle(_ event: AuthEvent) {
        switch event {
        case .initialSession(let user):
            if let user { setSignedIn(user) } else { state = .signedOut }
        case .signedIn(let user), .sessionUpdated(let user):
            setSignedIn(user)
        case .signedOut:
            state = .signedOut
        case .transient:
            break
        }
    }

    /// Inicia sesión. Lanza `DataLayerError` con un mensaje apto para el usuario (`userMessage`).
    func signIn(username: String, password: String) async throws {
        guard let backend else { throw DataLayerError.notConfigured }
        guard let email = Credentials.email(username: username, password: password) else {
            throw DataLayerError.invalidCredentials
        }
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let user = try await backend.signIn(email: email, password: password)
            setSignedIn(user)
        } catch let error as DataLayerError {
            AppLog.auth.error("signIn failed: \(ErrorSummary.describe(error), privacy: .public)")
            throw error
        } catch {
            AppLog.auth.error("signIn failed: \(ErrorSummary.describe(error), privacy: .public)")
            throw DataLayerError.unknown
        }
    }

    /// Cierra sesión. Aunque la red falle, la sesión local ya se elimina y la UI vuelve al login.
    func signOut() async {
        guard let backend else { return }
        do {
            try await backend.signOut()
        } catch {
            AppLog.auth.error("signOut failed: \(ErrorSummary.describe(error), privacy: .public)")
        }
        state = .signedOut
    }

    private func setSignedIn(_ user: AuthUser) {
        let next = AuthState.signedIn(userId: user.id, username: user.username)
        if state != next { state = next }
    }
}
