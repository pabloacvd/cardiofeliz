import Foundation

/// Racha diaria, hitos y congeladores.
/// Equivale a `src/gamification/streak.ts`.

struct StreakMilestone: Sendable, Hashable {
    var day: DateKey
    var value: Int
}

struct StreakResult: Sendable, Hashable {
    /// Días activos consecutivos vigentes (los congelados y las vacaciones no cortan ni suman).
    var current: Int
    var best: Int
    /// Congeladores disponibles hoy.
    var freezes: Int
    var freezesEarned: Int
    /// Días que un congelador salvó la racha.
    var freezesUsedOn: [DateKey]
    var activeToday: Bool
    /// Hay racha, hoy todavía no hubo actividad y no se está de vacaciones.
    var atRisk: Bool
    var lastActiveDay: DateKey?
    /// Hoy se ganó un congelador.
    var earnedFreezeToday: Bool
    /// Cada vez que una racha alcanzó un hito con bonus de XP.
    var milestones: [StreakMilestone]
}

enum GameStreak {
    static func computeStreak(ctx: GameContext) -> StreakResult {
        let freezeEvery = GameConfig.Streak.freezeEvery
        let maxFreezes = GameConfig.Streak.maxFreezes
        let milestoneBonusXp = GameConfig.Streak.milestoneBonusXp

        let byDay = GameActivities.groupByDay(ctx.activities)
        let activeDays = byDay.keys.sorted()

        var result = StreakResult(
            current: 0,
            best: 0,
            freezes: 0,
            freezesEarned: 0,
            freezesUsedOn: [],
            activeToday: byDay[ctx.today] != nil,
            atRisk: false,
            lastActiveDay: activeDays.last,
            earnedFreezeToday: false,
            milestones: []
        )

        guard let firstActive = activeDays.first else { return result }

        var streak = 0
        var freezes = 0

        for day in GameDates.eachDay(firstActive, ctx.today) {
            if byDay[day] != nil {
                streak += 1
                if streak > result.best {
                    result.best = streak
                }
                if milestoneBonusXp[streak] != nil {
                    result.milestones.append(StreakMilestone(day: day, value: streak))
                }
                if streak % freezeEvery == 0 && freezes < maxFreezes {
                    freezes += 1
                    result.freezesEarned += 1
                    if day == ctx.today {
                        result.earnedFreezeToday = true
                    }
                }
            } else if GameVacations.isOnVacation(day: day, vacations: ctx.vacations) || day == ctx.today || streak == 0 {
                continue
            } else if freezes > 0 {
                freezes -= 1
                result.freezesUsedOn.append(day)
            } else {
                streak = 0
            }
        }

        result.current = streak
        result.freezes = freezes
        result.atRisk = streak > 0 && !result.activeToday && !GameVacations.isOnVacation(day: ctx.today, vacations: ctx.vacations)
        return result
    }
}
