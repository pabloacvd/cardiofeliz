import Foundation

/// Catálogo y evaluación de logros del usuario.
/// Equivale a `src/gamification/achievements.ts`.

struct AchievementStatus: Sendable, Hashable, Identifiable {
    var id: String
    var title: String
    var description: String
    var unlocked: Bool
    var current: Double
    var target: Double
}

private struct Stats {
    let workouts: Double
    let runs: Double
    let totalKm: Double
    let longestRunMinutes: Double
    let bestStreak: Double
    let bestWeeklyStreak: Double
    let perfectWeeks: Double
    let freezesUsed: Double
    let earlyBird: Bool
    let returnedAfterGap: Bool
}

private struct AchievementDef {
    let id: String
    let title: String
    let description: String
    let target: Double
    let value: @Sendable (Stats) -> Double
}

enum GameAchievements {
    private static func gatherStats(ctx: GameContext) -> Stats {
        let streak = GameStreak.computeStreak(ctx: ctx)
        let weekly = GameWeeks.computeWeeklyStreak(ctx: ctx)

        let days = Array(Set(ctx.activities.map(\.occurredOn))).sorted()
        var returnedAfterGap = false
        if days.count > 1 {
            for i in 1..<days.count {
                if GameDates.diffDays(days[i], days[i - 1]) <= 1 { continue }
                let allBetween = GameDates.eachDay(days[i - 1], days[i])
                if allBetween.count > 2 {
                    let between = Array(allBetween.dropFirst().dropLast())
                    let idle = between.filter { !GameVacations.isOnVacation(day: $0, vacations: ctx.vacations) }.count
                    if idle >= GameConfig.Achievements.comebackGapDays {
                        returnedAfterGap = true
                        break
                    }
                }
            }
        }

        let runs = ctx.activities.filter(GameActivities.isRun)
        let totalKm = runs.reduce(0.0) { $0 + GameActivities.safeDouble($1.distanceKm) }
        let longestRunMin = runs.map { Double(GameActivities.safeInt($0.durationSeconds)) / 60.0 }.max() ?? 0.0

        let earlyBird = ctx.activities.contains { a in
            guard let h = GameActivities.startedHour(a) else { return false }
            return h < GameConfig.Achievements.earlyBirdBeforeHour
        }

        return Stats(
            workouts: Double(ctx.activities.filter(GameActivities.isWorkout).count),
            runs: Double(runs.count),
            totalKm: totalKm,
            longestRunMinutes: longestRunMin,
            bestStreak: Double(streak.best),
            bestWeeklyStreak: Double(weekly.best),
            perfectWeeks: Double(weekly.perfectWeeks),
            freezesUsed: Double(streak.freezesUsedOn.count),
            earlyBird: earlyBird,
            returnedAfterGap: returnedAfterGap
        )
    }

    private static let definitions: [AchievementDef] = {
        var list: [AchievementDef] = [
            AchievementDef(id: "first_workout", title: "Primer entreno", description: "Terminá tu primer día de entrenamiento.", target: 1.0, value: { $0.workouts }),
            AchievementDef(id: "first_run", title: "Primera corrida", description: "Registrá tu primera corrida.", target: 1.0, value: { $0.runs })
        ]

        for n in [3, 7, 14, 30, 60, 100] {
            list.append(AchievementDef(
                id: "streak_\(n)",
                title: "Racha de \(n) días",
                description: "Estate activa \(n) días seguidos.",
                target: Double(n),
                value: { $0.bestStreak }
            ))
        }

        list.append(AchievementDef(id: "perfect_week", title: "Semana perfecta", description: "Cumplí la meta de una semana completa.", target: 1.0, value: { $0.perfectWeeks }))
        list.append(AchievementDef(id: "perfect_weeks_4", title: "Un mes redondo", description: "Cumplí la meta 4 semanas seguidas.", target: 4.0, value: { $0.bestWeeklyStreak }))

        for n in [10, 25, 50] {
            list.append(AchievementDef(
                id: "workouts_\(n)",
                title: "\(n) entrenos",
                description: "Terminá \(n) días de entrenamiento.",
                target: Double(n),
                value: { $0.workouts }
            ))
        }

        for n in [50, 100, 250] {
            list.append(AchievementDef(
                id: "km_\(n)",
                title: "\(n) km corridos",
                description: "Sumá \(n) km corriendo.",
                target: Double(n),
                value: { $0.totalKm }
            ))
        }

        list.append(AchievementDef(id: "run_45", title: "Corrida de 45", description: "Corré 45 minutos o más de una vez.", target: 45.0, value: { $0.longestRunMinutes }))
        list.append(AchievementDef(id: "run_60", title: "Corrida de 60", description: "Corré 60 minutos o más de una vez.", target: 60.0, value: { $0.longestRunMinutes }))
        list.append(AchievementDef(id: "early_bird", title: "Madrugadora", description: "Entrená antes de las 8 de la mañana.", target: 1.0, value: { $0.earlyBird ? 1.0 : 0.0 }))
        list.append(AchievementDef(id: "comeback", title: "¡Volví!", description: "Retomá después de 7 días o más sin actividad.", target: 1.0, value: { $0.returnedAfterGap ? 1.0 : 0.0 }))
        list.append(AchievementDef(id: "freeze_used", title: "Salvada por un pelo", description: "Un congelador te salvó la racha.", target: 1.0, value: { $0.freezesUsed }))

        return list
    }()

    static func evaluateAchievements(ctx: GameContext) -> [AchievementStatus] {
        let stats = gatherStats(ctx: ctx)
        return definitions.map { def in
            let raw = def.value(stats)
            return AchievementStatus(
                id: def.id,
                title: def.title,
                description: def.description,
                unlocked: raw >= def.target,
                current: min(round(raw * 100.0) / 100.0, def.target),
                target: def.target
            )
        }
    }

    /// Logros desbloqueados ahora que todavía no estaban registrados.
    static func newlyUnlocked(ctx: GameContext, alreadyUnlockedIds: Set<String>) -> [AchievementStatus] {
        evaluateAchievements(ctx: ctx).filter { $0.unlocked && !alreadyUnlockedIds.contains($0.id) }
    }
}
