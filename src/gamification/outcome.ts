import type { Activity } from '../types/gamification';
import { computeGameSummary } from './index';
import type { GameContext } from './activities';
import type { AchievementStatus } from './achievements';

export interface LogOutcome {
  /** XP total ganado por el registro (incluye bonus de misiones, desafíos o hitos que se desbloqueen). */
  xpGained: number;
  levelBefore: number;
  levelAfter: number;
  leveledUp: boolean;
  tierName: string;
  streakBefore: number;
  streakAfter: number;
  /** Se ganó un congelador gracias a este registro. */
  earnedFreeze: boolean;
  newAchievements: AchievementStatus[];
  /** Avance de la semana de la actividad (lunes a domingo). */
  weekRuns: number;
  runsGoal: number;
  weekWorkouts: number;
  workoutsGoal: number;
}

/**
 * Qué cambió al registrar una actividad: compara el estado de juego antes y después.
 * `before` y `after` deben tener el mismo `today`; `after` incluye la actividad nueva.
 */
export function logOutcome(before: GameContext, after: GameContext): LogOutcome {
  const b = computeGameSummary(before);
  const a = computeGameSummary(after);
  const alreadyUnlocked = new Set(b.achievements.filter((x) => x.unlocked).map((x) => x.id));

  return {
    xpGained: Math.max(0, a.xp.total - b.xp.total),
    levelBefore: b.level.level,
    levelAfter: a.level.level,
    leveledUp: a.level.level > b.level.level,
    tierName: a.level.tierName,
    streakBefore: b.streak.current,
    streakAfter: a.streak.current,
    earnedFreeze: a.streak.freezesEarned > b.streak.freezesEarned,
    newAchievements: a.achievements.filter((x) => x.unlocked && !alreadyUnlocked.has(x.id)),
    weekRuns: a.week.runs,
    runsGoal: a.week.runsGoal,
    weekWorkouts: a.week.workouts,
    workoutsGoal: a.week.workoutsGoal,
  };
}

/** Contexto "después" = contexto "antes" + la actividad nueva. */
export function withActivity(ctx: GameContext, activity: Activity): GameContext {
  return { ...ctx, activities: [...ctx.activities, activity] };
}
