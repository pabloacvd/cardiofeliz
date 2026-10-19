/**
 * Utilidades de fechas "de calendario" (sin hora) representadas como texto YYYY-MM-DD.
 *
 * Todo el motor trabaja con estas claves y aritmética en UTC, así que el resultado
 * no depende de la zona horaria ni del horario de verano. La única conversión desde
 * un Date real es `toDateKey` / `todayKey`, que usa la fecha LOCAL del dispositivo.
 */

export type DateKey = string;

const DAY_MS = 86_400_000;
const KEY_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

function pad2(n: number): string {
  return String(n).padStart(2, '0');
}

export function isValidDateKey(key: string): boolean {
  const m = KEY_RE.exec(key);
  if (!m) return false;
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  const dt = new Date(Date.UTC(y, mo - 1, d));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === mo - 1 && dt.getUTCDate() === d;
}

/** Cantidad de días desde 1970-01-01 (UTC). Lanza RangeError si la clave es inválida. */
export function dayNumber(key: DateKey): number {
  if (!isValidDateKey(key)) {
    throw new RangeError('Fecha inválida');
  }
  const [y, m, d] = key.split('-').map(Number);
  return Math.round(Date.UTC(y, m - 1, d) / DAY_MS);
}

export function dateFromDayNumber(n: number): DateKey {
  const d = new Date(n * DAY_MS);
  return `${String(d.getUTCFullYear()).padStart(4, '0')}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())}`;
}

export function addDays(key: DateKey, n: number): DateKey {
  return dateFromDayNumber(dayNumber(key) + n);
}

/** a - b, en días. */
export function diffDays(a: DateKey, b: DateKey): number {
  return dayNumber(a) - dayNumber(b);
}

/** Fecha local del dispositivo como clave YYYY-MM-DD. */
export function toDateKey(date: Date): DateKey {
  return `${String(date.getFullYear()).padStart(4, '0')}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

export function todayKey(now: Date = new Date()): DateKey {
  return toDateKey(now);
}

/** Índice del día de la semana con lunes = 0 ... domingo = 6. */
export function weekdayIndex(key: DateKey): number {
  // 1970-01-01 fue jueves (índice 3 con lunes = 0).
  return (((dayNumber(key) + 3) % 7) + 7) % 7;
}

/** Lunes de la semana a la que pertenece la fecha. */
export function weekStart(key: DateKey): DateKey {
  return addDays(key, -weekdayIndex(key));
}

/** Domingo de la semana a la que pertenece la fecha. */
export function weekEnd(key: DateKey): DateKey {
  return addDays(weekStart(key), 6);
}

/** Número de semana consecutivo (estable, útil como semilla de rotación). */
export function weekNumber(key: DateKey): number {
  return Math.floor((dayNumber(weekStart(key)) + 3) / 7);
}

/** Semana ISO 8601 (año ISO y número de semana). */
export function isoWeek(key: DateKey): { year: number; week: number } {
  const thursday = addDays(weekStart(key), 3);
  const year = Number(thursday.slice(0, 4));
  const week = Math.floor(diffDays(thursday, `${String(year).padStart(4, '0')}-01-01`) / 7) + 1;
  return { year, week };
}

/** Todas las fechas entre `from` y `to`, ambas inclusive. Vacío si from > to. */
export function eachDay(from: DateKey, to: DateKey): DateKey[] {
  const start = dayNumber(from);
  const end = dayNumber(to);
  const out: DateKey[] = [];
  for (let n = start; n <= end; n++) out.push(dateFromDayNumber(n));
  return out;
}
