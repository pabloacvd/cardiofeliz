import SwiftUI

public struct ContentView: View {
    @ObservedObject private var phone = PhoneConnector.shared
    @ObservedObject private var workout = WorkoutManager.shared

    public init() {}

    public var body: some View {
        let display = workout.display
        Group {
            if display.mode == .idle {
                idleView
            } else {
                runningView(display)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Sin entrenamiento

    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
                .accessibilityHidden(true)

            Text("CardioFeliz")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.green)

            // El plan (qué bloque y qué fases) se elige en el iPhone: el Watch no puede arrancar uno.
            Text("Inicia el entrenamiento en el iPhone.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)

            if !phone.isPhoneReachable {
                Label("iPhone fuera de alcance", systemImage: "iphone.slash")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }

            if let summary = workout.lastSummary {
                lastSummaryView(summary)
            }
        }
    }

    private func lastSummaryView(_ summary: WatchSummary) -> some View {
        VStack(spacing: 2) {
            Text("Último entrenamiento")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            HStack(spacing: 10) {
                if let bpm = summary.averageHeartRate {
                    Label("\(Int(bpm.rounded()))", systemImage: "heart.fill").foregroundColor(.red)
                }
                if let kcal = summary.activeCalories {
                    Label("\(Int(kcal.rounded()))", systemImage: "flame.fill").foregroundColor(.orange)
                }
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            if !summary.savedToHealth {
                Text("No se guardó en Salud")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
        }
        .padding(.top, 4)
    }

    // MARK: En curso

    private func runningView(_ display: WatchDisplay) -> some View {
        ScrollView {
            VStack(spacing: 6) {
                if let phase = display.phase {
                    Text(phase.name.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(color(for: phase.kind))
                        .multilineTextAlignment(.center)

                    if let detail = phase.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 12))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }

                Text(clock(display.seconds))
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundColor(display.mode == .paused ? .orange : .white)
                    .accessibilityLabel(accessibleTime(display))

                if display.mode == .paused {
                    Text("PAUSADO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                } else if display.mode == .finished {
                    Text("Terminando…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                metrics

                controls(display)

                if !phone.isPhoneReachable || phone.commandFailed {
                    Label(
                        phone.commandFailed ? "No se pudo enviar" : "iPhone fuera de alcance",
                        systemImage: "iphone.slash"
                    )
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var metrics: some View {
        switch workout.health {
        case .active:
            HStack(spacing: 12) {
                Label(workout.heartRate > 0 ? "\(Int(workout.heartRate.rounded()))" : "--", systemImage: "heart.fill")
                    .foregroundColor(.red)
                Label("\(Int(workout.activeCalories.rounded()))", systemImage: "flame.fill")
                    .foregroundColor(.orange)
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
        case .requestingAccess:
            Text("Esperando permiso de Salud…")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        case .denied:
            Text("Sin permiso de Salud: no se mide el pulso ni se guarda el entrenamiento")
                .font(.system(size: 10))
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
        case .unavailable:
            Text("Salud no disponible")
                .font(.system(size: 10))
                .foregroundColor(.orange)
        case .idle:
            EmptyView()
        }
    }

    private func controls(_ display: WatchDisplay) -> some View {
        HStack(spacing: 6) {
            if display.mode == .paused {
                button("play.fill", "Reanudar", .green) { phone.send(.resume) }
            } else {
                button("pause.fill", "Pausar", .orange) { phone.send(.pause) }
            }
            button(
                display.isManual ? "checkmark" : "forward.fill",
                display.isManual ? "Listo" : "Siguiente",
                .blue
            ) { phone.send(.next) }
            button("stop.fill", "Terminar", .red) { phone.send(.stop) }
        }
        .padding(.top, 4)
    }

    private func button(_ icon: String, _ label: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12))
        }
        .tint(tint)
        .accessibilityLabel(label)
    }

    // MARK: Formato

    private func color(for kind: PhaseKind) -> Color {
        switch kind {
        case .warmup: return .yellow
        case .work: return .red
        case .rest, .transition: return .blue
        }
    }

    private func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func accessibleTime(_ display: WatchDisplay) -> String {
        let m = display.seconds / 60, s = display.seconds % 60
        let time = m > 0 ? "\(m) minutos \(s) segundos" : "\(s) segundos"
        return display.showsElapsed ? "Transcurrido \(time)" : "Quedan \(time)"
    }
}
