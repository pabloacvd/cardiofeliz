import SwiftUI

struct RoutineEditorView: View {
    @ObservedObject var routineStore: RoutineStore
    @ObservedObject var workflow: WorkoutWorkflowViewModel
    let username: String
    let onDismiss: () -> Void

    @State private var draft: RutinaData
    @State private var initialRoutine: RutinaData
    @State private var isSaving: Bool = false
    @State private var showingDiscardAlert: Bool = false
    @State private var saveErrorMessage: String? = nil
    @State private var showingSaveSuccess: Bool = false

    init(
        routineStore: RoutineStore,
        workflow: WorkoutWorkflowViewModel,
        username: String,
        onDismiss: @escaping () -> Void
    ) {
        self.routineStore = routineStore
        self.workflow = workflow
        self.username = username
        self.onDismiss = onDismiss
        _draft = State(initialValue: routineStore.rutina)
        _initialRoutine = State(initialValue: routineStore.rutina)
    }

    private var hasChanges: Bool {
        RoutineEditorOperations.hasRoutineChanges(a: draft, b: initialRoutine)
    }

    private var validationResult: RoutineValidationResult {
        RoutineValidator.validateRutina(draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                VStack(spacing: 20) {
                    // Banner de cambios sin guardar
                    if hasChanges {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("Tienes cambios sin guardar.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)
                    }

                    // Banner de errores de validación
                    if !validationResult.isValid {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.octagon.fill")
                                    .foregroundColor(.red)
                                Text("Corrige los siguientes errores antes de guardar:")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.red)
                            }

                            ForEach(validationResult.errors.prefix(4), id: \.self) { err in
                                Text("• \(err)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red.opacity(0.9))
                            }

                            if validationResult.errors.count > 4 {
                                Text("…y \(validationResult.errors.count - 4) errores más.")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(8)
                    }

                    // Mensaje de error al guardar
                    if let saveErrorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(saveErrorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                            Spacer()
                            Button("OK") { self.saveErrorMessage = nil }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.red)
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(8)
                    }

                    // Toast de guardado exitoso
                    if showingSaveSuccess {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Rutina guardada y sincronizada correctamente.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(8)
                        .transition(.opacity)
                    }

                    // 1. Datos Generales (Objetivo, Edad)
                    RoutineMetaEditorView(draft: $draft)

                    // 2. Días de entrenamiento
                    daysSection

                    // 3. Copia de Seguridad y Restauración
                    RoutineBackupSectionView(
                        draft: draft,
                        username: username,
                        isCustom: routineStore.isCustom,
                        onLoadDraft: { imported in
                            draft = imported
                        },
                        onRestoreDefault: {
                            draft = RoutineSyncLogic.getDefaultRoutine(displayName: username)
                        }
                    )
                }
                .padding(16)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .alert("¿Descartar cambios?", isPresented: $showingDiscardAlert) {
            Button("Seguir editando", role: .cancel) {}
            Button("Descartar", role: .destructive) {
                onDismiss()
            }
        } message: {
            Text("Hay cambios en tu rutina que no has guardado. Si sales ahora se perderán.")
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button {
                if hasChanges {
                    showingDiscardAlert = true
                } else {
                    onDismiss()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                    Text("Volver")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text("Mi Rutina")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(syncColor)
                        .frame(width: 5, height: 5)
                    Text(syncLabel)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                saveChanges()
            } label: {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 60)
                } else {
                    Text("Guardar")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(canSave ? .black : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(canSave ? Color.green : Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var canSave: Bool {
        hasChanges && validationResult.isValid
    }

    private var syncColor: Color {
        switch routineStore.syncStatus {
        case .synced: return .green
        case .syncing: return .blue
        case .pending: return .orange
        case .error: return .red
        }
    }

    private var syncLabel: String {
        switch routineStore.syncStatus {
        case .synced: return routineStore.isCustom ? "Personalizada" : "Por defecto"
        case .syncing: return "Sincronizando…"
        case .pending: return "Pendiente de subir"
        case .error: return "Error de sincronización"
        }
    }

    // MARK: - Sección Días

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("DÍAS DE ENTRENAMIENTO (\(draft.diasEntrenamiento.count)/\(RoutineValidationRules.maxDias))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                if draft.diasEntrenamiento.count < RoutineValidationRules.maxDias {
                    Button {
                        draft = RoutineEditorOperations.addDay(draft)
                    } label: {
                        Label("Nuevo Día", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 12) {
                ForEach(draft.diasEntrenamiento.indices, id: \.self) { dIdx in
                    let dia = draft.diasEntrenamiento[dIdx]

                    DayEditorView(
                        dia: dia,
                        index: dIdx,
                        totalDays: draft.diasEntrenamiento.count,
                        onUpdate: { nombre, ubicacion, calentamiento, calMin in
                            draft = RoutineEditorOperations.updateDay(
                                rutina: draft,
                                diaId: dia.id,
                                nombre: nombre,
                                ubicacion: ubicacion,
                                calentamiento: calentamiento,
                                calentamientoMinutos: calMin
                            )
                        },
                        onMoveUp: {
                            draft = RoutineEditorOperations.moveDay(draft, fromIndex: dIdx, toIndex: dIdx - 1)
                        },
                        onMoveDown: {
                            draft = RoutineEditorOperations.moveDay(draft, fromIndex: dIdx, toIndex: dIdx + 1)
                        },
                        onDelete: {
                            draft = RoutineEditorOperations.removeDay(draft, diaId: dia.id)
                        },
                        onAddBlock: { tipo in
                            draft = RoutineEditorOperations.addBlock(draft, diaId: dia.id, tipo: tipo)
                        },
                        onMutateBlock: { bloqueId, mutate in
                            draft = RoutineEditorOperations.updateBlock(draft, diaId: dia.id, bloqueId: bloqueId, mutate: mutate)
                        },
                        onChangeBlockType: { bloqueId, newTipo in
                            draft = RoutineEditorOperations.changeBlockType(draft, diaId: dia.id, bloqueId: bloqueId, newTipo: newTipo)
                        },
                        onDuplicateBlock: { bloqueId in
                            draft = RoutineEditorOperations.duplicateBlock(draft, diaId: dia.id, bloqueId: bloqueId)
                        },
                        onDeleteBlock: { bloqueId in
                            draft = RoutineEditorOperations.removeBlock(draft, diaId: dia.id, bloqueId: bloqueId)
                        },
                        onMoveBlockUp: { bloqueId in
                            if let bIdx = dia.bloques.firstIndex(where: { $0.id == bloqueId }), bIdx > 0 {
                                draft = RoutineEditorOperations.moveBlock(draft, diaId: dia.id, fromIndex: bIdx, toIndex: bIdx - 1)
                            }
                        },
                        onMoveBlockDown: { bloqueId in
                            if let bIdx = dia.bloques.firstIndex(where: { $0.id == bloqueId }), bIdx < dia.bloques.count - 1 {
                                draft = RoutineEditorOperations.moveBlock(draft, diaId: dia.id, fromIndex: bIdx, toIndex: bIdx + 1)
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Guardado

    private func saveChanges() {
        guard canSave else { return }
        isSaving = true
        saveErrorMessage = nil

        Task {
            do {
                if RoutineImportExport.isDefaultRoutine(draft) && routineStore.isCustom {
                    try await routineStore.resetRoutine()
                } else {
                    try await routineStore.saveRoutine(draft)
                }
                workflow.setRoutine(routineStore.rutina)
                initialRoutine = routineStore.rutina
                draft = routineStore.rutina
                isSaving = false
                showingSaveSuccess = true
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    showingSaveSuccess = false
                }
            } catch {
                isSaving = false
                saveErrorMessage = "Error al guardar la rutina: \(error.localizedDescription)"
            }
        }
    }
}
