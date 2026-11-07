import SwiftUI

/// Modal de celebración al completar un bloque o el día entero de entrenamiento.
/// Equivale a `src/components/WorkoutCompleteModal.tsx`.
struct WorkoutCompleteModalView: View {
    let data: WorkoutCompleteModalData
    let watchSummary: WatchSummary?
    let onNextBlock: () -> Void
    let onBackToDay: () -> Void

    init(
        data: WorkoutCompleteModalData,
        watchSummary: WatchSummary? = nil,
        onNextBlock: @escaping () -> Void,
        onBackToDay: @escaping () -> Void
    ) {
        self.data = data
        self.watchSummary = watchSummary
        self.onNextBlock = onNextBlock
        self.onBackToDay = onBackToDay
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Header Icon / Mascot
                if data.dayResult != nil {
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.15))
                            .frame(width: 70, height: 70)

                        MascotView(
                            stage: data.mascotStage,
                            mood: .proud,
                            size: 52
                        )
                    }
                    .padding(.top, 6)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 64, height: 64)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.green)
                    }
                    .padding(.top, 6)
                }

                VStack(spacing: 3) {
                    Text(data.dayResult != nil ? "¡DÍA DE ENTRENAMIENTO COMPLETADO!" : (data.isDayFinished ? "¡DÍA COMPLETADO!" : "¡BLOQUE FINALIZADO!"))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.green)
                        .tracking(1.2)

                    Text(data.bloque.nombre)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                // Stats grid
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("TIEMPO TOTAL")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.secondary)

                        Text(formatDuration(data.totalSeconds))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text("TIPO / RONDAS")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.orange)

                        Text(data.rounds != nil && data.rounds! > 0 ? "\(data.rounds!) Rondas" : "Completado")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                }

                if let watchSummary, watchSummary.averageHeartRate != nil || watchSummary.activeCalories != nil {
                    HStack(spacing: 16) {
                        if let bpm = watchSummary.averageHeartRate {
                            Label("\(Int(bpm.rounded())) ppm", systemImage: "heart.fill")
                                .foregroundColor(.red)
                        }
                        if let kcal = watchSummary.activeCalories {
                            Label("\(Int(kcal.rounded())) kcal", systemImage: "flame.fill")
                                .foregroundColor(.orange)
                        }
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .accessibilityElement(children: .combine)
                }

                // Resumen de Gamificación del Día (si cerró el día)
                if let dayResult = data.dayResult {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.yellow)
                            Text("¡DÍA COMPLETADO!")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.yellow)
                        }

                        HStack(spacing: 8) {
                            HStack(spacing: 3) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                Text("+\(dayResult.xpGained) XP")
                                    .font(.system(size: 11, weight: .black))
                            }
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.15))
                            .cornerRadius(12)

                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 9))
                                Text("Racha: \(dayResult.streakAfter) \(dayResult.streakAfter == 1 ? "día" : "días")")
                                    .font(.system(size: 11, weight: .black))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(12)
                        }

                        if dayResult.earnedFreeze {
                            Text("Ganaste un congelador para proteger tu racha.")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.cyan)
                        }

                        if dayResult.leveledUp {
                            Text("¡Subiste al nivel \(dayResult.levelAfter): \(dayResult.tierName)!")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green)
                        }

                        ForEach(dayResult.newAchievements) { a in
                            Text("Logro desbloqueado: \(a.title)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                    )
                }

                // Action buttons
                VStack(spacing: 8) {
                    if data.hasNextBlock {
                        Button(action: onNextBlock) {
                            HStack {
                                Text("Continuar al Siguiente Bloque")
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onBackToDay) {
                        Text("Volver a la Rutina del Día")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
        }
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        if mins > 0 {
            return String(format: "%d min %02d s", mins, secs)
        } else {
            return "\(secs) s"
        }
    }
}
