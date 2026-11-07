import SwiftUI

struct BlockDetailView: View {
    let dia: DiaEntrenamiento
    let bloque: Bloque
    @ObservedObject var workflow: WorkoutWorkflowViewModel

    init(dia: DiaEntrenamiento, bloque: Bloque, workflow: WorkoutWorkflowViewModel) {
        self.dia = dia
        self.bloque = bloque
        self.workflow = workflow
    }

    private var isCompleted: Bool {
        workflow.isBlockCompleted(diaId: dia.id, blockId: bloque.id)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Top Bar
            HStack {
                Button {
                    workflow.destination = .dayDetail(dia)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("Volver")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 1) {
                    Text(dia.nombre)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text(bloque.nombre)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Spacer()

                Circle()
                    .fill(workflow.isIdleTimerDisabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(workflow.isIdleTimerDisabled ? "Pantalla encendida" : "Pantalla estándar")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Metadata badges
                    HStack(spacing: 8) {
                        BlockBadgeView(tipo: bloque.tipo)

                        let meta = BlockMetaHelper.meta(for: bloque)
                        if !meta.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(meta)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                        }

                        if isCompleted {
                            Text("COMPLETADO")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }

                    // Exercises list
                    VStack(alignment: .leading, spacing: 10) {
                        Text("EJERCICIOS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1)

                        VStack(spacing: 8) {
                            ForEach(bloque.ejercicios.indices, id: \.self) { idx in
                                let ej = bloque.ejercicios[idx]
                                let isEmom = ej.minuto != nil

                                HStack(spacing: 12) {
                                    Text(isEmom ? "M\(ej.minuto!)" : "\(idx + 1)")
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 32, height: 32)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)

                                    Text(ej.detalle)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)

                                    Spacer()
                                }
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Bottom CTA
            Button {
                workflow.startActiveWorkout(dia: dia, bloque: bloque)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(startLabel)
                }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color(red: 0.2, green: 0.9, blue: 0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.green.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black.ignoresSafeArea())
    }

    private var startLabel: String {
        if isCompleted { return "Repetir Bloque" }
        switch bloque.tipo {
        case .emom: return "Iniciar EMOM"
        case .amrap: return "Iniciar AMRAP"
        case .forTime: return "Iniciar For Time"
        case .tabata: return "Iniciar Tabata"
        case .triserie: return "Iniciar Triserie"
        case .density: return "Iniciar Density"
        case .finisher: return "Iniciar Finisher"
        case .hiitIntervals: return "Iniciar HIIT"
        }
    }
}
