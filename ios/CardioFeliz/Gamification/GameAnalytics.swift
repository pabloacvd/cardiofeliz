import Foundation

/// Agregaciones y cálculos estadísticos para las pantallas de progreso.
/// Equivale a `src/gamification/analytics.ts`.

struct DailyMinutesPoint: Sendable, Hashable, Identifiable {
    var id: String { date }
    var date: DateKey
    var label: String
    var workoutsMin: Int
    var runsMin: Int
    var restMin: Int
    var totalMin: Int
    var isVacation: Bool
}

struct WeeklyDataPoint: Sendable, Hashable, Identifiable {
    var id: String { weekStart }
    var weekStart: DateKey
    var weekEnd: DateKey
    var label: String
    var workouts: Int
    var runs: Int
    var workoutsMin: Int
    var runsMin: Int
    var restMin: Int
    var totalMin: Int
    var km: Double
    var calories: Int
    var met: Bool
    var paused: Bool
}

struct PacePoint: Sendable, Hashable, Identifiable {
    var id: String
    var date: DateKey
    var label: String
    var distanceKm: Double
    var durationMinutes: Int
    var paceMinKm: Double
    var paceFormatted: String
    var location: String
    var feeling: Int?
}

struct TypeDistributionPoint: Sendable, Hashable, Identifiable {
    var id: String { name }
    var name: String
    var value: Int
    var minutes: Int
    var colorHex: String
}

struct FeelingPoint: Sendable, Hashable, Identifiable {
    var id: String { "\(date)-\(label)" }
    var date: DateKey
    var label: String
    var feeling: Int
    var type: String
}

struct PersonalRecords: Sendable, Hashable {
    var bestStreakDays: Int
    var longestRunMinutes: Int
    var longestRunKm: Double
    var bestPaceMinKm: Double?
    var bestPaceFormatted: String?
    var maxRoundsAmrap: Int
    var mostActiveWeekMinutes: Int
    var mostActiveWeekLabel: String?
}

struct HeatmapDay: Sendable, Hashable, Identifiable {
    var id: String { date }
    var date: DateKey
    var dayOfMonth: Int
    /// 0 = Mon, 6 = Sun
    var dayOfWeek: Int
    var isCurrentMonth: Bool
    var isToday: Bool
    var isFuture: Bool
    var isVacation: Bool
    var minutes: Int
    var activitiesCount: Int
    /// 0 = 0min, 1 = 1-15min, 2 = 16-30min, 3 = 31-45min, 4 = >45min
    var intensity: Int
}

struct AnalyticsSummary: Sendable, Hashable {
    var totalXp: Int
    var level: LevelInfo
    var currentStreak: Int
    var bestStreak: Int
    var currentWeeklyStreak: Int
    var bestWeeklyStreak: Int
    var totalActivities: Int
    var totalWorkouts: Int
    var totalRuns: Int
    var totalActiveRest: Int
    var totalMinutes: Int
    var totalKm: Double
    var totalCalories: Int
    var thisWeek: WeekProgress
    var prevWeek: WeekProgress
    var records: PersonalRecords
}

enum GameAnalytics {
    private static let dayNames = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]

    static func formatPace(_ minPerKm: Double) -> String {
        let min = Int(floor(minPerKm))
        let sec = Int(round((minPerKm - Double(min)) * 60.0))
        let formattedSec = sec == 60 ? "00" : String(format: "%02d", sec)
        let formattedMin = sec == 60 ? min + 1 : min
        return "\(formattedMin):\(formattedSec) /km"
    }

    /// Agrupación diaria para los últimos N días hasta today.
    static func computeDailyMinutes(ctx: GameContext, daysCount: Int = 7) -> [DailyMinutesPoint] {
        var points: [DailyMinutesPoint] = []
        let startDay = GameDates.addDays(ctx.today, -(daysCount - 1))
        let days = GameDates.eachDay(startDay, ctx.today)

        for d in days {
            let list = ctx.activities.filter { $0.occurredOn == d }
            var workoutsMin = 0
            var runsMin = 0
            var restMin = 0

            for a in list {
                let m = Int(round(Double(a.durationSeconds) / 60.0))
                if GameActivities.isWorkout(a) {
                    workoutsMin += m
                } else if GameActivities.isRun(a) {
                    runsMin += m
                } else {
                    restMin += m
                }
            }

            let parts = d.split(separator: "-").compactMap { Int($0) }
            let dd = parts.count > 2 ? parts[2] : 1
            // 1970-01-01 was Thursday (index 4 in 0=Sun..6=Sat)
            let dayNum = GameDates.dayNumber(d)
            let weekday = (((dayNum + 4) % 7) + 7) % 7
            let dayLabel = "\(dayNames[weekday]) \(dd)"

            points.append(DailyMinutesPoint(
                date: d,
                label: dayLabel,
                workoutsMin: workoutsMin,
                runsMin: runsMin,
                restMin: restMin,
                totalMin: workoutsMin + runsMin + restMin,
                isVacation: GameVacations.isOnVacation(day: d, vacations: ctx.vacations)
            ))
        }

        return points
    }

    /// Agrupación semanal para las últimas N semanas.
    static func computeWeeklyHistory(ctx: GameContext, weeksCount: Int = 8) -> [WeeklyDataPoint] {
        var points: [WeeklyDataPoint] = []
        let currentWeekStart = GameDates.weekStart(ctx.today)

        for i in stride(from: weeksCount - 1, through: 0, by: -1) {
            let ws = GameDates.addDays(currentWeekStart, -i * 7)
            let we = GameDates.weekEnd(ws)
            let wp = GameWeeks.weekProgress(ctx: ctx, anyDay: ws)

            let inWeek = ctx.activities.filter { $0.occurredOn >= ws && $0.occurredOn <= we }
            var workoutsMin = 0
            var runsMin = 0
            var restMin = 0
            var calories = 0.0

            for a in inWeek {
                let m = Int(round(Double(a.durationSeconds) / 60.0))
                if GameActivities.isWorkout(a) {
                    workoutsMin += m
                } else if GameActivities.isRun(a) {
                    runsMin += m
                } else {
                    restMin += m
                }
                if let cal = a.caloriesKcal {
                    calories += cal
                }
            }

            let parts = ws.split(separator: "-").compactMap { Int($0) }
            let wsM = parts.count > 1 ? parts[1] : 1
            let wsD = parts.count > 2 ? parts[2] : 1
            let label = String(format: "%02d/%02d", wsD, wsM)

            points.append(WeeklyDataPoint(
                weekStart: ws,
                weekEnd: we,
                label: label,
                workouts: wp.workouts,
                runs: wp.runs,
                workoutsMin: workoutsMin,
                runsMin: runsMin,
                restMin: restMin,
                totalMin: workoutsMin + runsMin + restMin,
                km: round(wp.km * 10.0) / 10.0,
                calories: Int(round(calories)),
                met: wp.met,
                paused: wp.paused
            ))
        }

        return points
    }

    /// Historial de ritmo para corridas con distancia.
    static func computePaceHistory(ctx: GameContext) -> [PacePoint] {
        let runsWithKm = ctx.activities
            .filter { GameActivities.isRun($0) && ($0.distanceKm ?? 0.0) > 0 && $0.durationSeconds > 0 }
            .sorted { $0.occurredOn < $1.occurredOn }

        return runsWithKm.map { a in
            let km = a.distanceKm ?? 0.0
            let durationMin = Double(a.durationSeconds) / 60.0
            let paceMinKm = durationMin / km
            let parts = a.occurredOn.split(separator: "-").compactMap { Int($0) }
            let mm = parts.count > 1 ? parts[1] : 1
            let dd = parts.count > 2 ? parts[2] : 1

            let locStr: String
            switch a.runLocation {
            case .cinta: locStr = "Cinta"
            case .calle: locStr = "Calle"
            case .none: locStr = "Corrida"
            }

            return PacePoint(
                id: a.id,
                date: a.occurredOn,
                label: String(format: "%02d/%02d", dd, mm),
                distanceKm: round(km * 100.0) / 100.0,
                durationMinutes: Int(round(durationMin)),
                paceMinKm: round(paceMinKm * 100.0) / 100.0,
                paceFormatted: formatPace(paceMinKm),
                location: locStr,
                feeling: a.feeling
            )
        }
    }

    /// Distribución por tipo de actividad.
    static func computeTypeDistribution(ctx: GameContext) -> [TypeDistributionPoint] {
        var workoutsCount = 0
        var workoutsMin = 0
        var treadmillRunsCount = 0
        var treadmillRunsMin = 0
        var outdoorRunsCount = 0
        var outdoorRunsMin = 0
        var genericRunsCount = 0
        var genericRunsMin = 0
        var activeRestCount = 0
        var activeRestMin = 0

        for a in ctx.activities {
            let m = Int(round(Double(a.durationSeconds) / 60.0))
            if GameActivities.isWorkout(a) {
                workoutsCount += 1
                workoutsMin += m
            } else if GameActivities.isRun(a) {
                switch a.runLocation {
                case .cinta:
                    treadmillRunsCount += 1
                    treadmillRunsMin += m
                case .calle:
                    outdoorRunsCount += 1
                    outdoorRunsMin += m
                case .none:
                    genericRunsCount += 1
                    genericRunsMin += m
                }
            } else {
                activeRestCount += 1
                activeRestMin += m
            }
        }

        var result: [TypeDistributionPoint] = []
        if workoutsCount > 0 {
            result.append(TypeDistributionPoint(name: "Entrenamientos", value: workoutsCount, minutes: workoutsMin, colorHex: "#22c55e"))
        }
        if treadmillRunsCount > 0 {
            result.append(TypeDistributionPoint(name: "Corrida (Cinta)", value: treadmillRunsCount, minutes: treadmillRunsMin, colorHex: "#06b6d4"))
        }
        if outdoorRunsCount > 0 {
            result.append(TypeDistributionPoint(name: "Corrida (Calle)", value: outdoorRunsCount, minutes: outdoorRunsMin, colorHex: "#3b82f6"))
        }
        if genericRunsCount > 0 {
            result.append(TypeDistributionPoint(name: "Corridas", value: genericRunsCount, minutes: genericRunsMin, colorHex: "#0ea5e9"))
        }
        if activeRestCount > 0 {
            result.append(TypeDistributionPoint(name: "Descanso activo", value: activeRestCount, minutes: activeRestMin, colorHex: "#a855f7"))
        }

        return result
    }

    /// Tendencia de sensación (1-5).
    static func computeFeelingTrend(ctx: GameContext) -> [FeelingPoint] {
        let filtered = ctx.activities
            .filter { $0.feeling != nil && $0.feeling! >= 1 && $0.feeling! <= 5 }
            .sorted { $0.occurredOn < $1.occurredOn }
        let sliced = filtered.suffix(15)

        return sliced.map { a in
            let parts = a.occurredOn.split(separator: "-").compactMap { Int($0) }
            let mm = parts.count > 1 ? parts[1] : 1
            let dd = parts.count > 2 ? parts[2] : 1
            let typeStr = GameActivities.isWorkout(a) ? "Entreno" : GameActivities.isRun(a) ? "Corrida" : "Descanso"

            return FeelingPoint(
                date: a.occurredOn,
                label: String(format: "%02d/%02d", dd, mm),
                feeling: a.feeling!,
                type: typeStr
            )
        }
    }

    /// Récords personales calculados del historial.
    static func computePersonalRecords(ctx: GameContext) -> PersonalRecords {
        let streak = GameStreak.computeStreak(ctx: ctx)
        let runs = ctx.activities.filter(GameActivities.isRun)

        var longestRunMinutes = 0
        var longestRunKm = 0.0
        var bestPaceMinKm: Double? = nil
        var maxRoundsAmrap = 0

        for r in runs {
            let min = Int(round(Double(r.durationSeconds) / 60.0))
            let km = r.distanceKm ?? 0.0
            if min > longestRunMinutes { longestRunMinutes = min }
            if km > longestRunKm { longestRunKm = km }
            if km > 0 && min > 0 {
                let pace = Double(min) / km
                if bestPaceMinKm == nil || pace < bestPaceMinKm! {
                    bestPaceMinKm = pace
                }
            }
        }

        for a in ctx.activities {
            if let rounds = a.roundsTotal, rounds > maxRoundsAmrap {
                maxRoundsAmrap = rounds
            }
        }

        let weeks = computeWeeklyHistory(ctx: ctx, weeksCount: 24)
        var mostActiveWeekMinutes = 0
        var mostActiveWeekLabel: String? = nil

        for w in weeks {
            if w.totalMin > mostActiveWeekMinutes {
                mostActiveWeekMinutes = w.totalMin
                mostActiveWeekLabel = w.label
            }
        }

        return PersonalRecords(
            bestStreakDays: streak.best,
            longestRunMinutes: longestRunMinutes,
            longestRunKm: round(longestRunKm * 100.0) / 100.0,
            bestPaceMinKm: bestPaceMinKm.map { round($0 * 100.0) / 100.0 },
            bestPaceFormatted: bestPaceMinKm.map(formatPace),
            maxRoundsAmrap: maxRoundsAmrap,
            mostActiveWeekMinutes: mostActiveWeekMinutes,
            mostActiveWeekLabel: mostActiveWeekLabel
        )
    }

    /// Grilla para el heatmap mensual (mes actual o especificado).
    static func computeMonthlyHeatmap(ctx: GameContext, targetMonthDate: DateKey? = nil) -> [HeatmapDay] {
        let target = targetMonthDate ?? ctx.today
        let parts = target.split(separator: "-").compactMap { Int($0) }
        let year = parts.count > 0 ? parts[0] : 2026
        let month = parts.count > 1 ? parts[1] : 1

        let firstOfMonth = String(format: "%04d-%02d-01", year, month)
        // Days in month calculation
        var dateComps = DateComponents()
        dateComps.year = year
        dateComps.month = month + 1
        dateComps.day = 0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let lastDayNumber = cal.date(from: dateComps).flatMap { cal.component(.day, from: $0) } ?? 30
        let lastOfMonth = String(format: "%04d-%02d-%02d", year, month, lastDayNumber)

        let gridStart = GameDates.weekStart(firstOfMonth)
        let gridEnd = GameDates.weekEnd(lastOfMonth)

        let days = GameDates.eachDay(gridStart, gridEnd)
        var minutesByDay: [DateKey: (minutes: Int, count: Int)] = [:]

        for a in ctx.activities {
            let cur = minutesByDay[a.occurredOn] ?? (minutes: 0, count: 0)
            let m = Int(round(Double(a.durationSeconds) / 60.0))
            minutesByDay[a.occurredOn] = (minutes: cur.minutes + m, count: cur.count + 1)
        }

        return days.map { d in
            let dParts = d.split(separator: "-").compactMap { Int($0) }
            let m = dParts.count > 1 ? dParts[1] : 1
            let dayNum = dParts.count > 2 ? dParts[2] : 1
            let dayOfWeek = GameDates.weekdayIndex(d) // 0 = Mon, 6 = Sun
            let isCurrentMonth = (m == month)
            let isToday = (d == ctx.today)
            let isFuture = (d > ctx.today)
            let stats = minutesByDay[d] ?? (minutes: 0, count: 0)
            let min = stats.minutes

            let intensity: Int
            if min > 45 {
                intensity = 4
            } else if min >= 30 {
                intensity = 3
            } else if min >= 15 {
                intensity = 2
            } else if min > 0 {
                intensity = 1
            } else {
                intensity = 0
            }

            return HeatmapDay(
                date: d,
                dayOfMonth: dayNum,
                dayOfWeek: dayOfWeek,
                isCurrentMonth: isCurrentMonth,
                isToday: isToday,
                isFuture: isFuture,
                isVacation: GameVacations.isOnVacation(day: d, vacations: ctx.vacations),
                minutes: min,
                activitiesCount: stats.count,
                intensity: intensity
            )
        }
    }

    /// Resumen global para Analíticas.
    static func computeAnalyticsSummary(ctx: GameContext) -> AnalyticsSummary {
        let xp = GameXp.computeXp(ctx: ctx)
        let level = GameLevels.levelFromXp(xp.total)
        let streak = GameStreak.computeStreak(ctx: ctx)
        let weekly = GameWeeks.computeWeeklyStreak(ctx: ctx)
        let thisWeek = GameWeeks.weekProgress(ctx: ctx, anyDay: ctx.today)
        let prevWeekStart = GameDates.addDays(GameDates.weekStart(ctx.today), -7)
        let prevWeek = GameWeeks.weekProgress(ctx: ctx, anyDay: prevWeekStart)

        var totalMinutes = 0
        var totalKm = 0.0
        var totalCalories = 0.0
        var totalWorkouts = 0
        var totalRuns = 0
        var totalActiveRest = 0

        for a in ctx.activities {
            totalMinutes += Int(round(Double(a.durationSeconds) / 60.0))
            if let km = a.distanceKm { totalKm += km }
            if let cal = a.caloriesKcal { totalCalories += cal }
            if GameActivities.isWorkout(a) {
                totalWorkouts += 1
            } else if GameActivities.isRun(a) {
                totalRuns += 1
            } else {
                totalActiveRest += 1
            }
        }

        return AnalyticsSummary(
            totalXp: xp.total,
            level: level,
            currentStreak: streak.current,
            bestStreak: streak.best,
            currentWeeklyStreak: weekly.current,
            bestWeeklyStreak: weekly.best,
            totalActivities: ctx.activities.count,
            totalWorkouts: totalWorkouts,
            totalRuns: totalRuns,
            totalActiveRest: totalActiveRest,
            totalMinutes: totalMinutes,
            totalKm: round(totalKm * 10.0) / 10.0,
            totalCalories: Int(round(totalCalories)),
            thisWeek: thisWeek,
            prevWeek: prevWeek,
            records: computePersonalRecords(ctx: ctx)
        )
    }
}
