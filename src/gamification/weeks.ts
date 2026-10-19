import { GAME_CONFIG } from './config';
import { addDays, weekEnd, weekStart, type DateKey } from './dates';
import { isRun, isWorkout, safeNumber, type GameContext } from './activities';
import { vacationDaysInRange } from './vacations';

export type WeekStatus = 'met' | 'paused' | 'missed' | 'in_progress';

export interface WeekProgress {
  weekStart: DateKey;
  weekEnd: DateKey;
  workouts: number;
  runs: number;
  workoutsGoal: number;
  runsGoal: number;
  /** Para los anillos: nunca supera la meta. */
  workoutsCapped: number;
  runsCapped: number;
  remainingWorkouts: number;
  remainingRuns: number;
  met: boolean;
  /** Semana con vacaciones suficientes: no suma ni rompe la racha semanal. */
  paused: boolean;
  status: WeekStatus;
  activeDays: number;
  minutes: number;
  km: number;
}

/** Progreso de la semana (lunes a domingo) que contiene a `anyDay`. */
export function weekProgress(ctx: GameContext, anyDay: DateKey): WeekProgress {
  const start = weekStart(anyDay);
  const end = weekEnd(anyDay);
  const { workouts: workoutsGoal, runs: runsGoal } = GAME_CONFIG.weeklyGoal;

  const inWeek = ctx.activities.filter((a) => a.occurredOn >= start && a.occurredOn <= end);
  const workouts = inWeek.filter(isWorkout).length;
  const runs = inWeek.filter(isRun).length;
  const met = workouts >= workoutsGoal && runs >= runsGoal;
  const paused =
    !met && vacationDaysInRange(start, end, ctx.vacations) >= GAME_CONFIG.week.vacationPauseMinDays;

  let status: WeekStatus;
  if (met) status = 'met';
  else if (paused) status = 'paused';
  else if (end < ctx.today) status = 'missed';
  else status = 'in_progress';

  return {
    weekStart: start,
    weekEnd: end,
    workouts,
    runs,
    workoutsGoal,
    runsGoal,
    workoutsCapped: Math.min(workouts, workoutsGoal),
    runsCapped: Math.min(runs, runsGoal),
    remainingWorkouts: Math.max(0, workoutsGoal - workouts),
    remainingRuns: Math.max(0, runsGoal - runs),
    met,
    paused,
    status,
    activeDays: new Set(inWeek.map((a) => a.occurredOn)).size,
    minutes: Math.round(inWeek.reduce((sum, a) => sum + safeNumber(a.durationSeconds), 0) / 60),
    km: Math.round(inWeek.reduce((sum, a) => sum + safeNumber(a.distanceKm), 0) * 100) / 100,
  };
}

export interface WeeklyStreakResult {
  current: number;
  best: number;
  /** Semanas con la meta cumplida (todo el historial). */
  perfectWeeks: number;
  /** Una entrada por semana, desde la primera con actividad hasta la actual. */
  weeks: WeekProgress[];
}

/**
 * Racha semanal: semanas consecutivas con la meta cumplida.
 * Las semanas pausadas por vacaciones y la semana en curso (si aún no cumplió) no cortan la racha.
 */
export function computeWeeklyStreak(ctx: GameContext): WeeklyStreakResult {
  const result: WeeklyStreakResult = { current: 0, best: 0, perfectWeeks: 0, weeks: [] };
  if (ctx.activities.length === 0) return result;

  const firstDay = ctx.activities.reduce(
    (min, a) => (a.occurredOn < min ? a.occurredOn : min),
    ctx.activities[0].occurredOn,
  );
  const firstWeek = weekStart(firstDay);
  const currentWeek = weekStart(ctx.today);

  let streak = 0;
  for (let ws = firstWeek; ws <= currentWeek; ws = addDays(ws, 7)) {
    const week = weekProgress(ctx, ws);
    result.weeks.push(week);
    if (week.status === 'met') {
      streak += 1;
      result.perfectWeeks += 1;
      if (streak > result.best) result.best = streak;
    } else if (week.status === 'missed') {
      streak = 0;
    }
  }
  result.current = streak;
  return result;
}
