import SwiftUI

struct BlockBadgeView: View {
    let tipo: TipoBloque

    init(tipo: TipoBloque) {
        self.tipo = tipo
    }

    var body: some View {
        Text(tipo.rawValue)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15))
            .foregroundColor(badgeColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(badgeColor.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(6)
    }

    var badgeColor: Color {
        switch tipo {
        case .emom: return .green
        case .amrap: return .orange
        case .forTime: return .cyan
        case .tabata: return .red
        case .triserie: return .purple
        case .density: return .indigo
        case .finisher: return .orange
        case .hiitIntervals: return .pink
        }
    }
}

enum BlockMetaHelper {
    static func meta(for bloque: Bloque) -> String {
        switch bloque.tipo {
        case .emom:
            let mins = bloque.duracionMinutos ?? 15
            return "\(mins) min"
        case .amrap:
            let mins = bloque.duracionMinutos ?? 15
            return "\(mins) min"
        case .forTime:
            let cap = bloque.capMinutos ?? 15
            return "Cap \(cap) min"
        case .tabata:
            if let est = bloque.estructura, !est.isEmpty { return est }
            let cfg = TimerConfig.tabataConfig(for: bloque)
            return "\(cfg.workSeconds)s / \(cfg.restSeconds)s × \(cfg.rounds)"
        case .triserie, .density:
            let cfg = TimerConfig.triserieConfig(for: bloque)
            return cfg.restSeconds > 0 ? "\(cfg.rounds) Rondas · Descanso \(cfg.restSeconds)s" : "\(cfg.rounds) Rondas"
        case .finisher:
            let rounds = TimerConfig.finisherRounds(for: bloque)
            return "\(rounds) \(rounds == 1 ? "Ronda" : "Rondas")"
        case .hiitIntervals:
            let rounds = TimerConfig.finisherRounds(for: bloque)
            let steps = TimerConfig.finisherSteps(for: bloque)
            let total = TimerConfig.finisherTotalSeconds(steps)
            let roundsLabel = "\(rounds) \(rounds == 1 ? "Ronda" : "Rondas")"
            if let total {
                let mins = (Double(total) / 60.0 * 10).rounded() / 10
                return "\(mins) min · \(roundsLabel)"
            }
            return roundsLabel
        }
    }
}
