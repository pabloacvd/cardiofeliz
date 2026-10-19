import { GAME_CONFIG } from './config';
import type { Activity } from '../types/gamification';

/** Devuelve el peso si es válido; si no, null (sin peso no se estiman calorías). */
export function sanitizeWeight(weightKg: number | null | undefined): number | null {
  const { weightMinKg, weightMaxKg } = GAME_CONFIG.calories;
  if (typeof weightKg !== 'number' || !Number.isFinite(weightKg)) return null;
  if (weightKg < weightMinKg || weightKg > weightMaxKg) return null;
  return weightKg;
}

/**
 * MET de una corrida. Con distancia y duración se interpola por velocidad;
 * si falta alguna o la velocidad es inverosímil, se usa un valor moderado fijo.
 */
export function metForRun(distanceKm: number | null | undefined, minutes: number): number {
  const { runDefault, maxPlausibleRunSpeedKmh } = GAME_CONFIG.calories.met;
  const table = GAME_CONFIG.calories.runTable;
  if (typeof distanceKm !== 'number' || !Number.isFinite(distanceKm) || distanceKm <= 0 || minutes <= 0) {
    return runDefault;
  }

  const speed = distanceKm / (minutes / 60);
  if (speed < 2 || speed > maxPlausibleRunSpeedKmh) return runDefault;
  if (speed <= table[0].speedKmh) return table[0].met;
  const last = table[table.length - 1];
  if (speed >= last.speedKmh) return last.met;

  for (let i = 1; i < table.length; i++) {
    const lo = table[i - 1];
    const hi = table[i];
    if (speed <= hi.speedKmh) {
      const t = (speed - lo.speedKmh) / (hi.speedKmh - lo.speedKmh);
      return lo.met + t * (hi.met - lo.met);
    }
  }
  return runDefault;
}

/**
 * Calorías estimadas = MET × peso (kg) × horas. Devuelve null si falta un peso válido.
 * Es una estimación: se muestra siempre como "aprox.".
 */
export function estimateCalories(
  activity: Pick<Activity, 'type' | 'durationSeconds' | 'distanceKm'>,
  weightKg: number | null | undefined,
): number | null {
  const weight = sanitizeWeight(weightKg);
  if (weight === null) return null;

  const seconds =
    Number.isFinite(activity.durationSeconds) && activity.durationSeconds > 0 ? activity.durationSeconds : 0;
  const hours = seconds / 3600;
  const minutes = seconds / 60;

  let met: number;
  switch (activity.type) {
    case 'run':
      met = metForRun(activity.distanceKm, minutes);
      break;
    case 'active_rest':
      met = GAME_CONFIG.calories.met.activeRest;
      break;
    default:
      met = GAME_CONFIG.calories.met.workout;
  }
  return Math.round(met * weight * hours);
}
