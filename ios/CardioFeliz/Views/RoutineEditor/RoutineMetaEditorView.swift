import SwiftUI

struct RoutineMetaEditorView: View {
    @Binding var draft: RutinaData

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DATOS GENERALES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                // Objetivo
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Objetivo")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)

                        Spacer()

                        Text("\(draft.objetivo.count)/\(RoutineValidationRules.maxLenObjetivo)")
                            .font(.system(size: 11))
                            .foregroundColor(draft.objetivo.count > RoutineValidationRules.maxLenObjetivo ? .red : .secondary)
                    }

                    TextField("Ej: Ganar resistencia y salud cardiovascular", text: Binding(
                        get: { draft.objetivo },
                        set: { draft.objetivo = $0 }
                    ))
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }

                // Edad
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Edad")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)

                        Spacer()

                        Text("\(draft.edad) años")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                    }

                    HStack {
                        Stepper(
                            value: Binding(
                                get: { draft.edad },
                                set: { draft.edad = max(1, min(RoutineValidationRules.maxEdad, $0)) }
                            ),
                            in: 1...RoutineValidationRules.maxEdad
                        ) {
                            Text("Ajustar edad: \(draft.edad)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
            .padding(14)
            .background(Color(.systemBackground).opacity(0.6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
