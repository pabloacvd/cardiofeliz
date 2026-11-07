import SwiftUI
import Combine

struct WarmupView: View {
    let dia: DiaEntrenamiento
    @ObservedObject var workflow: WorkoutWorkflowViewModel

    @State private var secondsLeft: Int
    @State private var isRunning: Bool = false
    @State private var isCompleted: Bool = false

    private let initialSeconds: Int
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    init(dia: DiaEntrenamiento, workflow: WorkoutWorkflowViewModel) {
        self.dia = dia
        self.workflow = workflow
        let mins = dia.calentamientoMinutos ?? 0
        let secs = max(0, mins * 60)
        self.initialSeconds = secs
        _secondsLeft = State(initialValue: secs)
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
                    Text("Calentamiento")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.orange)
                }

                Spacer()

                Circle()
                    .fill(workflow.isIdleTimerDisabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(workflow.isIdleTimerDisabled ? "Pantalla encendida" : "Pantalla estándar")
            }

            ScrollView {
                VStack(spacing: 20) {
                    // Warmup description card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("CALENTAMIENTO")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(.orange)
                        }

                        Text(dia.calentamiento)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.3), lineWidth: 1))

                    // Timer Card (if minutes > 0)
                    if initialSeconds > 0 {
                        VStack(spacing: 14) {
                            Text("TIMER DE CALENTAMIENTO")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1)

                            Text(formatTime(secondsLeft))
                                .font(.system(size: 64, weight: .black, design: .monospaced))
                                .foregroundColor(isCompleted ? .green : .orange)
                                .contentTransition(.numericText())

                            HStack(spacing: 12) {
                                Button {
                                    toggleTimer()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                        Text(isRunning ? "Pausar" : isCompleted ? "¡Listo!" : "Iniciar")
                                    }
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(isRunning ? Color.orange : Color.green)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                                .disabled(isCompleted)

                                Button {
                                    resetTimer()
                                } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .frame(width: 38, height: 38)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }

                            if isCompleted {
                                Text("¡Calentamiento completo! Podés comenzar el primer bloque.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.2), lineWidth: 1))
                    }
                }
            }

            Spacer()

            // Bottom CTA
            if let firstBlock = dia.bloques.first {
                Button {
                    workflow.showBlockDetail(dia: dia, bloque: firstBlock)
                } label: {
                    HStack(spacing: 8) {
                        Text("Pasar al Bloque A")
                        Image(systemName: "chevron.right")
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
        }
        .padding(16)
        .background(Color.black.ignoresSafeArea())
        .onReceive(timer) { _ in
            guard isRunning else { return }
            if secondsLeft <= 4 && secondsLeft > 1 {
                SoundManager.shared.playCountdownTick()
            }
            if secondsLeft <= 1 {
                secondsLeft = 0
                isRunning = false
                isCompleted = true
                SoundManager.shared.playGo()
                return
            }
            secondsLeft -= 1
        }
    }

    private func toggleTimer() {
        if !isRunning {
            SoundManager.shared.playGo()
        }
        isRunning.toggle()
    }

    private func resetTimer() {
        isRunning = false
        isCompleted = false
        secondsLeft = initialSeconds
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
