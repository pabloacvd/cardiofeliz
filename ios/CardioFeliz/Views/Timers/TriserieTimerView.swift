import SwiftUI
import Combine

struct TriserieTimerView: View {
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

    private var config: TriserieConfig {
        TimerConfig.triserieConfig(for: bloque)
    }

    private var currentPhase: WorkoutPhase? {
        timerManager.clock.currentPhase
    }

    private var isResting: Bool {
        currentPhase?.kind == .rest
    }

    private var currentExerciseIndex: Int {
        guard let current = currentPhase, !bloque.ejercicios.isEmpty else { return 0 }
        return current.order % (bloque.ejercicios.count + (config.restSeconds > 0 ? 1 : 0))
    }

    private var currentRound: Int {
        guard let current = currentPhase, !bloque.ejercicios.isEmpty else { return 1 }
        let roundPhases = bloque.ejercicios.count + (config.restSeconds > 0 ? 1 : 0)
        return min(config.rounds, (current.order / max(1, roundPhases)) + 1)
    }

    private var restSecondsLeft: Int {
        let remaining = timerManager.timeRemainingInCurrentPhase(at: currentDate)
        return max(0, Int(ceil(remaining)))
    }

    private var activeElapsed: Int {
        Int(timerManager.clock.activeElapsed(at: currentDate))
    }

    private var blockLabel: String {
        bloque.tipo == .density ? "DENSITY" : "TRISERIE METABÓLICA"
    }

    private var isLastExerciseOfRound: Bool {
        currentExerciseIndex == bloque.ejercicios.count - 1
    }

    private var isFinalRound: Bool {
        currentRound == config.rounds
    }

    var body: some View {
        VStack(spacing: 16) {
            // Top Status Bar
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 8, height: 8)
                        Text(blockLabel)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.purple)
                    }

                    Spacer()

                    Text("Ronda \(currentRound) de \(config.rounds)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(6)
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray6))
                        let totalPhases = timerManager.phases.count
                        let progress = Double(timerManager.currentPhaseIndex) / Double(max(1, totalPhases))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.purple)
                            .frame(width: geo.size.width * max(0, min(1, progress)))
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            if isResting {
                // Rest mode screen
                VStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "cup.and.saucer.fill")
                        Text("DESCANSO ENTRE RONDAS")
                    }
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(20)

                    Text(String(format: "%02d", restSecondsLeft))
                        .font(.system(size: 96, weight: .black, design: .monospaced))
                        .foregroundColor(.orange)
                        .contentTransition(.numericText())

                    Text("Prepárate para la Ronda \(min(config.rounds, currentRound + 1)) de \(config.rounds)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Button("Saltar Descanso") {
                        timerManager.next()
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.orange.opacity(0.3), lineWidth: 1))
            } else {
                // Active exercise list
                VStack(alignment: .leading, spacing: 8) {
                    Text("EJERCICIO \(currentExerciseIndex + 1) DE \(bloque.ejercicios.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1)

                    VStack(spacing: 8) {
                        ForEach(bloque.ejercicios.indices, id: \.self) { idx in
                            let isCurrent = idx == currentExerciseIndex
                            let isPast = idx < currentExerciseIndex
                            let ej = bloque.ejercicios[idx]

                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isCurrent ? Color.purple : isPast ? Color.green.opacity(0.2) : Color(.systemGray6))
                                        .frame(width: 32, height: 32)

                                    if isPast {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.green)
                                    } else {
                                        Text("\(idx + 1)")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(isCurrent ? .white : .secondary)
                                    }
                                }

                                Text(ej.detalle)
                                    .font(.system(size: 15, weight: isCurrent ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isCurrent ? .white : isPast ? .secondary : Color(.secondaryLabel))
                                    .multilineTextAlignment(.leading)

                                Spacer()
                            }
                            .padding(12)
                            .background(isCurrent ? Color.purple.opacity(0.15) : Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isCurrent ? Color.purple : Color.clear, lineWidth: 1.5)
                            )
                        }
                    }
                }
            }

            Spacer()

            // Controls
            VStack(spacing: 12) {
                if !isResting {
                    Button {
                        if !timerManager.isRunning {
                            timerManager.start()
                        } else {
                            timerManager.next()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(!timerManager.isRunning
                                 ? "COMENZAR \(bloque.tipo == .density ? "DENSITY" : "TRISERIE")"
                                 : isLastExerciseOfRound
                                 ? (isFinalRound ? "¡FINALIZAR \(bloque.tipo == .density ? "DENSITY" : "TRISERIE")!" : config.restSeconds > 0 ? "DESCANSO (\(config.restSeconds)s)" : "SIGUIENTE RONDA")
                                 : "SIGUIENTE EJERCICIO")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    if timerManager.isRunning {
                        Button {
                            if timerManager.isPaused {
                                timerManager.resume()
                            } else {
                                timerManager.pause()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: timerManager.isPaused ? "play.fill" : "pause.fill")
                                Text(timerManager.isPaused ? "Reanudar" : "Pausar")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

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
