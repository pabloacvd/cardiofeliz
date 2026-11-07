import Foundation

/// Resumen global del estado de juego derivado.
/// Equivale a `src/gamification/index.ts`.

struct GameSummary: Sendable, Hashable {
    var xp: XpBreakdown
    var level: LevelInfo
    var mascot: MascotStageDef
    var streak: StreakResult
    var weekly: WeeklyStreakResult
    var week: WeekProgress
    var challenge: WeeklyChallenge
    var missions: DailyMissions
    var achievements: [AchievementStatus]
    var vacation: VacationStatus
    var comeback: ComebackStatus
    var coach: CoachMessage
}

enum GameEngine {
    /// Normaliza el contexto (descarta datos inválidos o del futuro) y calcula todo el estado de juego.
    static func computeGameSummary(input: GameContext) -> GameSummary {
        let ctx = GameContext(
            activities: GameActivities.cleanActivities(input.activities, today: input.today),
            vacations: GameActivities.cleanVacations(input.vacations),
            today: input.today,
            weightKg: input.weightKg,
            displayName: input.displayName
        )

        let xp = GameXp.computeXp(ctx: ctx)
        let level = GameLevels.levelFromXp(xp.total)

        return GameSummary(
            xp: xp,
            level: level,
            mascot: GameLevels.mascotStage(level.level),
            streak: GameStreak.computeStreak(ctx: ctx),
            weekly: GameWeeks.computeWeeklyStreak(ctx: ctx),
            week: GameWeeks.weekProgress(ctx: ctx, anyDay: ctx.today),
            challenge: GameChallenges.evaluateChallenge(ctx: ctx),
            missions: GameMissions.evaluateMissions(ctx: ctx),
            achievements: GameAchievements.evaluateAchievements(ctx: ctx),
            vacation: GameVacations.vacationStatus(today: ctx.today, vacations: ctx.vacations),
            comeback: GameVacations.comebackStatus(today: ctx.today, vacations: ctx.vacations),
            coach: GameCoach.pickCoachMessage(ctx: ctx)
        )
    }
}
