import SwiftUI
import Combine

struct EmomTimerView: View {
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

    private var totalMinutes: Int {
        bloque.duracionMinutos ?? 15
    }

    private var currentPhaseIndex: Int {
        timerManager.currentPhaseIndex
    }

    private var currentMinute: Int {
        min(totalMinutes, currentPhaseIndex + 1)
    }

    private var currentExerciseIndex: Int {
        guard !bloque.ejercicios.isEmpty else { return 0 }
        return (currentMinute - 1) % bloque.ejercicios.count
    }

    private var currentExercise: Ejercicio? {
        guard !bloque.ejercicios.isEmpty else { return nil }
        return bloque.ejercicios[currentExerciseIndex]
    }

    private var nextExercise: Ejercicio? {
        guard !bloque.ejercicios.isEmpty, currentMinute < totalMinutes else { return nil }
        let nextIndex = currentMinute % bloque.ejercicios.count
        return bloque.ejercicios[nextIndex]
    }

    private var isRest: Bool {
        currentExercise?.esDescanso ?? false
    }

    private var secondsInMinute: Int {
        let remaining = timerManager.timeRemainingInCurrentPhase(at: currentDate)
        return max(0, Int(ceil(remaining)))
    }

    private var activeElapsed: Int {
        Int(timerManager.clock.activeElapsed(at: currentDate))
    }

    private var totalRounds: Int {
        guard !bloque.ejercicios.isEmpty else { return 1 }
        return Int(ceil(Double(totalMinutes) / Double(bloque.ejercicios.count)))
    }

    private var currentRound: Int {
        guard !bloque.ejercicios.isEmpty else { return 1 }
        return ((currentMinute - 1) / bloque.ejercicios.count) + 1
    }

    var body: some View {
        VStack(spacing: 20) {
            // Top Status Bar
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("EMOM (\(totalMinutes) MIN)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Text("Ronda \(currentRound)/\(totalRounds) • Min \(currentMinute)/\(totalMinutes)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
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
                        let progress = Double(currentMinute - 1 + (60 - secondsInMinute) / 60) / Double(totalMinutes)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green)
                            .frame(width: geo.size.width * max(0, min(1, progress)))
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            // Giant Countdown Clock
            VStack(spacing: 4) {
                Text(String(format: "00:%02d", secondsInMinute))
                    .font(.system(size: 80, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())

                Text("SEGUNDOS RESTANTES DEL MINUTO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
            }

            // Current Exercise Card
            if let currentExercise {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(isRest ? "DESCANSO ACTIVO" : "MINUTO \(currentMinute) - EN CURSO")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(isRest ? .orange : .green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(isRest ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                            .cornerRadius(6)

                        Spacer()

                        Text("M\(currentExerciseIndex + 1) de \(bloque.ejercicios.count)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Text(currentExercise.detalle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isRest ? Color.orange.opacity(0.1) : Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isRest ? Color.orange.opacity(0.4) : Color.green.opacity(0.3), lineWidth: 1)
                )
            }

            // Next Exercise Preview
            if let nextExercise {
                HStack(spacing: 8) {
                    Text("SIGUIENTE")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)

                    Text(nextExercise.detalle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(10)
            }

            Spacer()

            // Controls
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Play/Pause button
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
                                 : timerManager.isPaused ? "CONTINUAR" : "COMENZAR EMOM")
                        }
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(timerManager.isRunning && !timerManager.isPaused ? Color.orange : Color.green)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)

                    // Skip minute button
                    Button {
                        timerManager.next()
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14))
                            Text("+1 MIN")
                                .font(.system(size: 9, weight: .black))
                        }
                        .foregroundColor(.white)
                        .frame(width: 70)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .disabled(!timerManager.isRunning)
                }

                HStack {
                    Text("Tiempo total: \(formatTime(activeElapsed))")
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
