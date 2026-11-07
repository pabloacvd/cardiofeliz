import SwiftUI

/// Historial de desafíos semanales (pasados y actual).
/// Equivale a `src/components/analytics/ChallengesHistory.tsx`.
struct ChallengesHistoryView: View {
    let currentChallenge: WeeklyChallenge
    let history: [WeeklyChallenge]

    private var completedCount: Int {
        history.filter(\.done).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)

                VStack(alignment: .leading, spacing: 1) {
                    Text("DESAFÍOS SEMANALES")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.secondary)

                    Text("\(completedCount) completado\(completedCount == 1 ? "" : "s") en total")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }

            if history.isEmpty {
                Text("No hay historial de desafíos aún.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(history.reversed(), id: \.weekStart) { c in
                        ChallengeHistoryRow(
                            challenge: c,
                            isCurrent: c.weekStart == currentChallenge.weekStart
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct ChallengeHistoryRow: View {
    let challenge: WeeklyChallenge
    let isCurrent: Bool

    private var statusIcon: String {
        if challenge.done { return "checkmark.circle.fill" }
        if challenge.paused { return "pause.circle.fill" }
        return "clock.fill"
    }

    private var statusColor: Color {
        if challenge.done { return .green }
        if challenge.paused { return .purple }
        return .cyan
    }

    private var progressText: String {
        let p = challenge.unit == .km ? String(format: "%.1f", challenge.progress) : "\(Int(challenge.progress))"
        let t = challenge.unit == .km ? String(format: "%.1f", challenge.target) : "\(Int(challenge.target))"
        return "\(p) / \(t) \(challenge.unit.rawValue)"
    }

    private var rowBgColor: Color {
        if challenge.done { return Color.green.opacity(0.06) }
        if challenge.paused { return Color.purple.opacity(0.06) }
        if isCurrent { return Color.cyan.opacity(0.06) }
        return Color.black.opacity(0.35)
    }

    private var rowBorderColor: Color {
        if challenge.done { return Color.green.opacity(0.2) }
        if challenge.paused { return Color.purple.opacity(0.2) }
        if isCurrent { return Color.cyan.opacity(0.2) }
        return Color.white.opacity(0.05)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("Semana \(challenge.weekStart)\(isCurrent ? " (Actual)" : "")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(progressText)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(statusColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.15))
                .cornerRadius(6)
        }
        .padding(10)
        .background(rowBgColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(rowBorderColor, lineWidth: 1)
        )
    }
}
