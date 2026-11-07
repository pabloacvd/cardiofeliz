import Foundation

/// Misiones diarias rotativas y evaluadas.
/// Equivale a `src/gamification/missions.ts`.

enum MissionId: String, CaseIterable, Sendable {
    case comebackEasy = "comeback_easy"
    case doRun = "do_run"
    case doWorkout = "do_workout"
    case longSession = "long_session"
    case activeRest = "active_rest"
    case anyActivity = "any_activity"

    var title: String {
        switch self {
        case .comebackEasy: return "Vuelta suave: 15 minutos de lo que quieras"
        case .doRun: return "Registrá tu corrida"
        case .doWorkout: return "Terminá un entrenamiento completo"
        case .longSession: return "Sumá 40 minutos activos"
        case .activeRest: return "Hacé un descanso activo (caminata o movilidad)"
        case .anyActivity: return "Moverte hoy: cualquier actividad cuenta"
        }
    }

    var xp: Int {
        switch self {
        case .comebackEasy: return 25
        case .doRun: return 30
        case .doWorkout: return 30
        case .longSession: return 25
        case .activeRest: return 15
        case .anyActivity: return 10
        }
    }

    func isDone(dayActivities: [ActivityRecord]) -> Bool {
        let minutesOf = Double(dayActivities.reduce(0) { $0 + $1.durationSeconds }) / 60.0
        switch self {
        case .comebackEasy:
            return minutesOf >= 15.0
        case .doRun:
            return dayActivities.contains(where: GameActivities.isRun)
        case .doWorkout:
            return dayActivities.contains(where: GameActivities.isWorkout)
        case .longSession:
            return minutesOf >= 40.0
        case .activeRest:
            return dayActivities.contains { $0.type == .activeRest }
        case .anyActivity:
            return !dayActivities.isEmpty
        }
    }
}

struct DailyMission: Sendable, Hashable, Identifiable {
    var id: String
    var title: String
    var xp: Int
    var done: Bool
}

struct DailyMissions: Sendable, Hashable {
    var day: DateKey
    var missions: [DailyMission]
    var allDone: Bool
    /// XP de las misiones cumplidas + bonus si se cumplieron todas.
    var xpEarned: Int
    /// De vacaciones: no hay misiones.
    var hidden: Bool
}

enum GameMissions {
    private static let maxMissions = 3

    /// Qué misiones se ofrecen en `day`. Se decide con lo ocurrido ANTES de ese día.
    static func pickDailyMissions(ctx: GameContext, day: DateKey? = nil) -> [MissionId] {
        let d = day ?? ctx.today
        if GameVacations.isOnVacation(day: d, vacations: ctx.vacations) {
            return []
        }

        let before = GameActivities.contextBefore(ctx, day: d)
        let week = GameWeeks.weekProgress(ctx: before, anyDay: d)
        var picks: [MissionId] = []

        if GameVacations.comebackStatus(today: d, vacations: ctx.vacations).active {
            picks.append(.comebackEasy)
        }
        if week.remainingRuns > 0 {
            picks.append(.doRun)
        }
        if week.remainingWorkouts > 0 {
            picks.append(.doWorkout)
        }

        // Rotación diaria determinista entre las opcionales.
        picks.append(GameDates.dayNumber(d) % 2 == 0 ? .longSession : .activeRest)
        picks.append(.anyActivity)

        return Array(picks.prefix(maxMissions))
    }

    static func evaluateMissions(ctx: GameContext, day: DateKey? = nil) -> DailyMissions {
        let d = day ?? ctx.today
        let ids = pickDailyMissions(ctx: ctx, day: d)
        let dayActivities = ctx.activities.filter { $0.occurredOn == d }

        let missions = ids.map { mid in
            DailyMission(
                id: mid.rawValue,
                title: mid.title,
                xp: mid.xp,
                done: mid.isDone(dayActivities: dayActivities)
            )
        }

        let allDone = !missions.isEmpty && missions.allSatisfy(\.done)
        let xpEarned = missions.filter(\.done).reduce(0) { $0 + $1.xp } + (allDone ? GameConfig.Xp.allMissionsBonus : 0)

        return DailyMissions(
            day: d,
            missions: missions,
            allDone: allDone,
            xpEarned: xpEarned,
            hidden: missions.isEmpty
        )
    }
}
