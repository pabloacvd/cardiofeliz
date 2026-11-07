import SwiftUI

/// Modal para gestionar el Modo Vacaciones (iniciar, finalizar o cancelar).
/// Equivale a `src/components/VacationSheet.tsx`.
struct VacationSheetView: View {
    @ObservedObject var vacationsStore: VacationsStore
    let status: VacationStatus
    let today: DateKey
    let onClose: () -> Void

    @State private var startDate: Date = Date()
    @State private var confirmEnd: Bool = false
    @State private var confirmDelete: Bool = false
    @State private var isSubmitting: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if status.active {
                        activeVacationContent
                    } else {
                        inactiveVacationContent
                    }
                }
                .padding(20)
            }
            .navigationTitle("Modo Vacaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        onClose()
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Active Content

    @ViewBuilder
    private var activeVacationContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Active Banner
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "beach.umbrella.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.purple)
                    Text("Vacaciones en curso")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.purple.opacity(0.95))
                }

                if let current = status.current {
                    let d = status.lengthDays
                    Text("Iniciadas el **\(current.startOn)** (\(d) \(d == 1 ? "día" : "días")). Tu racha está congelada sin gastar congeladores.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.85))
                        .lineSpacing(2)
                }

                if status.longWarning {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Llevás más de 30 días de vacaciones. Tu racha se mantiene intacta.")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(10)
                }
            }
            .padding(16)
            .background(Color.purple.opacity(0.15))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.purple.opacity(0.35), lineWidth: 1)
            )

            // Returning info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.yellow)
                    Text("Al volver de vacaciones:")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Se activan **3 días de '¡Hay que recuperar!'** con misiones suaves y un multiplicador de **×1.5 XP** en tus entrenamientos.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)

            // Actions
            VStack(spacing: 12) {
                Button {
                    if !confirmEnd {
                        confirmEnd = true
                    } else {
                        Task {
                            isSubmitting = true
                            try? await vacationsStore.endActiveVacation(today: today)
                            isSubmitting = false
                            onClose()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text(confirmEnd ? "¿Confirmar regreso hoy?" : "Volver de vacaciones hoy")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(confirmEnd ? Color.green : Color.green.opacity(0.9))
                    .cornerRadius(14)
                }
                .disabled(isSubmitting)

                if let current = status.current {
                    Button {
                        if !confirmDelete {
                            confirmDelete = true
                        } else {
                            Task {
                                isSubmitting = true
                                try? await vacationsStore.deleteVacation(id: current.id)
                                isSubmitting = false
                                onClose()
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text(confirmDelete ? "¿Eliminar este período de vacaciones?" : "Cancelar período de vacaciones")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(confirmDelete ? .red : .secondary)
                        .padding(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Inactive Content

    @ViewBuilder
    private var inactiveVacationContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Explanation
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "beach.umbrella.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.purple)
                    Text("¿Te vas de viaje o descanso?")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("El Modo Vacaciones **congela tu racha** diaria y semanal mientras esté activo. No consume tus congeladores acumulados y podés reactivar tu rutina cuando vuelvas.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)

            // Date picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Fecha de inicio")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                DatePicker(
                    "Inicio",
                    selection: $startDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)

                Text("Por defecto es hoy.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(.tertiaryLabel))
            }

            // Start button
            Button {
                Task {
                    isSubmitting = true
                    let startKey = ActivityValidation.localDay(startDate)
                    try? await vacationsStore.startVacation(startOn: startKey)
                    isSubmitting = false
                    onClose()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "beach.umbrella.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Activar Modo Vacaciones")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color.purple)
                .cornerRadius(14)
                .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 3)
            }
            .disabled(isSubmitting)
        }
    }
}
