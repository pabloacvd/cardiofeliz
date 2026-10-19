import type { Activity, VacationPeriod } from '../types/gamification';
import { isValidDateKey, type DateKey } from './dates';

export interface GameContext {
  activities: readonly Activity[];
  vacations: readonly VacationPeriod[];
  /** Fecha local de hoy (YYYY-MM-DD). Se inyecta para que el motor sea determinista. */
  today: DateKey;
  weightKg?: number | null;
  displayName?: string | null;
}

/** Descarta actividades con fecha inválida o futura (por ejemplo, un reloj desfasado). */
export function cleanActivities(activities: readonly Activity[], today: DateKey): Activity[] {
  return activities.filter((a) => isValidDateKey(a.occurredOn) && a.occurredOn <= today);
}

/** Descarta vacaciones con fechas inválidas o con fin anterior al inicio. */
export function cleanVacations(vacations: readonly VacationPeriod[]): VacationPeriod[] {
  return vacations.filter(
    (v) =>
      isValidDateKey(v.startOn) &&
      (v.endOn == null || (isValidDateKey(v.endOn) && v.endOn >= v.startOn)),
  );
}

export function groupByDay(activities: readonly Activity[]): Map<DateKey, Activity[]> {
  const map = new Map<DateKey, Activity[]>();
  for (const a of activities) {
    const list = map.get(a.occurredOn);
    if (list) list.push(a);
    else map.set(a.occurredOn, [a]);
  }
  return map;
}

export const isWorkout = (a: Activity): boolean => a.type === 'workout_day';
export const isRun = (a: Activity): boolean => a.type === 'run';

export function safeNumber(value: number | null | undefined): number {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? value : 0;
}

/** Hora local (0-23) en la que empezó la actividad, o null si no se informó o es inválida. */
export function startedHour(a: Activity): number | null {
  if (!a.startedAt) return null;
  const d = new Date(a.startedAt);
  return Number.isNaN(d.getTime()) ? null : d.getHours();
}

/**
 * Contexto "a la mañana de `day`": solo actividades anteriores a ese día y `today = day`.
 * Sirve para decidir qué misiones/desafíos se ofrecían ese día sin que las actividades
 * del propio día cambien la oferta.
 */
export function contextBefore(ctx: GameContext, day: DateKey): GameContext {
  return {
    ...ctx,
    activities: ctx.activities.filter((a) => a.occurredOn < day),
    today: day,
  };
}
