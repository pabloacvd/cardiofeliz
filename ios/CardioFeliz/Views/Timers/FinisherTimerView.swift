import SwiftUI
import Combine

struct FinisherTimerView: View {
    let bloque: Bloque
    let onComplete: (Int) -> Void

    @StateObject private var timerManager: TimerManager
    @State private var currentDate = Date()
    private let redrawTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(bloque: Bloque, onComplete: @escaping (Int) -> Void) {
        self.bloque = bloque
        self.onComplete = onComplete
        let plan = WorkoutPlan(bloque: bloque)
        _timerManager = StateObject(wrappedValue: TimerManager(plan: plan))
    }

    private var totalRounds: Int {
        TimerConfig.finisherRounds(for: bloque)
    }

    private var currentPhase: WorkoutPhase? {
        timerManager.clock.currentPhase
    }

    private var isManual: Bool {
        currentPhase?.isManual ?? false
    }

    private var isRestLike: Bool {
        guard let kind = currentPhase?.kind else { return false }
        return kind == .rest || kind == .transition
    }

    private var secondsLeft: Int {
        let remaining = timerManager.timeRemainingInCurrentPhase(at: currentDate)
        return max(0, Int(ceil(remaining)))
    }

    private var activeElapsed: Int {
        Int(timerManager.clock.activeElapsed(at: currentDate))
    }

    private var blockLabel: String {
        bloque.tipo == .hiitIntervals ? "HIIT POR INTERVALOS" : "FINISHER"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Top Status Bar
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("\(blockLabel) (\(totalRounds) \(totalRounds == 1 ? "RONDA" : "RONDAS"))")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    let totalPhases = timerManager.phases.count
                    let currentIdx = min(timerManager.currentPhaseIndex + 1, totalPhases)
                    Text("\(currentIdx)/\(totalPhases)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                }

                // Global Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray6))
                        let total = timerManager.phases.count
                        let progress = Double(timerManager.currentPhaseIndex) / Double(max(1, total))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: geo.size.width * max(0, min(1, progress)))
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            // Phase Pill
            if let currentPhase {
                HStack(spacing: 6) {
                    Image(systemName: isRestLike ? "cup.and.saucer.fill" : isManual ? "hand.tap.fill" : "bolt.fill")
                    Text(currentPhase.name.uppercased())
                }
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(isRestLike ? .orange : isManual ? .pink : .orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isRestLike ? Color.orange.opacity(0.15) : Color.orange.opacity(0.15))
                .overlay(
                    Capsule().stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                )
                .clipShape(Capsule())
            }

            // Giant Countdown or Manual Check
            if isManual {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "checkmark")
                            .font(.system(size: 48, weight: .black))
                            .foregroundColor(.orange)
                    }

                    Text("TOCA LISTO AL TERMINAR")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                }
                .padding(.vertical, 10)
            } else {
                VStack(spacing: 4) {
                    Text(String(format: "00:%02d", secondsLeft))
                        .font(.system(size: 96, weight: .black, design: .monospaced))
                        .foregroundColor(isRestLike ? .orange : .white)
                        .contentTransition(.numericText())

                    Text("SEGUNDOS RESTANTES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                }
            }

            // Exercise Detail Card
            if let currentPhase {
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentPhase.detail ?? currentPhase.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isRestLike ? Color.orange.opacity(0.3) : Color.orange.opacity(0.4), lineWidth: 1)
                )
            }

            Spacer()

            // Controls
            VStack(spacing: 12) {
                if isManual && timerManager.isRunning {
                    HStack(spacing: 12) {
                        Button {
                            timerManager.next()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                Text("LISTO")
                            }
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.orange, Color.yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if timerManager.isPaused {
                                timerManager.resume()
                            } else {
                                timerManager.pause()
                            }
                        } label: {
                            Image(systemName: timerManager.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.black)
                                .frame(width: 54, height: 50)
                                .background(Color.orange)
                                .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button {
                        if !timerManager.isRunning {
                            timerManager.start()
                        } else if timerManager.isPaused {
                            timerManager.resume()
                        } else {
                            timerManager.pause()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: timerManager.isRunning && !timerManager.isPaused ? "pause.fill" : "play.fill")
                            Text(timerManager.isRunning && !timerManager.isPaused
                                 ? "PAUSAR"
                                 : timerManager.isPaused ? "CONTINUAR" : "INICIAR \(bloque.tipo == .hiitIntervals ? "HIIT" : "FINISHER")")
                        }
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Text("Tiempo: \(formatTime(activeElapsed))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Terminar Bloque") {
                        let elapsed = activeElapsed
                        timerManager.stop()
                        onComplete(elapsed)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .onReceive(redrawTimer) { _ in
            if timerManager.isRunning && !timerManager.isPaused {
                currentDate = Date()
            }
        }
        .onAppear {
            timerManager.onTimerEnd = {
                onComplete(activeElapsed)
            }
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
