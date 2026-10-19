import { GAME_CONFIG } from './config';
import { addDays, diffDays, type DateKey } from './dates';
import type { GameContext } from './activities';
import { computeStreak } from './streak';
import { comebackStatus, isOnVacation, vacationDaysInRange, vacationStatus } from './vacations';
import { weekProgress } from './weeks';

export type CoachMood = 'happy' | 'proud' | 'worried' | 'recover' | 'rest' | 'welcome';

export interface CoachMessage {
  /** Identificador estable de la regla que se activó (útil para tests y analítica). */
  id: string;
  mood: CoachMood;
  text: string;
}

const plural = (n: number, one: string, many: string): string => `${n} ${n === 1 ? one : many}`;

/** Días completos sin actividad hasta ayer, sin contar los de vacaciones. */
function idleDays(ctx: GameContext, lastActive: DateKey): number {
  const from = addDays(lastActive, 1);
  const to = addDays(ctx.today, -1);
  if (from > to) return 0;
  return diffDays(to, from) + 1 - vacationDaysInRange(from, to, ctx.vacations);
}

/**
 * Mensaje del coach al abrir la app. Reglas por prioridad: vacaciones → regreso → ausencia →
 * congelador ganado → racha en riesgo → progreso del día/semana → ánimo general.
 */
export function pickCoachMessage(ctx: GameContext): CoachMessage {
  const streak = computeStreak(ctx);
  const week = weekProgress(ctx, ctx.today);
  const name = ctx.displayName?.trim();
  const hi = name ? `${name}, ` : '';

  if (isOnVacation(ctx.today, ctx.vacations)) {
    const status = vacationStatus(ctx.today, ctx.vacations);
    if (status.longWarning) {
      return {
        id: 'vacation_long',
        mood: 'rest',
        text: `${hi}llevás ${status.lengthDays} días de vacaciones. Tu racha está a salvo, pero cuando quieras volvemos de a poco.`,
      };
    }
    return {
      id: 'vacation',
      mood: 'rest',
      text: `${hi}disfrutá tus vacaciones. Tu racha está congelada y no pierde nada.`,
    };
  }

  const comeback = comebackStatus(ctx.today, ctx.vacations);
  if (comeback.active) {
    return {
      id: 'comeback',
      mood: 'recover',
      text: `¡Hay que recuperar! ${hi}con 15 minutos alcanza para arrancar. Estos ${plural(comeback.daysLeft, 'día', 'días')} dan XP extra.`,
    };
  }

  if (streak.lastActiveDay === null) {
    return {
      id: 'welcome',
      mood: 'welcome',
      text: `¡Hola${name ? ` ${name}` : ''}! Hoy empieza tu racha. Un entrenamiento o una corrida de 30 minutos y arrancamos.`,
    };
  }

  const idle = idleDays(ctx, streak.lastActiveDay);
  if (!streak.activeToday && idle >= GAME_CONFIG.coach.lapseDays) {
    return {
      id: 'lapse',
      mood: 'worried',
      text: `${hi}te extrañamos. Hace ${plural(idle, 'día', 'días')} que no nos vemos: hoy alcanza con algo cortito para volver.`,
    };
  }

  if (streak.earnedFreezeToday) {
    return {
      id: 'freeze_earned',
      mood: 'proud',
      text: `¡Ganaste un congelador! Si algún día no podés entrenar, él cuida tu racha de ${streak.current} días.`,
    };
  }

  if (streak.atRisk) {
    const safe = streak.freezes > 0;
    return {
      id: safe ? 'streak_risk_freeze' : 'streak_risk',
      mood: 'worried',
      text: safe
        ? `${hi}tu racha de ${streak.current} días no está en peligro: tenés un congelador. Igual, hoy es un buen día para moverte.`
        : `${hi}tu racha de ${plural(streak.current, 'día', 'días')} está en juego. Un descanso activo de un toque la salva.`,
    };
  }

  if (week.met && streak.activeToday) {
    return {
      id: 'week_met',
      mood: 'proud',
      text: `¡Semana perfecta! Cumpliste ${week.workoutsGoal} entrenos y ${week.runsGoal} corridas. Todo lo que hagas ahora es de más.`,
    };
  }

  if (streak.activeToday) {
    const left: string[] = [];
    if (week.remainingWorkouts > 0) left.push(plural(week.remainingWorkouts, 'entreno', 'entrenos'));
    if (week.remainingRuns > 0) left.push(plural(week.remainingRuns, 'corrida', 'corridas'));
    return {
      id: 'done_today',
      mood: 'happy',
      text: `${hi}¡hoy ya sumaste! Para la meta de la semana te ${left.length > 1 ? 'faltan' : 'falta'} ${left.join(' y ')}.`,
    };
  }

  if (week.remainingRuns > 0 && week.remainingWorkouts === 0) {
    return {
      id: 'needs_run',
      mood: 'happy',
      text: `${hi}${week.remainingRuns === 1 ? 'te falta' : 'te faltan'} ${plural(week.remainingRuns, 'corrida', 'corridas')} para cerrar la semana. Hoy puede ser el día.`,
    };
  }

  if (week.remainingWorkouts > 0 && week.remainingRuns === 0) {
    return {
      id: 'needs_workout',
      mood: 'happy',
      text: `${hi}solo te ${week.remainingWorkouts === 1 ? 'falta' : 'faltan'} ${plural(week.remainingWorkouts, 'entreno', 'entrenos')} para completar la semana.`,
    };
  }

  // Con racha vigente y sin actividad hoy, `streak.atRisk` ya respondió más arriba.
  return {
    id: 'default',
    mood: 'happy',
    text: `${hi}¡buen día para entrenar! Elegí tu rutina o registrá una corrida.`,
  };
}
