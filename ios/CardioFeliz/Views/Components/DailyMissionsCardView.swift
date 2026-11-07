import SwiftUI

/// Tarjeta de misiones diarias con checklist y recompensas en XP.
/// Equivale a `src/components/DailyMissionsCard.tsx`.
struct DailyMissionsCardView: View {
    let missions: DailyMissions

    var body: some View {
        if !missions.hidden && !missions.missions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("MISIONES DE HOY")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if missions.xpEarned > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("+\(missions.xpEarned) XP sumados")
                                .font(.system(size: 10, weight: .black))
                        }
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.yellow.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                        )
                    }
                }

                // Missions list
                VStack(spacing: 8) {
                    ForEach(missions.missions) { m in
                        HStack(spacing: 10) {
                            Image(systemName: m.done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(m.done ? .green : .secondary)

                            Text(m.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(m.done ? .secondary : .primary)
                                .strikethrough(m.done, color: .secondary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("+\(m.xp) XP")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(m.done ? .green : .secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(m.done ? Color.green.opacity(0.15) : Color(.tertiarySystemBackground))
                                .cornerRadius(6)
                        }
                        .padding(10)
                        .background(m.done ? Color.green.opacity(0.06) : Color.black.opacity(0.4))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(m.done ? Color.green.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                }

                // All done celebration
                if missions.allDone {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("¡Todas las misiones completadas! (+20 XP bonus)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.yellow.opacity(0.12))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
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
}
