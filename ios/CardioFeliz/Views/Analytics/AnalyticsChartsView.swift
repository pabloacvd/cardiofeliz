import SwiftUI
import Charts

/// Gráficos nativos de analíticas construidos con Swift Charts.
/// Equivale a `src/components/analytics/ActivityCharts.tsx`.

// MARK: - 1. Minutos Activos Bar Chart

struct MinutesBarChartView: View {
    let data: [DailyMinutesPoint]

    var body: some View {
        if data.isEmpty {
            emptyPlaceholder
        } else {
            Chart {
                ForEach(data) { pt in
                    if pt.workoutsMin > 0 {
                        BarMark(
                            x: .value("Fecha", pt.label),
                            y: .value("Minutos", pt.workoutsMin)
                        )
                        .foregroundStyle(Color.green)
                        .position(by: .value("Tipo", "Entrenos"))
                    }

                    if pt.runsMin > 0 {
                        BarMark(
                            x: .value("Fecha", pt.label),
                            y: .value("Minutos", pt.runsMin)
                        )
                        .foregroundStyle(Color.cyan)
                        .position(by: .value("Tipo", "Corridas"))
                    }

                    if pt.restMin > 0 {
                        BarMark(
                            x: .value("Fecha", pt.label),
                            y: .value("Minutos", pt.restMin)
                        )
                        .foregroundStyle(Color.purple)
                        .position(by: .value("Tipo", "Descanso"))
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .center)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
        }
    }

    private var emptyPlaceholder: some View {
        Text("Sin datos de minutos activos")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 100)
    }
}

// MARK: - 2. Km Corridos Bar Chart

struct KmBarChartView: View {
    let data: [WeeklyDataPoint]

    var body: some View {
        if data.isEmpty {
            emptyPlaceholder
        } else {
            Chart {
                ForEach(data) { pt in
                    BarMark(
                        x: .value("Semana", pt.label),
                        y: .value("Km", pt.km)
                    )
                    .foregroundStyle(Color.cyan.gradient)
                    .cornerRadius(4)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 160)
        }
    }

    private var emptyPlaceholder: some View {
        Text("Usá 'Hoy corrí' para ver tus km en el tiempo.")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 100)
    }
}

// MARK: - 3. Calorías Area / Line Chart

struct CaloriesAreaChartView: View {
    let data: [WeeklyDataPoint]

    var body: some View {
        if data.isEmpty {
            emptyPlaceholder
        } else {
            Chart {
                ForEach(data) { pt in
                    AreaMark(
                        x: .value("Semana", pt.label),
                        y: .value("Calorías", pt.calories)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.6), Color.orange.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Semana", pt.label),
                        y: .value("Calorías", pt.calories)
                    )
                    .foregroundStyle(Color.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Semana", pt.label),
                        y: .value("Calorías", pt.calories)
                    )
                    .foregroundStyle(Color.orange)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 160)
        }
    }

    private var emptyPlaceholder: some View {
        Text("Sin datos de calorías")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 100)
    }
}

// MARK: - 4. Ritmo Medio Line Chart

struct PaceLineChartView: View {
    let data: [PacePoint]

    var body: some View {
        if data.isEmpty {
            emptyPlaceholder
        } else {
            Chart {
                ForEach(data) { pt in
                    LineMark(
                        x: .value("Fecha", pt.label),
                        y: .value("Ritmo", pt.paceMinKm)
                    )
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("Fecha", pt.label),
                        y: .value("Ritmo", pt.paceMinKm)
                    )
                    .foregroundStyle(Color.blue)
                    .symbolSize(30)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 160)
        }
    }

    private var emptyPlaceholder: some View {
        Text("Sin datos de ritmo")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 100)
    }
}

// MARK: - 5. Distribución de Actividades (SectorMark / Pie)

struct TypeDistributionChartView: View {
    let data: [TypeDistributionPoint]

    var body: some View {
        if data.isEmpty {
            emptyPlaceholder
        } else {
            VStack(spacing: 12) {
                Chart {
                    ForEach(data) { pt in
                        SectorMark(
                            angle: .value("Cantidad", pt.value),
                            innerRadius: .ratio(0.55),
                            angularInset: 2.0
                        )
                        .foregroundStyle(colorForName(pt.name))
                        .cornerRadius(3)
                    }
                }
                .frame(height: 160)

                // Legend
                HStack(spacing: 16) {
                    ForEach(data) { pt in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(colorForName(pt.name))
                                .frame(width: 8, height: 8)
                            Text("\(pt.name): \(pt.value)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func colorForName(_ name: String) -> Color {
        if name.contains("Entrenamiento") { return .green }
        if name.contains("Cinta") { return .cyan }
        if name.contains("Calle") { return .blue }
        if name.contains("Corrida") { return .teal }
        if name.contains("Descanso") { return .purple }
        return .orange
    }

    private var emptyPlaceholder: some View {
        Text("Sin actividades registradas")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 100)
    }
}

// MARK: - 6. Tendencia de Sensación Line Chart

struct FeelingLineChartView: View {
    let data: [FeelingPoint]

    var body: some View {
        if data.isEmpty {
            emptyPlaceholder
        } else {
            Chart {
                ForEach(data) { pt in
                    LineMark(
                        x: .value("Fecha", pt.label),
                        y: .value("Sensación", pt.feeling)
                    )
                    .foregroundStyle(Color.pink)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Fecha", pt.label),
                        y: .value("Sensación", pt.feeling)
                    )
                    .foregroundStyle(Color.pink)
                    .symbolSize(25)
                }
            }
            .chartYScale(domain: 1...5)
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .frame(height: 140)
        }
    }

    private var emptyPlaceholder: some View {
        Text("Sin registros de sensación")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 100)
    }
}
