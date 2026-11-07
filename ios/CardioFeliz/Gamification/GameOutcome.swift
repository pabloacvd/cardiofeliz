import Foundation

/// Comparación de estado de juego antes y después de registrar una actividad.
/// Equivale a `src/gamification/outcome.ts`.

struct LogOutcome: Sendable, Hashable {
    /// XP total ganado por el registro (incluye bonus de misiones, desafíos o hitos que se desbloqueen).
    var xpGained: Int
    var levelBefore: Int
    var levelAfter: Int
    var leveledUp: Bool
    var tierName: String
    var streakBefore: Int
    var streakAfter: Int
    /// Se ganó un congelador gracias a este registro.
    var earnedFreeze: Bool
    var newAchievements: [AchievementStatus]
    /// Avance de la semana de la actividad (lunes a domingo).
    var weekRuns: Int
    var runsGoal: Int
    var weekWorkouts: Int
    var workoutsGoal: Int
}

enum GameOutcome {
    static func logOutcome(before: GameContext, after: GameContext) -> LogOutcome {
        let b = GameEngine.computeGameSummary(input: before)
        let a = GameEngine.computeGameSummary(input: after)
        let alreadyUnlocked = Set(b.achievements.filter(\.unlocked).map(\.id))

        return LogOutcome(
            xpGained: max(0, a.xp.total - b.xp.total),
            levelBefore: b.level.level,
            levelAfter: a.level.level,
            leveledUp: a.level.level > b.level.level,
            tierName: a.level.tierName,
            streakBefore: b.streak.current,
            streakAfter: a.streak.current,
            earnedFreeze: a.streak.freezesEarned > b.streak.freezesEarned,
            newAchievements: a.achievements.filter { $0.unlocked && !alreadyUnlocked.contains($0.id) },
            weekRuns: a.week.runs,
            runsGoal: a.week.runsGoal,
            weekWorkouts: a.week.workouts,
            workoutsGoal: a.week.workoutsGoal
        )
    }

    static func withActivity(ctx: GameContext, activity: ActivityRecord) -> GameContext {
        var copy = ctx
        copy.activities.append(activity)
        return copy
    }
}
