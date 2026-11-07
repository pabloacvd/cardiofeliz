import SwiftUI

/// Tarjeta de récords personales del usuario.
/// Equivale a `src/components/analytics/PersonalRecordsCard.tsx`.
struct PersonalRecordsCardView: View {
    let records: PersonalRecords

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.yellow)
                Text("RÉCORDS PERSONALES")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.secondary)
            }

            // Grid 2 columns
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                // Best streak
                RecordTile(
                    icon: "flame.fill",
                    iconColor: .orange,
                    title: "MEJOR RACHA",
                    value: "\(records.bestStreakDays) \(records.bestStreakDays == 1 ? "día" : "días")"
                )

                // Longest run
                let longestRunStr: String = {
                    if records.longestRunMinutes > 0 {
                        let kmSuffix = records.longestRunKm > 0 ? String(format: " (%.1f km)", records.longestRunKm) : ""
                        return "\(records.longestRunMinutes) min\(kmSuffix)"
                    }
                    return "—"
                }()
                RecordTile(
                    icon: "figure.run",
                    iconColor: .cyan,
                    title: "CORRIDA MÁS LARGA",
                    value: longestRunStr
                )

                // Best pace
                RecordTile(
                    icon: "speedometer",
                    iconColor: .blue,
                    title: "MEJOR RITMO",
                    value: records.bestPaceFormatted ?? "—"
                )

                // Max AMRAP rounds
                RecordTile(
                    icon: "repeat",
                    iconColor: .green,
                    title: "RÉCORD AMRAP",
                    value: records.maxRoundsAmrap > 0 ? "\(records.maxRoundsAmrap) rondas" : "—"
                )
            }

            // Most active week (full width)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.purple)
                    Text("SEMANA MÁS ACTIVA")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(records.mostActiveWeekMinutes > 0 ? "\(records.mostActiveWeekMinutes) min activos" : "—")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white)

                    Spacer()

                    if let label = records.mostActiveWeekLabel {
                        Text("Semana \(label)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
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

private struct RecordTile: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
