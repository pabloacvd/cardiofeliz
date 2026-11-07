import SwiftUI
import Combine

struct AmrapTimerView: View {
    let bloque: Bloque
    let onComplete: (Int, Int) -> Void

    @StateObject private var timerManager: TimerManager
    @State private var currentDate = Date()
    @State private var roundsCompleted: Int = 0
    @State private var checkedExercises: [Int: Bool] = [:]

    private let redrawTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(bloque: Bloque, onComplete: @escaping (Int, Int) -> Void) {
        self.bloque = bloque
        self.onComplete = onComplete
        let plan = WorkoutPlan(bloque: bloque)
        _timerManager = StateObject(wrappedValue: TimerManager(plan: plan))
    }

    private var totalDurationSeconds: Int {
        (bloque.duracionMinutos ?? 15) * 60
    }

    private var secondsRemaining: Int {
        let remaining = timerManager.timeRemainingInCurrentPhase(at: currentDate)
        return max(0, Int(ceil(remaining)))
    }

    private var activeElapsed: Int {
        Int(timerManager.clock.activeElapsed(at: currentDate))
    }

    private var isLowTime: Bool {
        secondsRemaining <= 60 && secondsRemaining > 0
    }

    var body: some View {
        VStack(spacing: 16) {
            // Top Status Bar
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("AMRAP (\(bloque.duracionMinutos ?? 15) MIN)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    Text("\(roundsCompleted) Rondas Listas")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray6))
                        let progress = Double(totalDurationSeconds - secondsRemaining) / Double(max(1, totalDurationSeconds))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isLowTime ? Color.red : Color.orange)
                            .frame(width: geo.size.width * max(0, min(1, progress)))
                    }
                }
                .frame(height: 6)
            }

            // Giant Countdown Display
            VStack(spacing: 2) {
                Text(formatTime(secondsRemaining))
                    .font(.system(size: 72, weight: .black, design: .monospaced))
                    .foregroundColor(isLowTime ? .red : .white)
                    .contentTransition(.numericText())

                Text("TIEMPO RESTANTE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
            }

            // Round Counter Bar
            HStack(spacing: 12) {
                Button {
                    if roundsCompleted > 0 { roundsCompleted -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(roundsCompleted == 0)

                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("CONTEO DE RONDAS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("\(roundsCompleted) ")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.orange)
                        + Text("Completadas")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    SoundManager.shared.playGo()
                    roundsCompleted += 1
                    checkedExercises.removeAll()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("+1 Ronda")
                    }
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)

            // Exercises Checklist
            VStack(alignment: .leading, spacing: 8) {
                Text("CIRCUITO AMRAP (TOCA PARA MARCAR):")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(bloque.ejercicios.indices, id: \.self) { idx in
                            let isChecked = checkedExercises[idx] == true
                            let ej = bloque.ejercicios[idx]

                            Button {
                                toggleExercise(at: idx)
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isChecked ? Color.green : Color(.systemGray5))
                                            .frame(width: 26, height: 26)

                                        if isChecked {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .black))
                                                .foregroundColor(.black)
                                        } else {
                                            Text("\(idx + 1)")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Text(ej.detalle)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(isChecked ? .secondary : .primary)
                                        .strikethrough(isChecked)
                                        .multilineTextAlignment(.leading)

                                    Spacer()
                                }
                                .padding(10)
                                .background(isChecked ? Color.green.opacity(0.1) : Color(.secondarySystemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isChecked ? Color.green.opacity(0.3) : Color(.separator), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()

            // Controls
            VStack(spacing: 10) {
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
                             : timerManager.isPaused ? "CONTINUAR" : "INICIAR AMRAP")
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
                    Text("Tiempo transcurrido: \(formatTime(activeElapsed))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Terminar Bloque") {
                        let elapsed = activeElapsed
                        let rounds = roundsCompleted
                        timerManager.stop()
                        onComplete(elapsed, rounds)
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
                onComplete(activeElapsed, roundsCompleted)
            }
        }
    }

    private func toggleExercise(at index: Int) {
        checkedExercises[index] = !(checkedExercises[index] ?? false)

        let allChecked = bloque.ejercicios.indices.allSatisfy { checkedExercises[$0] == true }
        if allChecked {
            SoundManager.shared.playGo()
            roundsCompleted += 1
            checkedExercises.removeAll()
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
