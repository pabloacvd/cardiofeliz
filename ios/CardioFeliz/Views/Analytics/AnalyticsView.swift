import SwiftUI

/// Vista completa de Analíticas y Progreso del usuario.
/// Equivale a `src/views/AnalyticsView.tsx`.
struct AnalyticsView: View {
    @ObservedObject var activityStore: ActivityStore
    @ObservedObject var weightStore: ProfileWeightStore
    @ObservedObject var vacationsStore: VacationsStore
    @ObservedObject var achievementsStore: AchievementsStore
    @ObservedObject var session: SessionManager
    let onBack: () -> Void

    @State private var range: AnalyticsRange = .week
    @State private var isWeightSheetOpen: Bool = false
    @State private var isVacationSheetOpen: Bool = false

    enum AnalyticsRange: String, CaseIterable {
        case week = "Semana"
        case month = "Mes"
        case all = "Todo"
    }

    private var today: String {
        ActivityValidation.localDay(Date())
    }

    private var userName: String {
        if case .signedIn(_, let name) = session.state { return name }
        return "Usuario"
    }

    private var context: GameContext {
        GameContext(
            activities: activityStore.activities,
            vacations: vacationsStore.vacations,
            today: today,
            weightKg: weightStore.weightKg,
            displayName: userName
        )
    }

    private var game: GameSummary {
        GameEngine.computeGameSummary(input: context)
    }

    private var summary: AnalyticsSummary {
        GameAnalytics.computeAnalyticsSummary(ctx: context)
    }

    private var daily7: [DailyMinutesPoint] {
        GameAnalytics.computeDailyMinutes(ctx: context, daysCount: 7)
    }

    private var daily30: [DailyMinutesPoint] {
        GameAnalytics.computeDailyMinutes(ctx: context, daysCount: 30)
    }

    private var weeklyHistory: [WeeklyDataPoint] {
        GameAnalytics.computeWeeklyHistory(ctx: context, weeksCount: 8)
    }

    private var paceHistory: [PacePoint] {
        GameAnalytics.computePaceHistory(ctx: context)
    }

    private var typeDistribution: [TypeDistributionPoint] {
        GameAnalytics.computeTypeDistribution(ctx: context)
    }

    private var feelingTrend: [FeelingPoint] {
        GameAnalytics.computeFeelingTrend(ctx: context)
    }

    private var heatmap: [HeatmapDay] {
        GameAnalytics.computeMonthlyHeatmap(ctx: context, targetMonthDate: today)
    }

    private var activeMinutesRangeLabel: String {
        switch range {
        case .week: return "(ÚLTIMOS 7 DÍAS)"
        case .month: return "(ÚLTIMOS 30 DÍAS)"
        case .all: return "(ÚLTIMAS SEMANAS)"
        }
    }

    private var activeMinutesChartData: [DailyMinutesPoint] {
        switch range {
        case .week:
            return daily7
        case .month:
            return daily30
        case .all:
            return weeklyHistory.map {
                DailyMinutesPoint(
                    date: $0.weekStart,
                    label: $0.label,
                    workoutsMin: $0.workoutsMin,
                    runsMin: $0.runsMin,
                    restMin: $0.restMin,
                    totalMin: $0.totalMin,
                    isVacation: $0.paused
                )
            }
        }
    }

    private var challenges: [WeeklyChallenge] {
        GameChallenges.challengeHistory(ctx: context)
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: Date()).capitalized
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Top Header Navigation Bar
                HStack {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                            Text("Volver")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    HStack(spacing: 5) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                        Text("Analíticas y Progreso")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Range Selector
                    HStack(spacing: 2) {
                        ForEach(AnalyticsRange.allCases, id: \.self) { r in
                            Button {
                                range = r
                            } label: {
                                Text(r.rawValue)
                                    .font(.system(size: 10, weight: range == r ? .black : .medium))
                                    .foregroundColor(range == r ? .black : .secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(range == r ? Color.green : Color.clear)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(2)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                .padding(.bottom, 4)

                // Mascot & Level Hero Card
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )

                        MascotView(
                            stage: game.mascot.stage,
                            mood: game.coach.mood,
                            size: 48
                        )
                        .padding(6)
                    }
                    .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Nivel \(game.level.level):")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.white)
                            Text(game.level.tierName)
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.green)
                        }

                        Text("\(game.mascot.name) · \"\(game.mascot.catchphrase)\"")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.yellow.opacity(0.9))

                        // Progress bar
                        VStack(spacing: 2) {
                            HStack {
                                Text("\(game.level.xpIntoLevel) XP")
                                Spacer()
                                Text("\(game.level.xpForNextLevel) XP")
                            }
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.tertiarySystemBackground))
                                        .frame(height: 6)

                                    let pct = min(1.0, max(0.0, game.level.progress))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * pct, height: 6)
                                }
                            }
                            .frame(height: 6)
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

                // Quick Stats Grid (3 columns)
                HStack(spacing: 8) {
                    StatTile(
                        icon: "flame.fill",
                        iconColor: .orange,
                        title: "RACHA",
                        value: "\(summary.currentStreak) d",
                        subtitle: "Mejor: \(summary.bestStreak) d"
                    )

                    StatTile(
                        icon: "snowflake",
                        iconColor: .cyan,
                        title: "HIELOS",
                        value: "\(game.streak.freezes)",
                        subtitle: "Disponibles"
                    )

                    StatTile(
                        icon: "sparkles",
                        iconColor: .yellow,
                        title: "SEMANAS",
                        value: "\(summary.currentWeeklyStreak)",
                        subtitle: "Perfectas"
                    )
                }

                // Global Totals (3 columns)
                HStack(spacing: 8) {
                    TotalTile(
                        title: "MINUTOS",
                        value: "\(summary.totalMinutes) min",
                        valueColor: .green
                    )

                    TotalTile(
                        title: "DISTANCIA",
                        value: String(format: "%.1f km", summary.totalKm),
                        valueColor: .cyan
                    )

                    TotalTile(
                        title: "CALORÍAS",
                        value: summary.totalCalories > 0 ? "~\(summary.totalCalories)" : "—",
                        valueColor: .orange
                    )
                }

                // Weekly Comparison
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                        Text("META SEMANAL: ESTA SEMANA VS ANTERIOR")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        WeekComparisonBox(
                            title: "Esta Semana",
                            workoutsText: "\(summary.thisWeek.workouts)/\(summary.thisWeek.workoutsGoal)",
                            workoutsColor: .green,
                            runsText: "\(summary.thisWeek.runs)/\(summary.thisWeek.runsGoal)",
                            runsColor: .cyan
                        )

                        WeekComparisonBox(
                            title: "Semana Anterior",
                            workoutsText: "\(summary.prevWeek.workouts)/\(summary.prevWeek.workoutsGoal)",
                            workoutsColor: .white,
                            runsText: "\(summary.prevWeek.runs)/\(summary.prevWeek.runsGoal)",
                            runsColor: .white
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

                // Active Minutes Chart Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                        Text("MINUTOS ACTIVOS \(activeMinutesRangeLabel)")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.secondary)
                    }

                    MinutesBarChartView(data: activeMinutesChartData)
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                // Km Chart Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("KM CORRIDOS POR SEMANA")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.secondary)
                    }

                    KmBarChartView(data: weeklyHistory)
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                // Pace Chart Card (if runs exist)
                if !paceHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                            Text("EVOLUCIÓN DEL RITMO (MIN/KM)")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.secondary)
                        }

                        PaceLineChartView(data: paceHistory)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }

                // Calories Chart Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        Text("CALORÍAS ESTIMADAS (SEMANALES)")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.secondary)
                    }

                    if summary.totalCalories > 0 {
                        CaloriesAreaChartView(data: weeklyHistory)
                    } else {
                        VStack(spacing: 8) {
                            Text("Cargá tu peso corporal para calcular y visualizar las calorías quemadas.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button {
                                isWeightSheetOpen = true
                            } label: {
                                Text("Cargar peso")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                // Heatmap Calendar Card
                HeatmapCalendarView(days: heatmap, monthName: monthName)

                // Type Distribution Chart Card
                if !typeDistribution.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.purple)
                            Text("DISTRIBUCIÓN DE ACTIVIDADES")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.secondary)
                        }

                        TypeDistributionChartView(data: typeDistribution)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }

                // Feeling Trend Chart Card
                if !feelingTrend.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.pink)
                            Text("SENSACIÓN EN EL TIEMPO (1 = PESADO, 5 = EXCELENTE)")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.secondary)
                        }

                        FeelingLineChartView(data: feelingTrend)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }

                // Personal Records Card
                PersonalRecordsCardView(records: summary.records)

                // Achievements Gallery Card
                AchievementsGalleryView(
                    achievements: game.achievements,
                    unlockedAtMap: achievementsStore.unlockedAt
                )

                // Challenges History Card
                ChallengesHistoryView(
                    currentChallenge: game.challenge,
                    history: challenges
                )

                // Account & Settings Section
                AccountSectionView(
                    userName: userName,
                    weightKg: weightStore.weightKg,
                    onEditWeight: { isWeightSheetOpen = true },
                    onManageVacations: { isVacationSheetOpen = true },
                    isVacationActive: game.vacation.active,
                    onSignOut: {
                        Task { await session.signOut() }
                    }
                )
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $isVacationSheetOpen) {
            VacationSheetView(
                vacationsStore: vacationsStore,
                status: game.vacation,
                today: today,
                onClose: { isVacationSheetOpen = false }
            )
        }
        .sheet(isPresented: $isWeightSheetOpen) {
            WeightSheetView(
                initialKg: weightStore.weightKg,
                onSave: { kg in
                    weightStore.setWeightKg(kg)
                    activityStore.fillMissingCalories(weightKg: kg)
                    isWeightSheetOpen = false
                },
                onClose: { isWeightSheetOpen = false }
            )
        }
    }
}

// MARK: - Subcomponents

private struct StatTile: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 9))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct TotalTile: View {
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.4))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct WeekComparisonBox: View {
    let title: String
    let workoutsText: String
    let workoutsColor: Color
    let runsText: String
    let runsColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("Entrenos")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(workoutsText)
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(workoutsColor)
                }

                VStack(spacing: 2) {
                    Text("Corridas")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(runsText)
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(runsColor)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
    }
}
