import { describe, expect, it } from 'vitest';
import { challengeHistory, evaluateChallenge } from '../challenges';
import { evaluateMissions, pickDailyMissions } from '../missions';
import { addDays, weekEnd } from '../dates';
import type { Activity, VacationPeriod } from '../../types/gamification';
import { ctx, rest, run, vacation, workout } from './helpers';

const FIRST_MONDAY = '2026-03-02';

/** Primer lunes (dentro de 6 semanas consecutivas) en que toca el desafío `id`. */
function mondayOf(id: string, activities: Activity[] = [], vacations: VacationPeriod[] = []): string {
  for (let i = 0; i < 6; i++) {
    const monday = addDays(FIRST_MONDAY, 7 * i);
    if (evaluateChallenge(ctx(weekEnd(monday), activities, vacations), monday).id === id) return monday;
  }
  throw new Error(`El desafío ${id} no aparece en 6 semanas`);
}

describe('desafíos semanales', () => {
  it('es determinista: el mismo día y datos dan el mismo desafío', () => {
    const c = ctx('2026-03-04', [workout('2026-03-02')]);
    expect(evaluateChallenge(c)).toEqual(evaluateChallenge(c));
  });

  it('todos los días de una misma semana ven el mismo desafío', () => {
    const c = ctx('2026-03-08');
    const ids = ['2026-03-02', '2026-03-05', '2026-03-08'].map((d) => evaluateChallenge(c, d).id);
    expect(new Set(ids).size).toBe(1);
  });

  it('rota: seis semanas seguidas cubren los seis desafíos cuando todos son posibles', () => {
    const prior = [run('2026-01-05', { distanceKm: 5, startedAt: new Date(2026, 0, 5, 7).toISOString() })];
    const ids = new Set<string>();
    for (let i = 0; i < 6; i++) {
      const monday = addDays(FIRST_MONDAY, 7 * i);
      ids.add(evaluateChallenge(ctx(weekEnd(monday), prior), monday).id);
    }
    expect(ids.size).toBe(6);
  });

  it('sin historial no ofrece desafíos imposibles de medir (km ni horario)', () => {
    for (let i = 0; i < 12; i++) {
      const monday = addDays(FIRST_MONDAY, 7 * i);
      const { id } = evaluateChallenge(ctx(weekEnd(monday)), monday);
      expect(id).not.toBe('run_10_km');
      expect(id).not.toBe('morning_2_days');
    }
  });

  it('el desafío de km vuelve a aparecer cuando ya hay corridas con distancia', () => {
    const prior = [run('2026-01-05', { distanceKm: 5 })];
    expect(mondayOf('run_10_km', prior)).toBeTruthy();
  });

  it('suma el avance y se completa al llegar a la meta', () => {
    const monday = mondayOf('active_days_5');
    const days = [0, 1, 2, 3, 4].map((n) => addDays(monday, n));
    const partial = evaluateChallenge(ctx(weekEnd(monday), days.slice(0, 3).map((d) => rest(d))), monday);
    expect(partial.progress).toBe(3);
    expect(partial.done).toBe(false);
    expect(partial.ratio).toBeCloseTo(0.6);

    const full = evaluateChallenge(ctx(weekEnd(monday), days.map((d) => rest(d))), monday);
    expect(full.done).toBe(true);
    expect(full.ratio).toBe(1);
  });

  it('no cuenta actividades de otras semanas', () => {
    const monday = mondayOf('active_days_5');
    const outside = [rest(addDays(monday, -1)), rest(addDays(monday, 7))];
    expect(evaluateChallenge(ctx(weekEnd(monday), outside), monday).progress).toBe(0);
  });

  it('una semana con vacaciones sin cumplir queda pausada', () => {
    const monday = mondayOf('minutes_150');
    const v = [vacation(monday, addDays(monday, 4))];
    const c = evaluateChallenge(ctx(addDays(monday, 6), [], v), monday);
    expect(c.paused).toBe(true);
    expect(c.done).toBe(false);
  });

  it('se oculta si hoy se está de vacaciones', () => {
    const c = evaluateChallenge(ctx('2026-03-04', [], [vacation('2026-03-01', null)]));
    expect(c.hidden).toBe(true);
  });

  it('el historial va desde la primera actividad hasta la semana actual', () => {
    const history = challengeHistory(ctx('2026-03-18', [workout('2026-03-02')]));
    expect(history.map((h) => h.weekStart)).toEqual(['2026-03-02', '2026-03-09', '2026-03-16']);
  });

  it('el historial está vacío sin actividades', () => {
    expect(challengeHistory(ctx('2026-03-18'))).toEqual([]);
  });
});

describe('misiones diarias', () => {
  it('ofrece entre 2 y 3 misiones', () => {
    for (const today of ['2026-03-02', '2026-03-04', '2026-03-08']) {
      const n = pickDailyMissions(ctx(today)).length;
      expect(n).toBeGreaterThanOrEqual(2);
      expect(n).toBeLessThanOrEqual(3);
    }
  });

  it('con la semana por hacer propone corrida y entreno', () => {
    const ids = pickDailyMissions(ctx('2026-03-04'));
    expect(ids).toContain('do_run');
    expect(ids).toContain('do_workout');
  });

  it('con la meta semanal cumplida ya no propone corrida ni entreno', () => {
    const week = [
      workout('2026-03-02'), workout('2026-03-03'), workout('2026-03-04'),
      run('2026-03-05'), run('2026-03-06'),
    ];
    const ids = pickDailyMissions(ctx('2026-03-08', week));
    expect(ids).not.toContain('do_run');
    expect(ids).not.toContain('do_workout');
    expect(ids).toContain('any_activity');
  });

  it('no hay misiones de vacaciones', () => {
    const c = ctx('2026-03-04', [], [vacation('2026-03-01', null)]);
    expect(pickDailyMissions(c)).toEqual([]);
    expect(evaluateMissions(c).hidden).toBe(true);
  });

  it('en la ventana de regreso la primera misión es una vuelta suave', () => {
    const c = ctx('2026-03-03', [], [vacation('2026-02-20', '2026-03-01')]);
    expect(pickDailyMissions(c)[0]).toBe('comeback_easy');
  });

  it('la lista no cambia a lo largo del día aunque se vaya cumpliendo', () => {
    const before = pickDailyMissions(ctx('2026-03-04', [workout('2026-03-02')]));
    const after = pickDailyMissions(
      ctx('2026-03-04', [workout('2026-03-02'), run('2026-03-04'), workout('2026-03-04')]),
    );
    expect(after).toEqual(before);
  });

  it('marca como cumplida solo la misión que corresponde', () => {
    const result = evaluateMissions(ctx('2026-03-04', [run('2026-03-04')]));
    expect(result.missions.find((m) => m.id === 'do_run')?.done).toBe(true);
    expect(result.missions.find((m) => m.id === 'do_workout')?.done).toBe(false);
    expect(result.allDone).toBe(false);
  });

  it('al cumplir todas suma el bonus extra', () => {
    const today = '2026-03-04';
    const day = [workout(today), run(today), rest(today)];
    const result = evaluateMissions(ctx(today, day));
    expect(result.allDone).toBe(true);
    const base = result.missions.reduce((s, m) => s + m.xp, 0);
    expect(result.xpEarned).toBe(base + 20);
  });

  it('el XP sin completar todas es solo la suma de las cumplidas', () => {
    const result = evaluateMissions(ctx('2026-03-04', [run('2026-03-04')]));
    const run30 = result.missions.find((m) => m.id === 'do_run');
    expect(result.xpEarned).toBe(run30?.xp);
  });
});
