import { GAME_CONFIG } from './config';
import { eachDay, type DateKey } from './dates';
import { groupByDay, type GameContext } from './activities';
import { isOnVacation } from './vacations';

export interface StreakMilestone {
  day: DateKey;
  value: number;
}

export interface StreakResult {
  /** Días activos consecutivos vigentes (los congelados y las vacaciones no cortan ni suman). */
  current: number;
  best: number;
  /** Congeladores disponibles hoy. */
  freezes: number;
  freezesEarned: number;
  /** Días que un congelador salvó la racha. */
  freezesUsedOn: DateKey[];
  activeToday: boolean;
  /** Hay racha, hoy todavía no hubo actividad y no se está de vacaciones. */
  atRisk: boolean;
  lastActiveDay: DateKey | null;
  /** Hoy se ganó un congelador. */
  earnedFreezeToday: boolean;
  /** Cada vez que una racha alcanzó un hito con bonus de XP. */
  milestones: StreakMilestone[];
}

/**
 * Racha diaria. Cualquier actividad (entrenamiento, corrida o descanso activo) cuenta.
 *
 * - Un día sin actividad consume un congelador si hay; si no, la racha vuelve a 0.
 * - Los días de vacaciones se saltean: no suman, no cortan y no gastan congeladores.
 * - Hoy sin actividad todavía no corta la racha (queda "en riesgo").
 * - Se gana 1 congelador cada `freezeEvery` días de racha, con un máximo de `maxFreezes`.
 */
export function computeStreak(ctx: GameContext): StreakResult {
  const { freezeEvery, maxFreezes, milestoneBonusXp } = GAME_CONFIG.streak;
  const byDay = groupByDay(ctx.activities);
  const activeDays = [...byDay.keys()].sort();

  const result: StreakResult = {
    current: 0,
    best: 0,
    freezes: 0,
    freezesEarned: 0,
    freezesUsedOn: [],
    activeToday: byDay.has(ctx.today),
    atRisk: false,
    lastActiveDay: activeDays.length > 0 ? activeDays[activeDays.length - 1] : null,
    earnedFreezeToday: false,
    milestones: [],
  };
  if (activeDays.length === 0) return result;

  let streak = 0;
  let freezes = 0;

  for (const day of eachDay(activeDays[0], ctx.today)) {
    if (byDay.has(day)) {
      streak += 1;
      if (streak > result.best) result.best = streak;
      if (milestoneBonusXp[streak] !== undefined) result.milestones.push({ day, value: streak });
      if (streak % freezeEvery === 0 && freezes < maxFreezes) {
        freezes += 1;
        result.freezesEarned += 1;
        if (day === ctx.today) result.earnedFreezeToday = true;
      }
    } else if (isOnVacation(day, ctx.vacations) || day === ctx.today || streak === 0) {
      continue;
    } else if (freezes > 0) {
      freezes -= 1;
      result.freezesUsedOn.push(day);
    } else {
      streak = 0;
    }
  }

  result.current = streak;
  result.freezes = freezes;
  result.atRisk = streak > 0 && !result.activeToday && !isOnVacation(ctx.today, ctx.vacations);
  return result;
}
