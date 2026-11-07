import Foundation

/// Mensajes contextuales del coach según el estado de juego.
/// Equivale a `src/gamification/coach.ts`.

enum CoachMood: String, Sendable, Hashable {
    case happy
    case proud
    case worried
    case recover
    case rest
    case welcome
}

struct CoachMessage: Sendable, Hashable {
    var id: String
    var mood: CoachMood
    var text: String
}

enum GameCoach {
    private static func plural(_ n: Int, _ one: String, _ many: String) -> String {
        "\(n) \(n == 1 ? one : many)"
    }

    /// Días completos sin actividad hasta ayer, sin contar los de vacaciones.
    private static func idleDays(ctx: GameContext, lastActive: DateKey) -> Int {
        let from = GameDates.addDays(lastActive, 1)
        let to = GameDates.addDays(ctx.today, -1)
        guard from <= to else { return 0 }
        let diff = GameDates.diffDays(to, from) + 1
        let vacDays = GameVacations.vacationDaysInRange(from: from, to: to, vacations: ctx.vacations)
        return max(0, diff - vacDays)
    }

    static func pickCoachMessage(ctx: GameContext) -> CoachMessage {
        let streak = GameStreak.computeStreak(ctx: ctx)
        let week = GameWeeks.weekProgress(ctx: ctx, anyDay: ctx.today)
        let name = ctx.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hi = (name != nil && !name!.isEmpty) ? "\(name!), " : ""

        if GameVacations.isOnVacation(day: ctx.today, vacations: ctx.vacations) {
            let status = GameVacations.vacationStatus(today: ctx.today, vacations: ctx.vacations)
            if status.longWarning {
                return CoachMessage(
                    id: "vacation_long",
                    mood: .rest,
                    text: "\(hi)llevás \(status.lengthDays) días de vacaciones. Tu racha está a salvo, pero cuando quieras volvemos de a poco."
                )
            }
            return CoachMessage(
                id: "vacation",
                mood: .rest,
                text: "\(hi)disfrutá tus vacaciones. Tu racha está congelada y no pierde nada."
            )
        }

        let comeback = GameVacations.comebackStatus(today: ctx.today, vacations: ctx.vacations)
        if comeback.active {
            return CoachMessage(
                id: "comeback",
                mood: .recover,
                text: "¡Hay que recuperar! \(hi)con 15 minutos alcanza para arrancar. Estos \(plural(comeback.daysLeft, "día", "días")) dan XP extra."
            )
        }

        guard let lastActive = streak.lastActiveDay else {
            let userSuffix = (name != nil && !name!.isEmpty) ? " \(name!)" : ""
            return CoachMessage(
                id: "welcome",
                mood: .welcome,
                text: "¡Hola\(userSuffix)! Hoy empieza tu racha. Un entrenamiento o una corrida de 30 minutos y arrancamos."
            )
        }

        let idle = idleDays(ctx: ctx, lastActive: lastActive)
        if !streak.activeToday && idle >= GameConfig.Coach.lapseDays {
            return CoachMessage(
                id: "lapse",
                mood: .worried,
                text: "\(hi)te extrañamos. Hace \(plural(idle, "día", "días")) que no nos vemos: hoy alcanza con algo cortito para volver."
            )
        }

        if streak.earnedFreezeToday {
            return CoachMessage(
                id: "freeze_earned",
                mood: .proud,
                text: "¡Ganaste un congelador! Si algún día no podés entrenar, él cuida tu racha de \(streak.current) días."
            )
        }

        if streak.atRisk {
            let safe = streak.freezes > 0
            return CoachMessage(
                id: safe ? "streak_risk_freeze" : "streak_risk",
                mood: .worried,
                text: safe
                    ? "\(hi)tu racha de \(streak.current) días no está en peligro: tenés un congelador. Igual, hoy es un buen día para moverte."
                    : "\(hi)tu racha de \(plural(streak.current, "día", "días")) está en juego. Un descanso activo de un toque la salva."
            )
        }

        if week.met && streak.activeToday {
            return CoachMessage(
                id: "week_met",
                mood: .proud,
                text: "¡Semana perfecta! Cumpliste \(week.workoutsGoal) entrenos y \(week.runsGoal) corridas. Todo lo que hagas ahora es de más."
            )
        }

        if streak.activeToday {
            var left: [String] = []
            if week.remainingWorkouts > 0 {
                left.append(plural(week.remainingWorkouts, "entreno", "entrenos"))
            }
            if week.remainingRuns > 0 {
                left.append(plural(week.remainingRuns, "corrida", "corridas"))
            }
            return CoachMessage(
                id: "done_today",
                mood: .happy,
                text: "\(hi)¡hoy ya sumaste! Para la meta de la semana te \(left.count > 1 ? "faltan" : "falta") \(left.joined(separator: " y "))."
            )
        }

        if week.remainingRuns > 0 && week.remainingWorkouts == 0 {
            return CoachMessage(
                id: "needs_run",
                mood: .happy,
                text: "\(hi)\(week.remainingRuns == 1 ? "te falta" : "te faltan") \(plural(week.remainingRuns, "corrida", "corridas")) para cerrar la semana. Hoy puede ser el día."
            )
        }

        if week.remainingWorkouts > 0 && week.remainingRuns == 0 {
            return CoachMessage(
                id: "needs_workout",
                mood: .happy,
                text: "\(hi)solo te \(week.remainingWorkouts == 1 ? "falta" : "faltan") \(plural(week.remainingWorkouts, "entreno", "entrenos")) para completar la semana."
            )
        }

        return CoachMessage(
            id: "default",
            mood: .happy,
            text: "\(hi)¡buen día para entrenar! Elegí tu rutina o registrá una corrida."
        )
    }
}
