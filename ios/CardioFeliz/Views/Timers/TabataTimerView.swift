import SwiftUI
import Combine

struct TabataTimerView: View {
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

    private var config: TabataConfig {
        TimerConfig.tabataConfig(for: bloque)
    }

    private var currentPhase: WorkoutPhase? {
        timerManager.clock.currentPhase
    }

    private var isWork: Bool {
        currentPhase?.kind == .work
    }

    private var currentRound: Int {
        guard let current = currentPhase else { return 1 }
        // Each work + rest is 1 round.
        let order = current.order
        return (order / 2) + 1
    }

    private var secondsLeft: Int {
        let remaining = timerManager.timeRemainingInCurrentPhase(at: currentDate)
        return max(0, Int(ceil(remaining)))
    }

    private var activeElapsed: Int {
        Int(timerManager.clock.activeElapsed(at: currentDate))
    }

    private var totalPlannedDuration: Int {
        Int(timerManager.totalDuration)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Top Status Bar
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("TABATA (\(config.rounds) RONDAS)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.red)
                    }

                    Spacer()

                    Text("Intervalo \(currentRound)/\(config.rounds)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }

                // Global Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray6))
                        let progress = Double(activeElapsed) / Double(max(1, totalPlannedDuration))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.red)
                            .frame(width: geo.size.width * max(0, min(1, progress)))
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            // Phase Pill
            HStack(spacing: 6) {
                Image(systemName: isWork ? "bolt.fill" : "cup.and.saucer.fill")
                Text(isWork ? "¡TRABAJO ACTIVO!" : "DESCANSO")
            }
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(isWork ? .green : .orange)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isWork ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
            .overlay(
                Capsule().stroke(isWork ? Color.green.opacity(0.4) : Color.orange.opacity(0.4), lineWidth: 1.5)
            )
            .clipShape(Capsule())

            // Giant Countdown Number
            VStack(spacing: 4) {
                Text(String(format: "%02d", secondsLeft))
                    .font(.system(size: 110, weight: .black, design: .monospaced))
                    .foregroundColor(isWork ? .green : .orange)
                    .contentTransition(.numericText())

                Text("SEGUNDOS RESTANTES DE \(isWork ? "TRABAJO" : "DESCANSO")")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
            }

            // Exercise Card
            if let ej = bloque.ejercicios.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("EJERCICIO TABATA")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    Text(ej.detalle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isWork ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                )
            }

            Spacer()

            // Controls
            VStack(spacing: 12) {
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
                             : timerManager.isPaused ? "CONTINUAR" : "INICIAR TABATA")
                    }
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(timerManager.isRunning && !timerManager.isPaused ? Color.orange : Color.green)
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)

                HStack {
                    Text("Ronda: \(currentRound) de \(config.rounds)")
                        .font(.system(size: 11, weight: .medium))
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
}
