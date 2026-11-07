import SwiftUI

struct BlockEditorView: View {
    let diaId: String
    let bloque: Bloque
    let index: Int
    let totalBlocks: Int
    let onMutate: ((inout Bloque) -> Void) -> Void
    let onChangeType: (TipoBloque) -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @State private var isExpanded: Bool = false
    @State private var showingDeleteAlert: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header del bloque
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(bloque.nombre.isEmpty ? "Bloque sin nombre" : bloque.nombre)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)

                                BlockBadgeView(tipo: bloque.tipo)
                            }

                            Text("\(bloque.ejercicios.count) ejercicios · \(BlockMetaHelper.meta(for: bloque))")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Botones de acción del bloque
                HStack(spacing: 4) {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(index > 0 ? .primary : .secondary.opacity(0.3))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .disabled(index == 0)

                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(index < totalBlocks - 1 ? .primary : .secondary.opacity(0.3))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .disabled(index >= totalBlocks - 1)

                    Button(action: onDuplicate) {
                        Image(systemName: "plus.square.on.square")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Duplicar bloque")

                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Eliminar bloque")
                }
            }

            // Cuerpo editable (cuando está expandido)
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().background(Color.white.opacity(0.1))

                    // Tipo de Bloque
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tipo de Bloque")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        Picker("Tipo", selection: Binding(
                            get: { bloque.tipo },
                            set: { onChangeType($0) }
                        )) {
                            ForEach(TipoBloque.allCases, id: \.self) { tipo in
                                Text(tipo.rawValue).tag(tipo)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Nombre del bloque
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nombre")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        TextField("Ej: Bloque A", text: Binding(
                            get: { bloque.nombre },
                            set: { newName in onMutate { $0.nombre = newName } }
                        ))
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                    }

                    // Parámetros específicos según el tipo
                    typeSpecificSettings

                    // Lista de ejercicios
                    exercisesSection
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .alert("¿Eliminar bloque?", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Se eliminará \"\(bloque.nombre)\" y todos sus ejercicios.")
        }
    }

    @ViewBuilder
    private var typeSpecificSettings: some View {
        switch bloque.tipo {
        case .emom:
            stepperField(
                title: "Duración Total (minutos)",
                value: bloque.duracionMinutos ?? 16,
                range: 1...RoutineValidationRules.maxDuracionMin,
                unit: "min",
                step: 1
            ) { newVal in onMutate { $0.duracionMinutos = newVal } }

        case .amrap:
            stepperField(
                title: "Duración Total (minutos)",
                value: bloque.duracionMinutos ?? 12,
                range: 1...RoutineValidationRules.maxDuracionMin,
                unit: "min",
                step: 1
            ) { newVal in onMutate { $0.duracionMinutos = newVal } }

        case .forTime:
            stepperField(
                title: "Tope de Tiempo (Cap minutos)",
                value: bloque.capMinutos ?? 15,
                range: 1...RoutineValidationRules.maxCapMin,
                unit: "min",
                step: 1
            ) { newVal in onMutate { $0.capMinutos = newVal } }

        case .triserie, .density:
            VStack(spacing: 8) {
                stepperField(
                    title: "Rondas",
                    value: bloque.rondas ?? 4,
                    range: 1...RoutineValidationRules.maxRondas,
                    unit: "rondas",
                    step: 1
                ) { newVal in onMutate { $0.rondas = newVal } }

                stepperField(
                    title: "Descanso entre rondas",
                    value: bloque.descansoSeg ?? 45,
                    range: 0...RoutineValidationRules.maxSeg,
                    unit: "seg",
                    step: 5
                ) { newVal in onMutate { $0.descansoSeg = newVal } }
            }

        case .tabata:
            VStack(spacing: 8) {
                stepperField(
                    title: "Rondas",
                    value: bloque.rondas ?? 8,
                    range: 1...RoutineValidationRules.maxRondas,
                    unit: "rondas",
                    step: 1
                ) { newVal in onMutate { $0.rondas = newVal } }

                stepperField(
                    title: "Tiempo de Trabajo",
                    value: bloque.trabajoSeg ?? 20,
                    range: 1...RoutineValidationRules.maxSeg,
                    unit: "seg",
                    step: 5
                ) { newVal in onMutate { $0.trabajoSeg = newVal } }

                stepperField(
                    title: "Tiempo de Descanso",
                    value: bloque.descansoTabataSeg ?? 10,
                    range: 1...RoutineValidationRules.maxSeg,
                    unit: "seg",
                    step: 5
                ) { newVal in onMutate { $0.descansoTabataSeg = newVal } }
            }

        case .finisher:
            stepperField(
                title: "Rondas",
                value: bloque.rondas ?? 3,
                range: 1...RoutineValidationRules.maxRondas,
                unit: "rondas",
                step: 1
            ) { newVal in onMutate { $0.rondas = newVal } }

        case .hiitIntervals:
            VStack(spacing: 8) {
                stepperField(
                    title: "Rondas",
                    value: bloque.rondas ?? 4,
                    range: 1...RoutineValidationRules.maxRondas,
                    unit: "rondas",
                    step: 1
                ) { newVal in onMutate { $0.rondas = newVal } }

                stepperField(
                    title: "Duración Total (minutos)",
                    value: bloque.duracionMinutos ?? 12,
                    range: 1...RoutineValidationRules.maxDuracionMin,
                    unit: "min",
                    step: 1
                ) { newVal in onMutate { $0.duracionMinutos = newVal } }

                stepperField(
                    title: "Trabajo por paso activo",
                    value: bloque.trabajoSeg ?? 40,
                    range: 1...RoutineValidationRules.maxSeg,
                    unit: "seg",
                    step: 5
                ) { newVal in onMutate { $0.trabajoSeg = newVal } }
            }
        }
    }

    private func stepperField(
        title: String,
        value: Int,
        range: ClosedRange<Int>,
        unit: String,
        step: Int,
        onUpdate: @escaping (Int) -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()

            Text("\(value) \(unit)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)

            Stepper("", value: Binding(
                get: { value },
                set: { onUpdate(max(range.lowerBound, min(range.upperBound, $0))) }
            ), in: range, step: step)
            .labelsHidden()
        }
        .padding(6)
        .background(Color(.tertiarySystemBackground).opacity(0.3))
        .cornerRadius(6)
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EJERCICIOS (\(bloque.ejercicios.count))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    let nextMin = bloque.tipo == .emom ? (bloque.ejercicios.count + 1) : nil
                    let newEj = Ejercicio(detalle: "", minuto: nextMin, segundos: bloque.tipo != .emom ? 30 : nil)
                    onMutate { $0.ejercicios.append(newEj) }
                } label: {
                    Label("Agregar", systemImage: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 6) {
                ForEach(bloque.ejercicios.indices, id: \.self) { eIdx in
                    let ej = bloque.ejercicios[eIdx]
                    ExerciseEditorView(
                        index: eIdx,
                        totalCount: bloque.ejercicios.count,
                        tipoBloque: bloque.tipo,
                        exercise: ej,
                        onUpdate: { detalle, segundos in
                            onMutate { b in
                                guard eIdx < b.ejercicios.count else { return }
                                if let detalle { b.ejercicios[eIdx].detalle = detalle }
                                if let seg = segundos {
                                    b.ejercicios[eIdx].segundos = seg
                                }
                            }
                        },
                        onMoveUp: {
                            onMutate { b in
                                guard eIdx > 0, eIdx < b.ejercicios.count else { return }
                                let item = b.ejercicios.remove(at: eIdx)
                                b.ejercicios.insert(item, at: eIdx - 1)
                                if b.tipo == .emom {
                                    b.ejercicios = RoutineEditorOperations.renumberEmomExercises(b.ejercicios)
                                }
                            }
                        },
                        onMoveDown: {
                            onMutate { b in
                                guard eIdx < b.ejercicios.count - 1 else { return }
                                let item = b.ejercicios.remove(at: eIdx)
                                b.ejercicios.insert(item, at: eIdx + 1)
                                if b.tipo == .emom {
                                    b.ejercicios = RoutineEditorOperations.renumberEmomExercises(b.ejercicios)
                                }
                            }
                        },
                        onDelete: {
                            onMutate { b in
                                guard eIdx < b.ejercicios.count else { return }
                                b.ejercicios.remove(at: eIdx)
                                if b.tipo == .emom {
                                    b.ejercicios = RoutineEditorOperations.renumberEmomExercises(b.ejercicios)
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}
