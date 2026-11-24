import type { Activity, RunLocation } from '../types/gamification';
import { GAME_CONFIG, addDays, sanitizeWeight } from '../gamification';
import { isValidDateKey, type DateKey } from '../gamification/dates';

export const RUN_MIN_MINUTES = 1;
export const RUN_MAX_MINUTES = 300;
export const RUN_MIN_KM = 0.1;
export const RUN_MAX_KM = 100;
/** Cuántos días hacia atrás se puede registrar una corrida. */
export const MAX_BACKDATE_DAYS = 30;

export type FormExerciseType = 'run' | 'workout_day';

export interface RunFormValues {
  exerciseType?: FormExerciseType;
  dayId?: string | null;
  minutes: string;
  km: string;
  location: RunLocation | null;
  feeling: number | null;
  date: DateKey;
}

export type RunFormErrors = Partial<Record<'minutes' | 'km' | 'date' | 'dayId', string>>;

export interface RunFields {
  exerciseType: FormExerciseType;
  dayId: string | null;
  durationSeconds: number;
  distanceKm: number | null;
  runLocation: RunLocation | null;
  feeling: number | null;
  occurredOn: DateKey;
}

export type RunFormResult = { ok: true; fields: RunFields } | { ok: false; errors: RunFormErrors };

export function defaultRunForm(today: DateKey, defaultDayId?: string | null): RunFormValues {
  return {
    exerciseType: 'run',
    dayId: defaultDayId ?? null,
    minutes: String(GAME_CONFIG.defaultRunMinutes),
    km: '',
    location: null,
    feeling: null,
    date: today,
  };
}

export function runFormFromActivity(a: Activity): RunFormValues {
  return {
    exerciseType: a.type === 'workout_day' ? 'workout_day' : 'run',
    dayId: a.dayId ?? null,
    minutes: String(Math.max(1, Math.round(a.durationSeconds / 60))),
    km: a.distanceKm ? String(a.distanceKm) : '',
    location: a.runLocation ?? null,
    feeling: a.feeling ?? null,
    date: a.occurredOn,
  };
}

/** Número decimal escrito por una persona: acepta coma o punto. null si está vacío o no es un número. */
export function parseDecimal(text: string): number | null {
  const clean = text.trim().replace(',', '.');
  if (!/^\d+(\.\d+)?$/.test(clean)) return null;
  const value = Number(clean);
  return Number.isFinite(value) ? value : null;
}

/** Peso en kg dentro del rango válido, o null. */
export function parseWeight(text: string): number | null {
  const value = parseDecimal(text);
  return value === null ? null : sanitizeWeight(value);
}

export function validateRunForm(values: RunFormValues, today: DateKey): RunFormResult {
  const errors: RunFormErrors = {};
  const exerciseType: FormExerciseType = values.exerciseType ?? 'run';

  const minutesText = values.minutes.trim();
  const minutes = /^\d+$/.test(minutesText) ? Number(minutesText) : null;
  if (minutes === null || minutes < RUN_MIN_MINUTES || minutes > RUN_MAX_MINUTES) {
    errors.minutes = `Ingresá minutos enteros entre ${RUN_MIN_MINUTES} y ${RUN_MAX_MINUTES}.`;
  }

  let distanceKm: number | null = null;
  if (exerciseType === 'run' && values.km.trim() !== '') {
    const km = parseDecimal(values.km);
    if (km === null || km < RUN_MIN_KM || km > RUN_MAX_KM) {
      errors.km = `Ingresá km entre ${RUN_MIN_KM} y ${RUN_MAX_KM} (o dejalo vacío).`;
    } else {
      distanceKm = Math.round(km * 100) / 100;
    }
  }

  if (exerciseType === 'workout_day' && !values.dayId) {
    errors.dayId = 'Seleccioná un día de entrenamiento.';
  }

  if (!isValidDateKey(values.date)) {
    errors.date = 'Elegí una fecha válida.';
  } else if (values.date > today) {
    errors.date = exerciseType === 'workout_day'
      ? 'No se puede registrar un entrenamiento en el futuro.'
      : 'No se puede registrar una corrida en el futuro.';
  } else if (values.date < addDays(today, -MAX_BACKDATE_DAYS)) {
    errors.date = `Solo se puede registrar hasta ${MAX_BACKDATE_DAYS} días atrás.`;
  }

  if (errors.minutes || errors.km || errors.date || errors.dayId || minutes === null) return { ok: false, errors };

  const feeling =
    values.feeling !== null && Number.isInteger(values.feeling) && values.feeling >= 1 && values.feeling <= 5
      ? values.feeling
      : null;

  return {
    ok: true,
    fields: {
      exerciseType,
      dayId: exerciseType === 'workout_day' ? (values.dayId ?? null) : null,
      durationSeconds: minutes * 60,
      distanceKm: exerciseType === 'run' ? distanceKm : null,
      runLocation: exerciseType === 'run' ? values.location : null,
      feeling,
      occurredOn: values.date,
    },
  };
}
