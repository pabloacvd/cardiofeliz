import { describe, expect, it } from 'vitest';
import { logOutcome, withActivity } from '../outcome';
import {
  defaultRunForm,
  parseDecimal,
  parseWeight,
  runFormFromActivity,
  validateRunForm,
} from '../../utils/activityForm';
import { ctx, rest, run, workout } from './helpers';

const TODAY = '2026-03-11';

describe('parseDecimal / parseWeight', () => {
  it('acepta coma o punto y rechaza texto', () => {
    expect(parseDecimal('5,2')).toBe(5.2);
    expect(parseDecimal(' 5.25 ')).toBe(5.25);
    expect(parseDecimal('')).toBeNull();
    expect(parseDecimal('abc')).toBeNull();
    expect(parseDecimal('-3')).toBeNull();
    expect(parseDecimal('1e3')).toBeNull();
  });

  it('el peso respeta el rango válido', () => {
    expect(parseWeight('62,5')).toBe(62.5);
    expect(parseWeight('19')).toBeNull();
    expect(parseWeight('301')).toBeNull();
    expect(parseWeight('')).toBeNull();
  });
});

describe('validateRunForm', () => {
  it('el formulario por defecto es válido: 30 min hoy', () => {
    const r = validateRunForm(defaultRunForm(TODAY), TODAY);
    expect(r).toEqual({
      ok: true,
      fields: { durationSeconds: 1800, distanceKm: null, runLocation: null, feeling: null, occurredOn: TODAY },
    });
  });

  it('valida minutos: enteros entre 1 y 300', () => {
    for (const minutes of ['0', '301', '', '12.5', 'abc', '-5']) {
      const r = validateRunForm({ ...defaultRunForm(TODAY), minutes }, TODAY);
      expect(r.ok).toBe(false);
      if (!r.ok) expect(r.errors.minutes).toBeDefined();
    }
    expect(validateRunForm({ ...defaultRunForm(TODAY), minutes: '300' }, TODAY).ok).toBe(true);
  });

  it('km es opcional pero, si se informa, debe estar entre 0,1 y 100 y se redondea a 2 decimales', () => {
    const ok = validateRunForm({ ...defaultRunForm(TODAY), km: '5,126' }, TODAY);
    expect(ok.ok && ok.fields.distanceKm).toBe(5.13);
    for (const km of ['0', '0,05', '101', 'x']) {
      const r = validateRunForm({ ...defaultRunForm(TODAY), km }, TODAY);
      expect(r.ok).toBe(false);
      if (!r.ok) expect(r.errors.km).toBeDefined();
    }
  });

  it('permite ayer pero no el futuro ni más de 30 días atrás', () => {
    expect(validateRunForm({ ...defaultRunForm(TODAY), date: '2026-03-10' }, TODAY).ok).toBe(true);
    expect(validateRunForm({ ...defaultRunForm(TODAY), date: '2026-02-09' }, TODAY).ok).toBe(true); // 30 días
    for (const date of ['2026-03-12', '2026-02-08', 'ayer', '2026-02-30']) {
      const r = validateRunForm({ ...defaultRunForm(TODAY), date }, TODAY);
      expect(r.ok).toBe(false);
      if (!r.ok) expect(r.errors.date).toBeDefined();
    }
  });

  it('descarta una sensación fuera de 1 a 5', () => {
    const r = validateRunForm({ ...defaultRunForm(TODAY), feeling: 9 }, TODAY);
    expect(r.ok && r.fields.feeling).toBeNull();
    const ok = validateRunForm({ ...defaultRunForm(TODAY), feeling: 4, location: 'cinta' }, TODAY);
    expect(ok.ok && [ok.fields.feeling, ok.fields.runLocation]).toEqual([4, 'cinta']);
  });

  it('runFormFromActivity vuelve a validar sin cambios', () => {
    const a = run('2026-03-10', { durationSeconds: 45 * 60, distanceKm: 6.5, runLocation: 'calle', feeling: 5 });
    const r = validateRunForm(runFormFromActivity(a), TODAY);
    expect(r).toEqual({
      ok: true,
      fields: { durationSeconds: 2700, distanceKm: 6.5, runLocation: 'calle', feeling: 5, occurredOn: '2026-03-10' },
    });
  });
});

describe('logOutcome', () => {
  it('informa XP, racha y avance de la semana al registrar una corrida', () => {
    const before = ctx(TODAY, [workout('2026-03-10')]);
    const after = withActivity(before, run(TODAY));
    const o = logOutcome(before, after);
    expect(o.xpGained).toBeGreaterThanOrEqual(60);
    expect(o.streakBefore).toBe(1);
    expect(o.streakAfter).toBe(2);
    expect(o.weekRuns).toBe(1);
    expect(o.runsGoal).toBe(2);
  });

  it('detecta los logros que se desbloquean con este registro', () => {
    const before = ctx(TODAY, []);
    const o = logOutcome(before, withActivity(before, run(TODAY)));
    expect(o.newAchievements.map((a) => a.id)).toContain('first_run');
  });

  it('no repite logros ya desbloqueados', () => {
    const before = ctx(TODAY, [run('2026-03-09')]);
    const o = logOutcome(before, withActivity(before, run(TODAY)));
    expect(o.newAchievements.map((a) => a.id)).not.toContain('first_run');
  });

  it('un descanso activo suma XP y sostiene la racha', () => {
    const before = ctx(TODAY, [run('2026-03-10')]);
    const o = logOutcome(before, withActivity(before, rest(TODAY)));
    expect(o.xpGained).toBeGreaterThanOrEqual(20);
    expect(o.streakAfter).toBe(2);
  });
});
