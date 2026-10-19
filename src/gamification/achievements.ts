import { GAME_CONFIG } from './config';
import { diffDays, eachDay } from './dates';
import { isRun, isWorkout, safeNumber, startedHour, type GameContext } from './activities';
import { computeStreak } from './streak';
import { isOnVacation } from './vacations';
import { computeWeeklyStreak } from './weeks';

export interface AchievementStatus {
  id: string;
  title: string;
  description: string;
  unlocked: boolean;
  current: number;
  target: number;
}

interface Stats {
  workouts: number;
  runs: number;
  totalKm: number;
  longestRunMinutes: number;
  bestStreak: number;
  bestWeeklyStreak: number;
  perfectWeeks: number;
  freezesUsed: number;
  earlyBird: boolean;
  returnedAfterGap: boolean;
}

function gatherStats(ctx: GameContext): Stats {
  const streak = computeStreak(ctx);
  const weekly = computeWeeklyStreak(ctx);

  const days = [...new Set(ctx.activities.map((a) => a.occurredOn))].sort();
  let returnedAfterGap = false;
  for (let i = 1; i < days.length && !returnedAfterGap; i++) {
    if (diffDays(days[i], days[i - 1]) <= 1) continue;
    const between = eachDay(days[i - 1], days[i]).slice(1, -1);
    const idle = between.filter((d) => !isOnVacation(d, ctx.vacations)).length;
    if (idle >= GAME_CONFIG.achievements.comebackGapDays) returnedAfterGap = true;
  }

  const runs = ctx.activities.filter(isRun);
  return {
    workouts: ctx.activities.filter(isWorkout).length,
    runs: runs.length,
    totalKm: runs.reduce((s, a) => s + safeNumber(a.distanceKm), 0),
    longestRunMinutes: Math.max(0, ...runs.map((a) => safeNumber(a.durationSeconds) / 60)),
    bestStreak: streak.best,
    bestWeeklyStreak: weekly.best,
    perfectWeeks: weekly.perfectWeeks,
    freezesUsed: streak.freezesUsedOn.length,
    earlyBird: ctx.activities.some((a) => {
      const h = startedHour(a);
      return h !== null && h < GAME_CONFIG.achievements.earlyBirdBeforeHour;
    }),
    returnedAfterGap,
  };
}

interface AchievementDef {
  id: string;
  title: string;
  description: string;
  target: number;
  value: (s: Stats) => number;
}

const flag = (b: boolean): number => (b ? 1 : 0);

const DEFS: readonly AchievementDef[] = [
  { id: 'first_workout', title: 'Primer entreno', description: 'Terminá tu primer día de entrenamiento.', target: 1, value: (s) => s.workouts },
  { id: 'first_run', title: 'Primera corrida', description: 'Registrá tu primera corrida.', target: 1, value: (s) => s.runs },
  ...[3, 7, 14, 30, 60, 100].map((n) => ({
    id: `streak_${n}`,
    title: `Racha de ${n} días`,
    description: `Estate activa ${n} días seguidos.`,
    target: n,
    value: (s: Stats) => s.bestStreak,
  })),
  { id: 'perfect_week', title: 'Semana perfecta', description: 'Cumplí la meta de una semana completa.', target: 1, value: (s) => s.perfectWeeks },
  { id: 'perfect_weeks_4', title: 'Un mes redondo', description: 'Cumplí la meta 4 semanas seguidas.', target: 4, value: (s) => s.bestWeeklyStreak },
  ...[10, 25, 50].map((n) => ({
    id: `workouts_${n}`,
    title: `${n} entrenos`,
    description: `Terminá ${n} días de entrenamiento.`,
    target: n,
    value: (s: Stats) => s.workouts,
  })),
  ...[50, 100, 250].map((n) => ({
    id: `km_${n}`,
    title: `${n} km corridos`,
    description: `Sumá ${n} km corriendo.`,
    target: n,
    value: (s: Stats) => s.totalKm,
  })),
  { id: 'run_45', title: 'Corrida de 45', description: 'Corré 45 minutos o más de una vez.', target: 45, value: (s) => s.longestRunMinutes },
  { id: 'run_60', title: 'Corrida de 60', description: 'Corré 60 minutos o más de una vez.', target: 60, value: (s) => s.longestRunMinutes },
  { id: 'early_bird', title: 'Madrugadora', description: 'Entrená antes de las 8 de la mañana.', target: 1, value: (s) => flag(s.earlyBird) },
  { id: 'comeback', title: '¡Volví!', description: 'Retomá después de 7 días o más sin actividad.', target: 1, value: (s) => flag(s.returnedAfterGap) },
  { id: 'freeze_used', title: 'Salvada por un pelo', description: 'Un congelador te salvó la racha.', target: 1, value: (s) => s.freezesUsed },
];

export function evaluateAchievements(ctx: GameContext): AchievementStatus[] {
  const stats = gatherStats(ctx);
  return DEFS.map((def) => {
    const raw = def.value(stats);
    return {
      id: def.id,
      title: def.title,
      description: def.description,
      unlocked: raw >= def.target,
      current: Math.min(Math.round(raw * 100) / 100, def.target),
      target: def.target,
    };
  });
}

/** Logros desbloqueados ahora que todavía no estaban registrados (para celebrarlos una sola vez). */
export function newlyUnlocked(
  ctx: GameContext,
  alreadyUnlockedIds: Iterable<string>,
): AchievementStatus[] {
  const known = new Set(alreadyUnlockedIds);
  return evaluateAchievements(ctx).filter((a) => a.unlocked && !known.has(a.id));
}
