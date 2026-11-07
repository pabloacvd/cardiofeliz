import SwiftUI

struct ActiveWorkoutView: View {
    let dia: DiaEntrenamiento
    let bloque: Bloque
    @ObservedObject var workflow: WorkoutWorkflowViewModel
    @ObservedObject var activityStore: ActivityStore
    @ObservedObject var weightStore: ProfileWeightStore
    @ObservedObject private var watchSummaries = WatchSummaryStore.shared

    @State private var showExitConfirm: Bool = false

    init(
        dia: DiaEntrenamiento,
        bloque: Bloque,
        workflow: WorkoutWorkflowViewModel,
        activityStore: ActivityStore,
        weightStore: ProfileWeightStore
    ) {
        self.dia = dia
        self.bloque = bloque
        self.workflow = workflow
        self.activityStore = activityStore
        self.weightStore = weightStore
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                // Top Bar
                HStack {
                    Button {
                        showExitConfirm = true
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
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Timer Container
                Group {
                    switch bloque.tipo {
                    case .emom:
                        EmomTimerView(bloque: bloque) { totalSeconds in
                            handleCompletion(totalSeconds: totalSeconds, rounds: nil)
                        }
                    case .amrap:
                        AmrapTimerView(bloque: bloque) { totalSeconds, rounds in
                            handleCompletion(totalSeconds: totalSeconds, rounds: rounds)
                        }
                    case .forTime:
                        ForTimeTimerView(bloque: bloque) { totalSeconds in
                            handleCompletion(totalSeconds: totalSeconds, rounds: nil)
                        }
                    case .tabata:
                        TabataTimerView(bloque: bloque) { totalSeconds in
                            handleCompletion(totalSeconds: totalSeconds, rounds: nil)
                        }
                    case .triserie, .density:
                        TriserieTimerView(bloque: bloque) { totalSeconds in
                            handleCompletion(totalSeconds: totalSeconds, rounds: nil)
                        }
                    case .finisher, .hiitIntervals:
                        FinisherTimerView(bloque: bloque) { totalSeconds in
                            handleCompletion(totalSeconds: totalSeconds, rounds: nil)
                        }
                    }
                }
            }

            // Exit Confirmation Modal
            if showExitConfirm {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)

                    VStack(spacing: 6) {
                        Text("¿Detener Entrenamiento?")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("El progreso del temporizador actual se perderá si sales ahora.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 12) {
                        Button("Continuar") {
                            showExitConfirm = false
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)

                        Button("Salir") {
                            showExitConfirm = false
                            workflow.exitActiveWorkout(to: dia)
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .padding(.top, 4)
                }
                .padding(24)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 28)
            }
        }
        .onAppear {
            // No heredar la sesión del Watch de un bloque anterior.
            TimerManager.discardLastWatchSessionId()
        }
    }

    private func handleCompletion(totalSeconds: Int, rounds: Int?) {
        workflow.handleBlockCompleted(
            dia: dia,
            bloque: bloque,
            totalSeconds: totalSeconds,
            rounds: rounds,
            activityStore: activityStore,
            weightKg: weightStore.weightKg,
            watchSessionId: TimerManager.takeLastWatchSessionId(),
            watchSummaries: watchSummaries.summaries
        )
    }
}
