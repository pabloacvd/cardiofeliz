import SwiftUI

struct ExerciseEditorView: View {
    let index: Int
    let totalCount: Int
    let tipoBloque: TipoBloque
    let exercise: Ejercicio
    let onUpdate: (String?, Int??) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Badge de minuto o número de paso
                if tipoBloque == .emom {
                    Text("Min \(exercise.minuto ?? (index + 1))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(4)
                } else {
                    Text("#\(index + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .leading)
                }

                // Campo detalle
                TextField("Descripción del ejercicio", text: Binding(
                    get: { exercise.detalle },
                    set: { onUpdate($0, nil) }
                ))
                .font(.system(size: 13))
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(6)

                // Botones de reordenamiento y borrado
                HStack(spacing: 4) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(index > 0 ? .primary : .secondary.opacity(0.3))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .disabled(index == 0)

                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(index < totalCount - 1 ? .primary : .secondary.opacity(0.3))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .disabled(index >= totalCount - 1)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Opciones de tiempo por ejercicio (solo para tipos que no son EMOM)
            if tipoBloque != .emom {
                HStack(spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { exercise.segundos != nil },
                        set: { hasSeconds in
                            onUpdate(nil, hasSeconds ? (exercise.segundos ?? 30) : nil)
                        }
                    )) {
                        Text("Tiempo fijo:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .labelsHidden()

                    Text(exercise.segundos != nil ? "\(exercise.segundos!) seg" : "Paso manual (botón Listo)")
                        .font(.system(size: 11, weight: exercise.segundos != nil ? .bold : .regular))
                        .foregroundColor(exercise.segundos != nil ? .primary : .secondary)

                    if let segs = exercise.segundos {
                        Spacer()
                        Stepper("", value: Binding(
                            get: { segs },
                            set: { onUpdate(nil, max(5, min(RoutineValidationRules.maxSeg, $0))) }
                        ), in: 5...RoutineValidationRules.maxSeg, step: 5)
                        .labelsHidden()
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(8)
        .background(Color(.tertiarySystemBackground).opacity(0.4))
        .cornerRadius(8)
    }
}
