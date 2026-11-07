import SwiftUI
import Combine

struct ForTimeTimerView: View {
    let bloque: Bloque
    let onComplete: (Int) -> Void

    @StateObject private var timerManager: TimerManager
    @State private var currentDate = Date()
    @State private var checkedItems: [Int: Bool] = [:]

    private let redrawTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(bloque: Bloque, onComplete: @escaping (Int) -> Void) {
        self.bloque = bloque
        self.onComplete = onComplete
        let plan = WorkoutPlan(bloque: bloque)
        _timerManager = StateObject(wrappedValue: TimerManager(plan: plan))
    }

    private var capSeconds: Int {
        (bloque.capMinutos ?? 15) * 60
    }

    private var activeElapsed: Int {
        Int(timerManager.clock.activeElapsed(at: currentDate))
    }

    private var completedCount: Int {
        checkedItems.values.filter { $0 }.count
    }

    var body: some View {
        VStack(spacing: 16) {
            // Top Status Bar
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 8, height: 8)
                        Text("FOR TIME (CAP \(bloque.capMinutos ?? 15) MIN)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.cyan)
                    }

                    Spacer()

                    Text("\(completedCount)/\(bloque.ejercicios.count) Ejercicios")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.cyan.opacity(0.15))
                        .cornerRadius(6)
                }

                // Progress Bar towards Cap
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray6))
                        let progress = Double(activeElapsed) / Double(max(1, capSeconds))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.cyan)
                            .frame(width: geo.size.width * max(0, min(1, progress)))
                    }
                }
                .frame(height: 6)
            }

            // Giant Stopwatch Display
            VStack(spacing: 2) {
                Text(formatTime(activeElapsed))
                    .font(.system(size: 72, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())

                Text("TIEMPO TRANSCURRIDO (CAP \(formatTime(capSeconds)))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
            }

            // Exercises Checklist
            VStack(alignment: .leading, spacing: 8) {
                Text("TOCA EL EJERCICIO CUANDO LO COMPLETES:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(bloque.ejercicios.indices, id: \.self) { idx in
                            let isChecked = checkedItems[idx] == true
                            let ej = bloque.ejercicios[idx]

                            Button {
                                checkedItems[idx] = !isChecked
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isChecked ? Color.cyan : Color(.systemGray5))
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
                                .background(isChecked ? Color.cyan.opacity(0.1) : Color(.secondarySystemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isChecked ? Color.cyan.opacity(0.3) : Color(.separator), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()

            // Controls
            HStack(spacing: 12) {
                Button {
                    if !timerManager.isRunning {
                        timerManager.start()
                    } else if timerManager.isPaused {
                        timerManager.resume()
                    } else {
                        timerManager.pause()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: timerManager.isRunning && !timerManager.isPaused ? "pause.fill" : "play.fill")
                        Text(timerManager.isRunning && !timerManager.isPaused ? "PAUSAR" : timerManager.isPaused ? "REANUDAR" : "INICIAR")
                    }
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)

                Button {
                    let elapsed = activeElapsed
                    timerManager.stop()
                    onComplete(elapsed)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                        Text("¡TERMINÉ!")
                    }
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
                .disabled(!timerManager.isRunning)
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
