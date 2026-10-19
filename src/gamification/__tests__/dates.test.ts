import { describe, expect, it } from 'vitest';
import {
  addDays,
  dayNumber,
  diffDays,
  eachDay,
  isoWeek,
  isValidDateKey,
  toDateKey,
  weekdayIndex,
  weekEnd,
  weekNumber,
  weekStart,
} from '../dates';

describe('fechas de calendario', () => {
  it('valida el formato y rechaza fechas imposibles', () => {
    expect(isValidDateKey('2026-03-02')).toBe(true);
    expect(isValidDateKey('2026-02-30')).toBe(false);
    expect(isValidDateKey('2026-13-01')).toBe(false);
    expect(isValidDateKey('02/03/2026')).toBe(false);
    expect(isValidDateKey('')).toBe(false);
    expect(() => dayNumber('basura')).toThrow(RangeError);
  });

  it('suma días cruzando meses, años y bisiestos', () => {
    expect(addDays('2026-02-28', 1)).toBe('2026-03-01');
    expect(addDays('2024-02-28', 1)).toBe('2024-02-29');
    expect(addDays('2025-12-31', 1)).toBe('2026-01-01');
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28');
    expect(diffDays('2026-03-10', '2026-03-01')).toBe(9);
  });

  it('no se desvía con el cambio de horario de verano', () => {
    expect(addDays('2026-03-07', 1)).toBe('2026-03-08');
    expect(addDays('2026-11-01', 1)).toBe('2026-11-02');
    expect(eachDay('2026-03-07', '2026-03-10')).toEqual([
      '2026-03-07',
      '2026-03-08',
      '2026-03-09',
      '2026-03-10',
    ]);
  });

  it('usa lunes como primer día de la semana', () => {
    expect(weekdayIndex('2026-03-02')).toBe(0); // lunes
    expect(weekdayIndex('2026-03-08')).toBe(6); // domingo
    expect(weekStart('2026-03-08')).toBe('2026-03-02');
    expect(weekStart('2026-03-02')).toBe('2026-03-02');
    expect(weekEnd('2026-03-04')).toBe('2026-03-08');
    expect(weekStart('2026-03-09')).toBe('2026-03-09');
  });

  it('numera semanas de forma consecutiva', () => {
    expect(weekNumber('2026-03-09') - weekNumber('2026-03-02')).toBe(1);
    expect(weekNumber('2026-03-08')).toBe(weekNumber('2026-03-02'));
    expect(weekNumber('2026-01-05') - weekNumber('2025-12-29')).toBe(1);
  });

  it('calcula la semana ISO, incluidos los bordes de año', () => {
    expect(isoWeek('2026-03-02')).toEqual({ year: 2026, week: 10 });
    expect(isoWeek('2026-01-01')).toEqual({ year: 2026, week: 1 });
    expect(isoWeek('2021-01-03')).toEqual({ year: 2020, week: 53 });
    expect(isoWeek('2024-12-30')).toEqual({ year: 2025, week: 1 });
  });

  it('eachDay devuelve vacío si el rango está invertido', () => {
    expect(eachDay('2026-03-05', '2026-03-01')).toEqual([]);
    expect(eachDay('2026-03-05', '2026-03-05')).toEqual(['2026-03-05']);
  });

  it('toDateKey usa la fecha local del dispositivo', () => {
    expect(toDateKey(new Date(2026, 2, 2, 23, 59))).toBe('2026-03-02');
    expect(toDateKey(new Date(2026, 2, 3, 0, 1))).toBe('2026-03-03');
  });
});
