import SwiftUI

/// Sección de cuenta y preferencias en la pantalla de analíticas.
/// Equivale a `src/components/analytics/AccountSection.tsx`.
struct AccountSectionView: View {
    let userName: String
    let weightKg: Double?
    let onEditWeight: () -> Void
    let onManageVacations: () -> Void
    let isVacationActive: Bool
    let onSignOut: () -> Void

    @State private var showSignOutConfirmation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)

                Text("CUENTA Y PREFERENCIAS")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                // User tile
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("USUARIO CONECTADO")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.secondary)

                        Text(userName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

                // Weight tile
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PESO CORPORAL")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.secondary)

                        Text(weightKg != nil ? "\(String(format: "%.1f", weightKg!).replacingOccurrences(of: ".", with: ",")) kg" : "Sin registrar")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button {
                        onEditWeight()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "scalemass.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                            Text("Editar")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

                // Vacation tile
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MODO VACACIONES")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.secondary)

                        Text(isVacationActive ? "Activo (Racha pausada)" : "Inactivo")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isVacationActive ? .purple : .secondary)
                    }

                    Spacer()

                    Button {
                        onManageVacations()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "beach.umbrella.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.purple)
                            Text("Gestionar")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

                // Sign Out button
                Button {
                    showSignOutConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 13, weight: .bold))
                        Text("Cerrar Sesión")
                            .font(.system(size: 13, weight: .black))
                    }
                    .foregroundColor(Color.red.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .confirmationDialog("¿Cerrar sesión?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                    Button("Cerrar Sesión", role: .destructive) {
                        onSignOut()
                    }
                    Button("Cancelar", role: .cancel) {}
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
