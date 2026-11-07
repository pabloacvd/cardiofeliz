import SwiftUI

/// Calendario de constancia mensual (Heatmap) en cuadrícula de 7 columnas (L a D).
/// Equivale a `src/components/analytics/HeatmapCalendar.tsx`.
struct HeatmapCalendarView: View {
    let days: [HeatmapDay]
    let monthName: String

    @State private var selectedDay: HeatmapDay? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdayHeaders = ["L", "M", "M", "J", "V", "S", "D"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header & Legend
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                    Text("CONSTANCIA (\(monthName.uppercased()))")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Legend
                HStack(spacing: 3) {
                    Text("Menos")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    HStack(spacing: 2) {
                        intensityColor(0).frame(width: 8, height: 8).cornerRadius(2)
                        intensityColor(1).frame(width: 8, height: 8).cornerRadius(2)
                        intensityColor(2).frame(width: 8, height: 8).cornerRadius(2)
                        intensityColor(3).frame(width: 8, height: 8).cornerRadius(2)
                        intensityColor(4).frame(width: 8, height: 8).cornerRadius(2)
                    }

                    Text("Más")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            // Grid
            VStack(spacing: 4) {
                // Day of week headers
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { idx in
                        Text(weekdayHeaders[idx])
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Days
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(days) { d in
                        let isSelected = selectedDay?.id == d.id

                        Button {
                            if isSelected {
                                selectedDay = nil
                            } else {
                                selectedDay = d
                            }
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(d.isVacation ? Color.purple.opacity(0.3) : intensityColor(d.intensity))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                d.isToday ? Color.cyan :
                                                isSelected ? Color.white :
                                                (d.isVacation ? Color.purple.opacity(0.5) : Color.white.opacity(0.06)),
                                                lineWidth: d.isToday || isSelected ? 2 : 1
                                            )
                                    )

                                Text("\(d.dayOfMonth)")
                                    .font(.system(size: 11, weight: d.intensity >= 3 ? .black : .semibold))
                                    .foregroundColor(d.isVacation ? .purple : (d.intensity >= 3 ? .white : .secondary))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                                if d.isVacation {
                                    Image(systemName: "beach.umbrella.fill")
                                        .font(.system(size: 7))
                                        .foregroundColor(.purple)
                                        .padding(2)
                                }
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .opacity(d.isCurrentMonth ? 1.0 : 0.25)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Selected day details popup
            if let selected = selectedDay {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.date)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)

                        if selected.isVacation {
                            Text("Modo vacaciones activo")
                                .font(.system(size: 11))
                                .foregroundColor(.purple)
                        } else if selected.minutes > 0 {
                            let actCount = selected.activitiesCount
                            Text("\(selected.minutes) min activos (\(actCount) \(actCount == 1 ? "actividad" : "actividades"))")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Sin actividades")
                                .font(.system(size: 11))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                    }

                    Spacer()

                    Button {
                        selectedDay = nil
                    } label: {
                        Text("Cerrar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
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

    private func intensityColor(_ level: Int) -> Color {
        switch level {
        case 0: return Color(.tertiarySystemBackground)
        case 1: return Color.green.opacity(0.25)
        case 2: return Color.green.opacity(0.5)
        case 3: return Color.green.opacity(0.8)
        case 4: return Color.green
        default: return Color(.tertiarySystemBackground)
        }
    }
}
