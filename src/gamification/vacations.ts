import type { VacationPeriod } from '../types/gamification';
import { GAME_CONFIG } from './config';
import { addDays, diffDays, eachDay, type DateKey } from './dates';

/*
 * Convención: `startOn` y `endOn` son INCLUSIVOS. `endOn = null` significa vacaciones activas.
 * Al desactivar el modo vacaciones, la UI debe guardar `endOn = ayer` (si `startOn` es hoy o
 * posterior, borra el período). Así el día de regreso ya queda dentro de la ventana de recuperación.
 * Todas las funciones reciben períodos ya validados (ver `cleanVacations`).
 */

export function isOnVacation(day: DateKey, vacations: readonly VacationPeriod[]): boolean {
  return vacations.some((v) => v.startOn <= day && (v.endOn == null || day <= v.endOn));
}

/** Cantidad de días de vacaciones entre `from` y `to` (ambos inclusive). */
export function vacationDaysInRange(
  from: DateKey,
  to: DateKey,
  vacations: readonly VacationPeriod[],
): number {
  if (from > to) return 0;
  return eachDay(from, to).filter((d) => isOnVacation(d, vacations)).length;
}

export interface VacationStatus {
  active: boolean;
  current: VacationPeriod | null;
  /** Días de vacaciones transcurridos hasta hoy, contando el primero y el de hoy. */
  lengthDays: number;
  /** true cuando las vacaciones activas superan el umbral de aviso. */
  longWarning: boolean;
}

export function vacationStatus(today: DateKey, vacations: readonly VacationPeriod[]): VacationStatus {
  const current =
    vacations.find((v) => v.startOn <= today && (v.endOn == null || today <= v.endOn)) ?? null;
  if (!current) return { active: false, current: null, lengthDays: 0, longWarning: false };
  const lengthDays = diffDays(today, current.startOn) + 1;
  return {
    active: true,
    current,
    lengthDays,
    longWarning: lengthDays > GAME_CONFIG.vacation.longWarningDays,
  };
}

export interface ComebackStatus {
  active: boolean;
  /** 1 = primer día de vuelta. 0 cuando no está activo. */
  dayNumber: number;
  /** Días que quedan de ventana, contando hoy. */
  daysLeft: number;
  endedOn: DateKey | null;
}

const NO_COMEBACK: ComebackStatus = { active: false, dayNumber: 0, daysLeft: 0, endedOn: null };

/** Ventana "¡Hay que recuperar!" tras terminar unas vacaciones. */
export function comebackStatus(today: DateKey, vacations: readonly VacationPeriod[]): ComebackStatus {
  if (isOnVacation(today, vacations)) return NO_COMEBACK;

  const days = GAME_CONFIG.vacation.comebackDays;
  let endedOn: DateKey | null = null;
  for (const v of vacations) {
    if (v.endOn == null || v.endOn >= today) continue;
    if (today > addDays(v.endOn, days)) continue;
    if (endedOn === null || v.endOn > endedOn) endedOn = v.endOn;
  }
  if (endedOn === null) return NO_COMEBACK;

  const dayNumber = diffDays(today, endedOn);
  return { active: true, dayNumber, daysLeft: days - dayNumber + 1, endedOn };
}
