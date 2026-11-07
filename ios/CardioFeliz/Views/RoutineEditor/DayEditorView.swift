import SwiftUI

struct DayEditorView: View {
    let dia: DiaEntrenamiento
    let index: Int
    let totalDays: Int
    let onUpdate: (String?, String?, String?, Int??) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let onAddBlock: (TipoBloque) -> Void
    let onMutateBlock: (String, (inout Bloque) -> Void) -> Void
    let onChangeBlockType: (String, TipoBloque) -> Void
    let onDuplicateBlock: (String) -> Void
    let onDeleteBlock: (String) -> Void
    let onMoveBlockUp: (String) -> Void
    let onMoveBlockDown: (String) -> Void

    @State private var isExpanded: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var showingAddBlockSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header del día
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(dia.nombre.isEmpty ? "Día sin nombre" : dia.nombre)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)

                                if !dia.ubicacion.isEmpty {
                                    Text(dia.ubicacion)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(4)
                                }
                            }

                            Text("\(dia.bloques.count) bloques · \(dia.calentamientoMinutos ?? 5) min cal.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Controles del día
                HStack(spacing: 4) {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(index > 0 ? .primary : .secondary.opacity(0.3))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(index == 0)

                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(index < totalDays - 1 ? .primary : .secondary.opacity(0.3))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(index >= totalDays - 1)

                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Eliminar día")
                }
            }

            // Cuerpo del día editable
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().background(Color.white.opacity(0.1))

                    // Nombre y Ubicación
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nombre del Día")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextField("Ej: Día 1 - Pierna", text: Binding(
                                get: { dia.nombre },
                                set: { onUpdate($0, nil, nil, nil) }
                            ))
                            .font(.system(size: 13))
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ubicación")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextField("Ej: Gym / Casa", text: Binding(
                                get: { dia.ubicacion },
                                set: { onUpdate(nil, $0, nil, nil) }
                            ))
                            .font(.system(size: 13))
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                        }
                    }

                    // Calentamiento
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calentamiento")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        TextField("Descripción del calentamiento", text: Binding(
                            get: { dia.calentamiento },
                            set: { onUpdate(nil, nil, $0, nil) }
                        ))
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)

                        HStack {
                            Text("Duración calentamiento:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            Spacer()

                            let mins = dia.calentamientoMinutos ?? 5
                            Text("\(mins) min")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)

                            Stepper("", value: Binding(
                                get: { mins },
                                set: { onUpdate(nil, nil, nil, max(0, min(RoutineValidationRules.maxDuracionMin, $0))) }
                            ), in: 0...RoutineValidationRules.maxDuracionMin, step: 1)
                            .labelsHidden()
                        }
                        .padding(6)
                        .background(Color(.tertiarySystemBackground).opacity(0.3))
                        .cornerRadius(6)
                    }

                    // Lista de bloques
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("BLOQUES DE ENTRENAMIENTO (\(dia.bloques.count))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)

                            Spacer()

                            Button {
                                showingAddBlockSheet = true
                            } label: {
                                Label("Nuevo Bloque", systemImage: "plus.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(spacing: 8) {
                            ForEach(dia.bloques.indices, id: \.self) { bIdx in
                                let bloque = dia.bloques[bIdx]
                                let bId = bloque.id ?? "b_\(bIdx)"

                                BlockEditorView(
                                    diaId: dia.id,
                                    bloque: bloque,
                                    index: bIdx,
                                    totalBlocks: dia.bloques.count,
                                    onMutate: { mutate in
                                        onMutateBlock(bId, mutate)
                                    },
                                    onChangeType: { newTipo in
                                        onChangeBlockType(bId, newTipo)
                                    },
                                    onDuplicate: {
                                        onDuplicateBlock(bId)
                                    },
                                    onDelete: {
                                        onDeleteBlock(bId)
                                    },
                                    onMoveUp: {
                                        onMoveBlockUp(bId)
                                    },
                                    onMoveDown: {
                                        onMoveBlockDown(bId)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .alert("¿Eliminar este día?", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Se eliminará \"\(dia.nombre)\" con todos sus bloques.")
        }
        .confirmationDialog("Selecciona el tipo de bloque", isPresented: $showingAddBlockSheet, titleVisibility: .visible) {
            ForEach(TipoBloque.allCases, id: \.self) { tipo in
                Button(tipo.rawValue) {
                    onAddBlock(tipo)
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }
}
