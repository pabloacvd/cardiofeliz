import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

@main
struct CardioFelizWidgetBundle: WidgetBundle {
    var body: some Widget {
        CardioFelizWidgetLiveActivity()
    }
}

// MARK: - Contador

/// Una fase manual no tiene fin conocido: un rango `start...end` con start == end colapsaría a 0 s.
/// Se muestra el tiempo transcurrido con un tope lejano (el sistema lo dibuja solo, sin actualizaciones).
private let manualHorizon: TimeInterval = 24 * 3600

private func formatSeconds(_ value: TimeInterval) -> String {
    let total = max(0, Int(value.rounded(.down)))
    return String(format: "%02d:%02d", total / 60, total % 60)
}

/// El contador de la fase. Avanza solo con `Text(timerInterval:)`; la app no lo actualiza cada segundo.
private struct PhaseTimerText: View {
    let state: WorkoutAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Text(formatSeconds(state.frozenSeconds ?? 0))
                .monospacedDigit()
        } else if state.isManual {
            Text(timerInterval: state.currentPhaseStartDate...state.currentPhaseStartDate.addingTimeInterval(manualHorizon),
                 countsDown: false)
                .monospacedDigit()
        } else if state.countsUp {
            Text(timerInterval: state.currentPhaseStartDate...state.currentPhaseEndDate, countsDown: false)
                .monospacedDigit()
        } else {
            Text(timerInterval: state.currentPhaseStartDate...state.currentPhaseEndDate, countsDown: true)
                .monospacedDigit()
        }
    }
}

/// Texto corto para el lado derecho de la isla compacta.
private struct CompactTrailing: View {
    let state: WorkoutAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Image(systemName: "pause.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel("Pausado")
        } else {
            PhaseTimerText(state: state)
                .font(.caption)
                .foregroundStyle(.green)
                .frame(maxWidth: 52)
        }
    }
}

/// Pausa/reanuda y siguiente. Los ejecuta la app mediante App Intents.
private struct ControlButtons: View {
    let state: WorkoutAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            if state.isPaused {
                Button(intent: ResumeWorkoutIntent()) {
                    Label("Reanudar", systemImage: "play.fill")
                }
                .tint(.green)
            } else {
                Button(intent: PauseWorkoutIntent()) {
                    Label("Pausar", systemImage: "pause.fill")
                }
                .tint(.orange)
            }
            Button(intent: NextPhaseIntent()) {
                Label(state.isManual ? "Listo" : "Siguiente", systemImage: "forward.fill")
            }
            .tint(.blue)
        }
        .font(.subheadline)
        .buttonStyle(.borderedProminent)
    }
}

private func progressLabel(_ state: WorkoutAttributes.ContentState) -> String {
    "Fase \(state.phaseOrder + 1) de \(state.totalPhases)"
}

// MARK: - Live Activity

struct CardioFelizWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutAttributes.self) { context in
            // Pantalla de bloqueo y banner
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(context.attributes.workoutName)
                        .font(.headline)
                    Spacer()
                    Text(progressLabel(context.state))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.phaseName)
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                        if let detail = context.state.detail {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    PhaseTimerText(state: context.state)
                        .font(.largeTitle.bold())
                        .foregroundStyle(context.state.isPaused ? .orange : .primary)
                }

                ControlButtons(state: context.state)
            }
            .padding()
            .activityBackgroundTint(Color(.systemBackground))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.phaseName)
                            .font(.headline)
                            .foregroundStyle(.green)
                            .lineLimit(1)
                        Text(progressLabel(context.state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PhaseTimerText(state: context.state)
                        .font(.title2.bold())
                        .foregroundStyle(context.state.isPaused ? .orange : .primary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let detail = context.state.detail {
                            Text(detail)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                        ControlButtons(state: context.state)
                    }
                }
            } compactLeading: {
                Text(context.state.phaseName.prefix(4).uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            } compactTrailing: {
                CompactTrailing(state: context.state)
            } minimal: {
                if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Pausado")
                } else {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Entrenamiento en curso")
                }
            }
            .keylineTint(.green)
        }
    }
}
