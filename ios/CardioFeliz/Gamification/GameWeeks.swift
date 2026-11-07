import Foundation

/// Progreso semanal y racha de semanas perfectas.
/// Equivale a `src/gamification/weeks.ts`.

enum WeekStatus: String, Sendable, Hashable {
    case met
    case paused
    case missed
    case inProgress = "in_progress"
}

struct WeekProgress: Sendable, Hashable {
    var weekStart: DateKey
    var weekEnd: DateKey
    var workouts: Int
    var runs: Int
    var workoutsGoal: Int
    var runsGoal: Int
    /// Para los anillos: nunca supera la meta.
    var workoutsCapped: Int
    var runsCapped: Int
    var remainingWorkouts: Int
    var remainingRuns: Int
    var met: Bool
    /// Semana con vacaciones suficientes: no suma ni rompe la racha semanal.
    var paused: Bool
    var status: WeekStatus
    var activeDays: Int
    var minutes: Int
    var km: Double
}

struct WeeklyStreakResult: Sendable, Hashable {
    var current: Int
    var best: Int
    /// Semanas con la meta cumplida (todo el historial).
    var perfectWeeks: Int
    /// Una entrada por semana, desde la primera con actividad hasta la actual.
    var weeks: [WeekProgress]
}

enum GameWeeks {
    /// Progreso de la semana (lunes a domingo) que contiene a `anyDay`.
    static func weekProgress(ctx: GameContext, anyDay: DateKey) -> WeekProgress {
        let start = GameDates.weekStart(anyDay)
        let end = GameDates.weekEnd(anyDay)
        let workoutsGoal = GameConfig.WeeklyGoal.workouts
        let runsGoal = GameConfig.WeeklyGoal.runs

        let inWeek = ctx.activities.filter { $0.occurredOn >= start && $0.occurredOn <= end }
        let workouts = inWeek.filter(GameActivities.isWorkout).count
        let runs = inWeek.filter(GameActivities.isRun).count
        let met = workouts >= workoutsGoal && runs >= runsGoal
        let paused = !met && GameVacations.vacationDaysInRange(from: start, to: end, vacations: ctx.vacations) >= GameConfig.Week.vacationPauseMinDays

        let status: WeekStatus
        if met {
            status = .met
        } else if paused {
            status = .paused
        } else if end < ctx.today {
            status = .missed
        } else {
            status = .inProgress
        }

        let distinctDays = Set(inWeek.map(\.occurredOn)).count
        let totalSeconds = inWeek.reduce(0) { $0 + Double($1.durationSeconds) }
        let totalKm = inWeek.reduce(0.0) { $0 + ($1.distanceKm ?? 0.0) }

        return WeekProgress(
            weekStart: start,
            weekEnd: end,
            workouts: workouts,
            runs: runs,
            workoutsGoal: workoutsGoal,
            runsGoal: runsGoal,
            workoutsCapped: min(workouts, workoutsGoal),
            runsCapped: min(runs, runsGoal),
            remainingWorkouts: max(0, workoutsGoal - workouts),
            remainingRuns: max(0, runsGoal - runs),
            met: met,
            paused: paused,
            status: status,
            activeDays: distinctDays,
            minutes: Int(round(totalSeconds / 60.0)),
            km: round(totalKm * 100.0) / 100.0
        )
    }

    /// Racha semanal: semanas consecutivas con la meta cumplida.
    /// Las semanas pausadas por vacaciones y la semana en curso (si aún no cumplió) no cortan la racha.
    static func computeWeeklyStreak(ctx: GameContext) -> WeeklyStreakResult {
        var result = WeeklyStreakResult(current: 0, best: 0, perfectWeeks: 0, weeks: [])
        guard !ctx.activities.isEmpty else { return result }

        let firstDay = ctx.activities.reduce(ctx.activities[0].occurredOn) { min, a in
            a.occurredOn < min ? a.occurredOn : min
        }
        let firstWeek = GameDates.weekStart(firstDay)
        let currentWeek = GameDates.weekStart(ctx.today)

        var streak = 0
        var ws = firstWeek
        while ws <= currentWeek {
            let wp = weekProgress(ctx: ctx, anyDay: ws)
            result.weeks.append(wp)
            if wp.status == .met {
                streak += 1
                result.perfectWeeks += 1
                if streak > result.best {
                    result.best = streak
                }
            } else if wp.status == .missed {
                streak = 0
            }
            ws = GameDates.addDays(ws, 7)
        }
        result.current = streak
        return result
    }
}
