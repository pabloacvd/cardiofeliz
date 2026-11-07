import Foundation

/// Cálculo de XP de actividades, misiones, desafíos, hitos y semanas perfectas.
/// Equivale a `src/gamification/xp.ts`.

struct XpBreakdown: Sendable, Hashable {
    var total: Int
    var activities: Int
    var comebackBonus: Int
    var perfectWeeks: Int
    var challenges: Int
    var missions: Int
    var streakMilestones: Int
}

enum GameXp {
    /// XP base de una actividad, sin multiplicadores.
    static func activityBaseXp(
        type: ActivityType,
        durationSeconds: Int,
        blocksCompleted: Int?,
        distanceKm: Double?
    ) -> Int {
        switch type {
        case .workoutDay:
            let blocks = blocksCompleted ?? GameConfig.Xp.baseBlocks
            return GameConfig.Xp.workoutDay + max(0, blocks - GameConfig.Xp.baseBlocks) * GameConfig.Xp.extraBlock
        case .run:
            let minutes = Double(durationSeconds) / 60.0
            let timeBonus = min(
                GameConfig.Xp.runMaxTimeBonus,
                Int(floor(max(0.0, minutes - Double(GameConfig.Xp.runBaseMinutes)) / Double(GameConfig.Xp.runStepMinutes)))
            )
            let kmBonus = (distanceKm ?? 0.0) > 0 ? GameConfig.Xp.runKmBonus : 0
            return GameConfig.Xp.run + timeBonus + kmBonus
        case .activeRest:
            return GameConfig.Xp.activeRest
        }
    }

    static func activityBaseXp(_ activity: ActivityRecord) -> Int {
        activityBaseXp(
            type: activity.type,
            durationSeconds: activity.durationSeconds,
            blocksCompleted: activity.blocksCompleted,
            distanceKm: activity.distanceKm
        )
    }

    /// XP que se guarda en la actividad al registrarla (`xp_earned`).
    /// Incluye el bono de regreso si ese día cae en la ventana "¡Hay que recuperar!".
    static func computeActivityXp(ctx: GameContext, activity: ActivityRecord) -> Int {
        let base = activityBaseXp(activity)
        let comeback = GameVacations.comebackStatus(today: activity.occurredOn, vacations: ctx.vacations).active
        return comeback ? Int(round(Double(base) * GameConfig.Vacation.comebackXpMultiplier)) : base
    }

    /// XP total derivado del historial.
    static func computeXp(ctx: GameContext) -> XpBreakdown {
        var activitiesXp = 0
        var comebackBonus = 0

        let byDay = GameActivities.groupByDay(ctx.activities)

        for (day, list) in byDay {
            let multiplier = GameVacations.comebackStatus(today: day, vacations: ctx.vacations).active
                ? GameConfig.Vacation.comebackXpMultiplier
                : 1.0
            var restCounted = false
            for a in list {
                if a.type == .activeRest {
                    if restCounted { continue }
                    restCounted = true
                }
                let base = activityBaseXp(a)
                let boosted = Int(round(Double(base) * multiplier))
                activitiesXp += base
                comebackBonus += (boosted - base)
            }
        }

        let weekly = GameWeeks.computeWeeklyStreak(ctx: ctx)
        let perfectWeeks = weekly.perfectWeeks * GameConfig.Xp.perfectWeek

        let challenges = GameChallenges.challengeHistory(ctx: ctx).filter(\.done).count * GameConfig.Xp.challenge

        let missions = byDay.keys.reduce(0) { sum, day in
            sum + GameMissions.evaluateMissions(ctx: ctx, day: day).xpEarned
        }

        let streakMilestones = GameStreak.computeStreak(ctx: ctx).milestones.reduce(0) { sum, m in
            sum + (GameConfig.Streak.milestoneBonusXp[m.value] ?? 0)
        }

        let total = activitiesXp + comebackBonus + perfectWeeks + challenges + missions + streakMilestones

        return XpBreakdown(
            total: total,
            activities: activitiesXp,
            comebackBonus: comebackBonus,
            perfectWeeks: perfectWeeks,
            challenges: challenges,
            missions: missions,
            streakMilestones: streakMilestones
        )
    }
}
