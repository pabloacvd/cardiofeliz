import Foundation

/// Desafíos semanales rotativos según el número de semana e historial previo.
/// Equivale a `src/gamification/challenges.ts`.

enum ChallengeUnit: String, Sendable, Hashable {
    case days = "días"
    case km = "km"
    case min = "min"
}

struct WeeklyChallenge: Sendable, Hashable, Identifiable {
    var id: String
    var title: String
    var description: String
    var unit: ChallengeUnit
    var weekStart: DateKey
    var target: Double
    var progress: Double
    /// 0 a 1.
    var ratio: Double
    var done: Bool
    var xp: Int
    /// Semana con vacaciones suficientes y sin cumplir: no cuenta en contra.
    var paused: Bool
    /// La semana en curso está de vacaciones: no se muestra.
    var hidden: Bool
}

private struct ChallengeDef {
    let id: String
    let title: String
    let description: String
    let target: Double
    let unit: ChallengeUnit
    let progress: @Sendable ([ActivityRecord]) -> Double
    let feasible: @Sendable ([ActivityRecord]) -> Bool
}

enum GameChallenges {
    private static func distinctDays(_ list: [ActivityRecord]) -> [DateKey] {
        Array(Set(list.map(\.occurredOn))).sorted()
    }

    private static func longestConsecutiveDays(_ days: [DateKey]) -> Int {
        var best = 0
        var run = 0
        var prev: DateKey? = nil
        for d in days {
            if let p = prev, GameDates.diffDays(d, p) == 1 {
                run += 1
            } else {
                run = 1
            }
            if run > best {
                best = run
            }
            prev = d
        }
        return best
    }

    private static let catalog: [ChallengeDef] = [
        ChallengeDef(
            id: "streak_3_days",
            title: "3 días seguidos",
            description: "Estate activa 3 días seguidos esta semana.",
            target: 3.0,
            unit: .days,
            progress: { w in Double(longestConsecutiveDays(distinctDays(w))) },
            feasible: { _ in true }
        ),
        ChallengeDef(
            id: "run_10_km",
            title: "Corré 10 km",
            description: "Sumá 10 km corridos esta semana.",
            target: 10.0,
            unit: .km,
            progress: { w in
                let km = w.filter(GameActivities.isRun).reduce(0.0) { $0 + ($1.distanceKm ?? 0.0) }
                return round(km * 100.0) / 100.0
            },
            feasible: { prior in
                prior.contains { GameActivities.isRun($0) && ($0.distanceKm ?? 0.0) > 0 }
            }
        ),
        ChallengeDef(
            id: "minutes_150",
            title: "150 minutos activos",
            description: "Sumá 150 minutos de actividad esta semana.",
            target: 150.0,
            unit: .min,
            progress: { w in
                let sec = w.reduce(0) { $0 + $1.durationSeconds }
                return round(Double(sec) / 60.0)
            },
            feasible: { _ in true }
        ),
        ChallengeDef(
            id: "morning_2_days",
            title: "Madrugadora",
            description: "Entrená 2 días antes del mediodía.",
            target: 2.0,
            unit: .days,
            progress: { w in
                let morningActivities = w.filter { a in
                    guard let h = GameActivities.startedHour(a) else { return false }
                    return h < GameConfig.Challenges.morningBeforeHour
                }
                return Double(distinctDays(morningActivities).count)
            },
            feasible: { prior in
                prior.contains { GameActivities.startedHour($0) != nil }
            }
        ),
        ChallengeDef(
            id: "long_run_40",
            title: "Corrida larga",
            description: "Hacé una corrida de 40 minutos o más.",
            target: 40.0,
            unit: .min,
            progress: { w in
                let runs = w.filter(GameActivities.isRun)
                guard !runs.isEmpty else { return 0.0 }
                let maxSec = runs.map(\.durationSeconds).max() ?? 0
                return round(Double(maxSec) / 60.0)
            },
            feasible: { _ in true }
        ),
        ChallengeDef(
            id: "active_days_5",
            title: "5 días en movimiento",
            description: "Estate activa 5 días distintos esta semana.",
            target: 5.0,
            unit: .days,
            progress: { w in Double(distinctDays(w).count) },
            feasible: { _ in true }
        )
    ]

    private static func pickDefinition(ws: DateKey, prior: [ActivityRecord]) -> ChallengeDef {
        let base = GameDates.weekNumber(ws)
        for i in 0..<catalog.count {
            let index = (((base + i) % catalog.count) + catalog.count) % catalog.count
            let def = catalog[index]
            if def.feasible(prior) {
                return def
            }
        }
        return catalog[0]
    }

    /// Desafío de la semana que contiene a `anyDay`.
    static func evaluateChallenge(ctx: GameContext, anyDay: DateKey? = nil) -> WeeklyChallenge {
        let d = anyDay ?? ctx.today
        let ws = GameDates.weekStart(d)
        let we = GameDates.weekEnd(d)
        let prior = ctx.activities.filter { $0.occurredOn < ws }
        let inWeek = ctx.activities.filter { $0.occurredOn >= ws && $0.occurredOn <= we }

        let def = pickDefinition(ws: ws, prior: prior)
        let progress = def.progress(inWeek)
        let done = progress >= def.target
        let paused = !done && GameVacations.vacationDaysInRange(from: ws, to: we, vacations: ctx.vacations) >= GameConfig.Week.vacationPauseMinDays
        let isCurrentWeek = ctx.today >= ws && ctx.today <= we

        return WeeklyChallenge(
            id: def.id,
            title: def.title,
            description: def.description,
            unit: def.unit,
            weekStart: ws,
            target: def.target,
            progress: progress,
            ratio: min(1.0, def.target > 0 ? progress / def.target : 0.0),
            done: done,
            xp: GameConfig.Xp.challenge,
            paused: paused,
            hidden: isCurrentWeek && GameVacations.isOnVacation(day: ctx.today, vacations: ctx.vacations)
        )
    }

    /// Desafíos de todas las semanas, desde la primera con actividad hasta la actual.
    static func challengeHistory(ctx: GameContext) -> [WeeklyChallenge] {
        guard !ctx.activities.isEmpty else { return [] }
        let first = ctx.activities.reduce(ctx.activities[0].occurredOn) { min, a in
            a.occurredOn < min ? a.occurredOn : min
        }
        var out: [WeeklyChallenge] = []
        let last = GameDates.weekStart(ctx.today)
        var ws = GameDates.weekStart(first)
        while ws <= last {
            out.append(evaluateChallenge(ctx: ctx, anyDay: ws))
            ws = GameDates.addDays(ws, 7)
        }
        return out
    }
}
