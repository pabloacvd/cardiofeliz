import SwiftUI

/// Pantalla mínima de inicio de sesión (mismo contrato que la PWA: usuario → usuario@app.local).
/// No hay registro desde la app. Los errores son genéricos.
struct LoginView: View {
    @ObservedObject var session: SessionManager
    var onEnableDebugDemo: (() -> Void)? = nil

    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field { case username, password }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("CardioFeliz")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                TextField("Usuario", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focus, equals: .username)
                    .onSubmit { focus = .password }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                SecureField("Contraseña", text: $password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($focus, equals: .password)
                    .onSubmit { Task { await submit() } }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("login-error")
            }

            Button {
                Task { await submit() }
            } label: {
                Group {
                    if session.isSigningIn {
                        ProgressView().tint(.white)
                    } else {
                        Text("Entrar").font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSubmit ? Color.green : Color.gray)
                .cornerRadius(14)
            }
            .disabled(!canSubmit)

            #if DEBUG
            if let onEnableDebugDemo {
                Button {
                    onEnableDebugDemo()
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Ver flujo de entrenamiento (Modo DEBUG)")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            #endif

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var canSubmit: Bool {
        !session.isSigningIn && !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private func submit() async {
        guard canSubmit else { return }
        errorMessage = nil
        do {
            try await session.signIn(username: username, password: password)
            password = ""
        } catch let error as DataLayerError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = DataLayerError.unknown.userMessage
        }
    }
}

/// Estado "sin configurar" (equivale a `unconfigured` de AuthContext.tsx).
struct UnconfiguredView: View {
    var onEnableDebugDemo: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            Text("Sin configurar")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("Faltan SUPABASE_URL y SUPABASE_ANON_KEY en ios/Config.xcconfig. Añádelos (hay un ejemplo en Config.xcconfig.example), regenera el proyecto y vuelve a compilar.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            #if DEBUG
            if let onEnableDebugDemo {
                Button {
                    onEnableDebugDemo()
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Ver flujo de entrenamiento (Modo DEBUG)")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            #endif
        }
        .padding(32)
    }
}
