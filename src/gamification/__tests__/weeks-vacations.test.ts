import { describe, expect, it } from 'vitest';
import { computeWeeklyStreak, weekProgress } from '../weeks';
import { comebackStatus, isOnVacation, vacationDaysInRange, vacationStatus } from '../vacations';
import { ctx, rest, run, vacation, workout } from './helpers';

// Semanas (lunes a domingo): 02-23, 03-02, 03-09, 03-16
const perfectWeek = (monday: string) => {
  const d = (n: number) => {
    const base = new Date(`${monday}T00:00:00Z`);
    base.setUTCDate(base.getUTCDate() + n);
    return base.toISOString().slice(0, 10);
  };
  return [workout(d(0)), workout(d(2)), workout(d(4)), run(d(1)), run(d(5))];
};

describe('progreso semanal', () => {
  it('cuenta entrenos y corridas de lunes a domingo', () => {
    const w = weekProgress(
      ctx('2026-03-04', [workout('2026-03-02'), run('2026-03-03'), workout('2026-03-01'), workout('2026-03-09')]),
      '2026-03-04',
    );
    expect(w.workouts).toBe(1);
    expect(w.runs).toBe(1);
    expect(w.remainingWorkouts).toBe(2);
    expect(w.remainingRuns).toBe(1);
    expect(w.status).toBe('in_progress');
  });

  it('el domingo pertenece a la semana que termina y el lunes a la siguiente', () => {
    const c = ctx('2026-03-10', [workout('2026-03-08'), workout('2026-03-09')]);
    expect(weekProgress(c, '2026-03-08').workouts).toBe(1);
    expect(weekProgress(c, '2026-03-09').workouts).toBe(1);
  });

  it('los anillos no superan la meta aunque se haga de más', () => {
    const w = weekProgress(
      ctx('2026-03-08', [workout('2026-03-02'), workout('2026-03-03'), workout('2026-03-04'), workout('2026-03-05'), run('2026-03-06')]),
      '2026-03-08',
    );
    expect(w.workouts).toBe(4);
    expect(w.workoutsCapped).toBe(3);
    expect(w.remainingWorkouts).toBe(0);
  });

  it('la meta se cumple con 3 entrenos y 2 corridas', () => {
    const w = weekProgress(ctx('2026-03-08', perfectWeek('2026-03-02')), '2026-03-08');
    expect(w.met).toBe(true);
    expect(w.status).toBe('met');
  });

  it('una semana pasada sin cumplir queda como no lograda', () => {
    const w = weekProgress(ctx('2026-03-10', [workout('2026-03-02')]), '2026-03-02');
    expect(w.status).toBe('missed');
  });

  it('suma minutos y kilómetros', () => {
    const w = weekProgress(
      ctx('2026-03-08', [workout('2026-03-02'), run('2026-03-03', { distanceKm: 5.5 }), run('2026-03-04', { distanceKm: 4.25 })]),
      '2026-03-08',
    );
    expect(w.minutes).toBe(45 + 30 + 30);
    expect(w.km).toBe(9.75);
  });
});

describe('racha semanal', () => {
  it('cuenta semanas perfectas consecutivas', () => {
    const acts = [...perfectWeek('2026-02-23'), ...perfectWeek('2026-03-02')];
    const s = computeWeeklyStreak(ctx('2026-03-10', acts));
    expect(s.current).toBe(2);
    expect(s.best).toBe(2);
    expect(s.perfectWeeks).toBe(2);
  });

  it('una semana pasada fallida corta la racha', () => {
    const acts = [...perfectWeek('2026-02-23'), workout('2026-03-03'), ...perfectWeek('2026-03-09')];
    const s = computeWeeklyStreak(ctx('2026-03-17', acts));
    expect(s.current).toBe(1);
    expect(s.best).toBe(1);
    expect(s.perfectWeeks).toBe(2);
  });

  it('la semana en curso sin cumplir todavía no corta la racha', () => {
    const acts = [...perfectWeek('2026-02-23'), ...perfectWeek('2026-03-02'), workout('2026-03-09')];
    const s = computeWeeklyStreak(ctx('2026-03-10', acts));
    expect(s.current).toBe(2);
  });

  it('una semana pausada por vacaciones no corta ni suma', () => {
    const acts = [...perfectWeek('2026-02-23'), ...perfectWeek('2026-03-09')];
    const s = computeWeeklyStreak(
      ctx('2026-03-17', acts, [vacation('2026-03-02', '2026-03-08')]),
    );
    expect(s.current).toBe(2);
    expect(s.perfectWeeks).toBe(2);
    expect(s.weeks.find((w) => w.weekStart === '2026-03-02')?.status).toBe('paused');
  });

  it('vacaciones de menos de 4 días en la semana no la pausan', () => {
    const acts = [...perfectWeek('2026-02-23'), workout('2026-03-02'), ...perfectWeek('2026-03-09')];
    const s = computeWeeklyStreak(
      ctx('2026-03-17', acts, [vacation('2026-03-05', '2026-03-07')]),
    );
    expect(s.weeks.find((w) => w.weekStart === '2026-03-02')?.status).toBe('missed');
    expect(s.current).toBe(1);
  });

  it('una semana con vacaciones pero meta cumplida cuenta como lograda', () => {
    const s = computeWeeklyStreak(
      ctx('2026-03-10', perfectWeek('2026-03-02'), [vacation('2026-03-03', '2026-03-08')]),
    );
    expect(s.weeks[0].status).toBe('met');
    expect(s.current).toBe(1);
  });

  it('sin actividades devuelve todo en cero', () => {
    const s = computeWeeklyStreak(ctx('2026-03-10'));
    expect(s).toEqual({ current: 0, best: 0, perfectWeeks: 0, weeks: [] });
  });
});

describe('vacaciones', () => {
  it('detecta días dentro del período (inclusive)', () => {
    const v = [vacation('2026-03-03', '2026-03-05')];
    expect(isOnVacation('2026-03-02', v)).toBe(false);
    expect(isOnVacation('2026-03-03', v)).toBe(true);
    expect(isOnVacation('2026-03-05', v)).toBe(true);
    expect(isOnVacation('2026-03-06', v)).toBe(false);
  });

  it('un período abierto cubre todo desde el inicio', () => {
    const v = [vacation('2026-03-03', null)];
    expect(isOnVacation('2026-03-02', v)).toBe(false);
    expect(isOnVacation('2027-01-01', v)).toBe(true);
  });

  it('cuenta días de vacaciones en un rango', () => {
    const v = [vacation('2026-03-03', '2026-03-05'), vacation('2026-03-10', '2026-03-12')];
    expect(vacationDaysInRange('2026-03-01', '2026-03-31', v)).toBe(6);
    expect(vacationDaysInRange('2026-03-05', '2026-03-10', v)).toBe(2);
    expect(vacationDaysInRange('2026-03-10', '2026-03-01', v)).toBe(0);
  });

  it('estado de vacaciones: largo y aviso tras 30 días', () => {
    const v = [vacation('2026-03-01', null)];
    expect(vacationStatus('2026-03-01', v).lengthDays).toBe(1);
    expect(vacationStatus('2026-03-30', v).longWarning).toBe(false);
    expect(vacationStatus('2026-03-31', v).lengthDays).toBe(31);
    expect(vacationStatus('2026-03-31', v).longWarning).toBe(true);
    expect(vacationStatus('2026-02-20', v).active).toBe(false);
  });

  it('la ventana "¡Hay que recuperar!" dura 3 días desde el día siguiente al fin', () => {
    const v = [vacation('2026-03-01', '2026-03-10')];
    expect(comebackStatus('2026-03-10', v).active).toBe(false); // todavía de vacaciones
    const d1 = comebackStatus('2026-03-11', v);
    expect(d1).toMatchObject({ active: true, dayNumber: 1, daysLeft: 3, endedOn: '2026-03-10' });
    expect(comebackStatus('2026-03-13', v)).toMatchObject({ active: true, dayNumber: 3, daysLeft: 1 });
    expect(comebackStatus('2026-03-14', v).active).toBe(false);
  });

  it('vacaciones abiertas no tienen ventana de regreso', () => {
    expect(comebackStatus('2026-03-20', [vacation('2026-03-01', null)]).active).toBe(false);
  });

  it('sin vacaciones no hay ventana de regreso', () => {
    expect(comebackStatus('2026-03-20', []).active).toBe(false);
  });

  it('con dos períodos se usa el más reciente', () => {
    const v = [vacation('2026-01-01', '2026-01-10'), vacation('2026-03-01', '2026-03-10')];
    expect(comebackStatus('2026-03-12', v).endedOn).toBe('2026-03-10');
  });

  it('una actividad sola no pausa la semana', () => {
    expect(weekProgress(ctx('2026-03-04', [rest('2026-03-03')]), '2026-03-04').paused).toBe(false);
  });
});
