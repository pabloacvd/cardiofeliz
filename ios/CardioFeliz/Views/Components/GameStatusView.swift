import SwiftUI

/// Vista de estado del juego: racha, congeladores, nivel, XP y anillos de la semana.
/// Equivale a `GameStatus` en `src/components/GameStatus.tsx`.
struct GameStatusView: View {
    let game: GameSummary
    var onOpenVacations: (() -> Void)?

    private var streakText: String {
        let n = game.streak.current
        return "\(n) \(n == 1 ? "día" : "días")"
    }

    private var xpLeft: Int {
        max(0, game.level.xpForNextLevel - game.level.xpIntoLevel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Badges row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Flame streak badge
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                        Text(streakText)
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(Color.orange.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )

                    // Freezes badge
                    HStack(spacing: 5) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("\(game.streak.freezes)")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(Color.cyan.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.12))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )

                    // Perfect weeks badge
                    if game.weekly.current > 0 {
                        let w = game.weekly.current
                        Text("\(w) \(w == 1 ? "semana" : "semanas") perfecta\(w == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }

                    // Vacation badge / button
                    if game.vacation.active {
                        Button {
                            onOpenVacations?()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "beach.umbrella.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.purple)
                                Text("De vacaciones")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color.purple.opacity(0.9))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.15))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    } else if let onOpenVacations {
                        Button {
                            onOpenVacations()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "beach.umbrella")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.purple)
                                Text("Vacaciones")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Streak at risk note
            if game.streak.atRisk {
                Text(game.streak.freezes > 0 ? "Hoy usarías un congelador si no entrenas." : "Sumá algo hoy para sostener la racha.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
            }

            // Level & XP bar
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 4) {
                        Text("Nivel \(game.level.level)")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.white)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(game.level.tierName)
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Text("\(game.level.totalXp) XP")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(.tertiarySystemBackground))
                            .frame(height: 8)

                        let progress = min(1.0, max(0.0, game.level.progress))
                        RoundedRectangle(cornerRadius: 5)
                            .fill(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)

                Text("Te faltan \(xpLeft) XP para el nivel \(game.level.level + 1).")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(.tertiaryLabel))
            }

            // Weekly goals rings
            VStack(alignment: .leading, spacing: 8) {
                Text("META DE LA SEMANA")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    Spacer()

                    WeeklyRingGauge(
                        label: "Entrenos",
                        value: game.week.workoutsCapped,
                        goal: game.week.workoutsGoal,
                        color: .green
                    )

                    WeeklyRingGauge(
                        label: "Corridas",
                        value: game.week.runsCapped,
                        goal: game.week.runsGoal,
                        color: .cyan
                    )

                    Spacer()
                }

                if game.week.met {
                    Text("¡Semana perfecta cumplida! 🎉")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
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

private struct WeeklyRingGauge: View {
    let label: String
    let value: Int
    let goal: Int
    let color: Color

    private var progress: Double {
        goal > 0 ? min(1.0, Double(value) / Double(goal)) : 0.0
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemBackground), lineWidth: 5)
                    .frame(width: 54, height: 54)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 54, height: 54)

                Text("\(value)/\(goal)")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white)
            }

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}
