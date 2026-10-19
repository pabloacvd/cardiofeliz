import type { Activity } from '../types/gamification';
import type { DiaEntrenamiento, TipoBloque } from '../types/workout';
import type { DateKey } from '../gamification/dates';

/** Un bloque terminado hoy. Se guarda hasta que termina el día (o hasta que cambia la fecha). */
export interface BlockProgressEntry {
  /** Fecha local en la que se completó el bloque. */
  date: DateKey;
  /** Momento exacto (ISO) en que se completó. */
  completedAt: string;
  durationSeconds: number;
  rounds?: number;
  tipoBloque: TipoBloque;
  bloqueNombre: string;
}

export type BlockProgress = Record<string, BlockProgressEntry>;

/** Datos de una actividad antes de calcular id, XP y calorías. */
export type ActivityDraft = Omit<Activity, 'id' | 'userId' | 'xpEarned' | 'caloriesKcal' | 'createdAt'>;

export function blockKey(diaId: string, blockIndex: number): string {
  return `${diaId}_bloque_${blockIndex}`;
}

/** Descarta los bloques que no se completaron hoy: cada día de entrenamiento empieza de cero. */
export function pruneBlockProgress(progress: BlockProgress, today: DateKey): BlockProgress {
  const out: BlockProgress = {};
  for (const [key, entry] of Object.entries(progress)) {
    if (entry.date === today) out[key] = entry;
  }
  return out;
}

/** El día está terminado cuando todos sus bloques están completados, sin importar el orden. */
export function isDayFinished(dia: DiaEntrenamiento, progress: BlockProgress): boolean {
  return dia.bloques.length > 0 && dia.bloques.every((_, i) => progress[blockKey(dia.id, i)] !== undefined);
}

/** Arma la actividad `workout_day` a partir de los bloques completados. */
export function buildWorkoutDayActivity(
  dia: DiaEntrenamiento,
  progress: BlockProgress,
  today: DateKey,
): ActivityDraft {
  const entries = dia.bloques
    .map((_, i) => progress[blockKey(dia.id, i)])
    .filter((e): e is BlockProgressEntry => e !== undefined);

  const durationSeconds = entries.reduce((sum, e) => sum + Math.max(0, Math.round(e.durationSeconds)), 0);
  const withRounds = entries.filter((e) => typeof e.rounds === 'number');
  const roundsTotal = withRounds.length > 0 ? withRounds.reduce((sum, e) => sum + (e.rounds ?? 0), 0) : null;

  // Inicio del día = el bloque que empezó primero (fin del bloque menos su duración).
  const starts = entries
    .map((e) => new Date(e.completedAt).getTime() - e.durationSeconds * 1000)
    .filter((t) => Number.isFinite(t));
  const startedAt = starts.length > 0 ? new Date(Math.min(...starts)).toISOString() : null;

  return {
    type: 'workout_day',
    occurredOn: today,
    startedAt,
    durationSeconds,
    dayId: dia.id,
    blocksCompleted: entries.length,
    roundsTotal,
  };
}

/** Días de entrenamiento terminados en la semana actual: 'today' si fue hoy, 'week' si fue antes. */
export function weekCompletedDays(
  activities: readonly Activity[],
  today: DateKey,
  weekStartKey: DateKey,
): Record<string, 'today' | 'week'> {
  const out: Record<string, 'today' | 'week'> = {};
  for (const a of activities) {
    if (a.type !== 'workout_day' || !a.dayId) continue;
    if (a.occurredOn < weekStartKey || a.occurredOn > today) continue;
    if (a.occurredOn === today) out[a.dayId] = 'today';
    else if (out[a.dayId] !== 'today') out[a.dayId] = 'week';
  }
  return out;
}
