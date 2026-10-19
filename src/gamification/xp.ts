import type { Activity } from '../types/gamification';
import { GAME_CONFIG } from './config';
import { groupByDay, safeNumber, type GameContext } from './activities';
import { challengeHistory } from './challenges';
import { evaluateMissions } from './missions';
import { computeStreak } from './streak';
import { comebackStatus } from './vacations';
import { computeWeeklyStreak } from './weeks';

/** XP base de una actividad, sin multiplicadores. */
export function activityBaseXp(activity: Pick<Activity, 'type' | 'durationSeconds' | 'blocksCompleted' | 'distanceKm'>): number {
  const xp = GAME_CONFIG.xp;
  switch (activity.type) {
    case 'workout_day': {
      const blocks = typeof activity.blocksCompleted === 'number' ? Math.max(0, Math.floor(activity.blocksCompleted)) : xp.baseBlocks;
      return xp.workoutDay + Math.max(0, blocks - xp.baseBlocks) * xp.extraBlock;
    }
    case 'run': {
      const minutes = safeNumber(activity.durationSeconds) / 60;
      const timeBonus = Math.min(
        xp.runMaxTimeBonus,
        Math.floor(Math.max(0, minutes - xp.runBaseMinutes) / xp.runStepMinutes),
      );
      return xp.run + timeBonus + (safeNumber(activity.distanceKm) > 0 ? xp.runKmBonus : 0);
    }
    case 'active_rest':
      return xp.activeRest;
    default:
      return 0;
  }
}

/**
 * XP que se guarda en la actividad al registrarla (`xp_earned`).
 * Incluye el bono de regreso si ese día cae en la ventana "¡Hay que recuperar!".
 */
export function computeActivityXp(ctx: GameContext, activity: Activity): number {
  const base = activityBaseXp(activity);
  const comeback = comebackStatus(activity.occurredOn, ctx.vacations).active;
  return comeback ? Math.round(base * GAME_CONFIG.vacation.comebackXpMultiplier) : base;
}

export interface XpBreakdown {
  total: number;
  activities: number;
  comebackBonus: number;
  perfectWeeks: number;
  challenges: number;
  missions: number;
  streakMilestones: number;
}

/**
 * XP total derivado del historial. No usa el `xpEarned` guardado: se recalcula con las reglas
 * vigentes, así un ajuste de reglas se refleja en todo el historial y todos los dispositivos coinciden.
 * Para no inflar XP, solo el primer descanso activo de cada día suma.
 */
export function computeXp(ctx: GameContext): XpBreakdown {
  let activitiesXp = 0;
  let comebackBonus = 0;

  for (const [day, list] of groupByDay(ctx.activities)) {
    const multiplier = comebackStatus(day, ctx.vacations).active ? GAME_CONFIG.vacation.comebackXpMultiplier : 1;
    let restCounted = false;
    for (const a of list) {
      if (a.type === 'active_rest') {
        if (restCounted) continue;
        restCounted = true;
      }
      const base = activityBaseXp(a);
      const boosted = Math.round(base * multiplier);
      activitiesXp += base;
      comebackBonus += boosted - base;
    }
  }

  const weekly = computeWeeklyStreak(ctx);
  const perfectWeeks = weekly.perfectWeeks * GAME_CONFIG.xp.perfectWeek;

  const challenges =
    challengeHistory(ctx).filter((c) => c.done).length * GAME_CONFIG.xp.challenge;

  const missions = [...groupByDay(ctx.activities).keys()].reduce(
    (sum, day) => sum + evaluateMissions(ctx, day).xpEarned,
    0,
  );

  const streakMilestones = computeStreak(ctx).milestones.reduce(
    (sum, m) => sum + (GAME_CONFIG.streak.milestoneBonusXp[m.value] ?? 0),
    0,
  );

  return {
    total: activitiesXp + comebackBonus + perfectWeeks + challenges + missions + streakMilestones,
    activities: activitiesXp,
    comebackBonus,
    perfectWeeks,
    challenges,
    missions,
    streakMilestones,
  };
}
