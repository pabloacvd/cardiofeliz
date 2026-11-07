import SwiftUI

struct DayDetailView: View {
    let dia: DiaEntrenamiento
    @ObservedObject var workflow: WorkoutWorkflowViewModel

    init(dia: DiaEntrenamiento, workflow: WorkoutWorkflowViewModel) {
        self.dia = dia
        self.workflow = workflow
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Top Navigation
                Button {
                    workflow.goHome()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                        Text("Volver a Días")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                // Day Header Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(dia.id.replacingOccurrences(of: "_", with: " ").uppercased())
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(6)

                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10))
                            Text(dia.ubicacion)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(6)
                    }

                    Text(dia.nombre)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 1))

                // Start full routine CTA
                if !dia.bloques.isEmpty {
                    Button {
                        workflow.startWarmup(for: dia)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Iniciar Rutina")
                        }
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color(red: 0.2, green: 0.9, blue: 0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }

                // Warmup Section
                WarmupCardView(
                    calentamiento: dia.calentamiento,
                    calentamientoMinutos: dia.calentamientoMinutos,
                    onStart: {
                        workflow.startWarmup(for: dia)
                    }
                )

                // Blocks Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("BLOQUES DEL ENTRENAMIENTO (\(dia.bloques.count))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("Toca para ver detalle")
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 10) {
                        ForEach(dia.bloques.indices, id: \.self) { idx in
                            let bloque = dia.bloques[idx]
                            let isDone = workflow.isBlockCompleted(diaId: dia.id, blockId: bloque.id)

                            BlockCardView(
                                bloque: bloque,
                                index: idx,
                                isCompleted: isDone
                            ) {
                                workflow.showBlockDetail(dia: dia, bloque: bloque)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
