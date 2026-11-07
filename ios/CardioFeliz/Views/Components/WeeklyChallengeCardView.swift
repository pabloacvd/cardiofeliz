import SwiftUI

/// Tarjeta del desafío de la semana con barra de progreso y recompensa.
/// Equivale a `src/components/WeeklyChallengeCard.tsx`.
struct WeeklyChallengeCardView: View {
    let challenge: WeeklyChallenge

    var body: some View {
        if !challenge.hidden {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("DESAFÍO DE LA SEMANA")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.cyan)
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("+\(challenge.xp) XP")
                            .font(.system(size: 10, weight: .black))
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.12))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                    )
                }

                // Title & Description
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text(challenge.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                // Progress state
                if challenge.paused {
                    HStack(spacing: 8) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.purple)
                        Text("Pausado por modo vacaciones (no cuenta en contra).")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.purple.opacity(0.9))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.12))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
                } else if challenge.done {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.green)
                            Text("¡Desafío completado!")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        }

                        Spacer()

                        let progStr = challenge.unit == .km ? String(format: "%.1f", challenge.progress) : "\(Int(challenge.progress))"
                        let targStr = challenge.unit == .km ? String(format: "%.1f", challenge.target) : "\(Int(challenge.target))"
                        Text("\(progStr)/\(targStr) \(challenge.unit.rawValue)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Progreso")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            Spacer()

                            let progStr = challenge.unit == .km ? String(format: "%.1f", challenge.progress) : "\(Int(challenge.progress))"
                            let targStr = challenge.unit == .km ? String(format: "%.1f", challenge.target) : "\(Int(challenge.target))"
                            Text("\(progStr) / \(targStr) \(challenge.unit.rawValue)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }

                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.tertiarySystemBackground))
                                    .frame(height: 7)

                                let progress = min(1.0, max(0.0, challenge.ratio))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [.cyan, .green], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * progress, height: 7)
                            }
                        }
                        .frame(height: 7)
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
}
