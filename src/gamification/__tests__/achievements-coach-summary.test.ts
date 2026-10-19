import { describe, expect, it } from 'vitest';
import { evaluateAchievements, newlyUnlocked } from '../achievements';
import { pickCoachMessage } from '../coach';
import { computeGameSummary } from '../index';
import type { GameContext } from '../activities';
import { activeDays, ctx, rest, run, vacation, workout } from './helpers';

const unlocked = (c: GameContext): string[] =>
  evaluateAchievements(c).filter((a) => a.unlocked).map((a) => a.id);

describe('logros', () => {
  it('sin actividades no hay nada desbloqueado', () => {
    expect(unlocked(ctx('2026-03-04'))).toEqual([]);
  });

  it('el primer entreno y la primera corrida se desbloquean por separado', () => {
    expect(unlocked(ctx('2026-03-04', [workout('2026-03-04')]))).toContain('first_workout');
    expect(unlocked(ctx('2026-03-04', [workout('2026-03-04')]))).not.toContain('first_run');
    expect(unlocked(ctx('2026-03-04', [run('2026-03-04')]))).toContain('first_run');
  });

  it('los logros de racha usan la mejor racha, aunque se haya cortado', () => {
    const days = ['2026-02-01', '2026-02-02', '2026-02-03', '2026-02-04'];
    const ids = unlocked(ctx('2026-03-04', activeDays(days)));
    expect(ids).toContain('streak_3');
    expect(ids).not.toContain('streak_7');
  });

  it('suma kilómetros ignorando valores inválidos', () => {
    const runs = [
      run('2026-03-01', { distanceKm: 30 }),
      run('2026-03-02', { distanceKm: 25 }),
      run('2026-03-03', { distanceKm: -10 }),
      run('2026-03-04', { distanceKm: Number.NaN }),
    ];
    const ids = unlocked(ctx('2026-03-04', runs));
    expect(ids).toContain('km_50');
    expect(ids).not.toContain('km_100');
  });

  it('corridas largas', () => {
    const ids = unlocked(ctx('2026-03-04', [run('2026-03-04', { durationSeconds: 50 * 60 })]));
    expect(ids).toContain('run_45');
    expect(ids).not.toContain('run_60');
  });

  it('madrugadora requiere hora de inicio antes de las 8', () => {
    const early = run('2026-03-04', { startedAt: new Date(2026, 2, 4, 7, 0).toISOString() });
    const late = run('2026-03-04', { startedAt: new Date(2026, 2, 4, 19, 0).toISOString() });
    expect(unlocked(ctx('2026-03-04', [early]))).toContain('early_bird');
    expect(unlocked(ctx('2026-03-04', [late]))).not.toContain('early_bird');
    expect(unlocked(ctx('2026-03-04', [run('2026-03-04')]))).not.toContain('early_bird');
  });

  it('"¡Volví!" cuenta 7 días de ausencia, pero no los de vacaciones', () => {
    const acts = [rest('2026-03-01'), rest('2026-03-12')];
    expect(unlocked(ctx('2026-03-12', acts))).toContain('comeback');
    const withVacation = ctx('2026-03-12', acts, [vacation('2026-03-02', '2026-03-11')]);
    expect(unlocked(withVacation)).not.toContain('comeback');
  });

  it('semana perfecta', () => {
    const week = [
      workout('2026-03-02'), workout('2026-03-03'), workout('2026-03-04'),
      run('2026-03-05'), run('2026-03-06'),
    ];
    expect(unlocked(ctx('2026-03-10', week))).toContain('perfect_week');
  });

  it('el progreso nunca supera la meta', () => {
    for (const a of evaluateAchievements(ctx('2026-03-04', [run('2026-03-04', { distanceKm: 900 })]))) {
      expect(a.current).toBeLessThanOrEqual(a.target);
    }
  });

  it('newlyUnlocked devuelve solo los que todavía no se habían registrado', () => {
    const c = ctx('2026-03-04', [workout('2026-03-04'), run('2026-03-04')]);
    expect(newlyUnlocked(c, []).map((a) => a.id)).toEqual(expect.arrayContaining(['first_workout', 'first_run']));
    expect(newlyUnlocked(c, ['first_workout']).map((a) => a.id)).not.toContain('first_workout');
    expect(newlyUnlocked(c, ['first_workout', 'first_run'])).toEqual([]);
  });
});

describe('coach', () => {
  const idOf = (c: GameContext): string => pickCoachMessage(c).id;

  it('de bienvenida cuando todavía no hay actividad', () => {
    expect(idOf(ctx('2026-03-04'))).toBe('welcome');
  });

  it('en vacaciones tiene prioridad sobre todo lo demás', () => {
    const c = ctx('2026-03-04', [rest('2026-03-03')], [vacation('2026-03-01', null)]);
    expect(idOf(c)).toBe('vacation');
  });

  it('avisa si las vacaciones ya son largas', () => {
    expect(idOf(ctx('2026-03-04', [], [vacation('2026-01-01', null)]))).toBe('vacation_long');
  });

  it('al volver de vacaciones anima a recuperar', () => {
    const c = ctx('2026-03-03', [rest('2026-02-10')], [vacation('2026-02-20', '2026-03-01')]);
    const msg = pickCoachMessage(c);
    expect(msg.id).toBe('comeback');
    expect(msg.mood).toBe('recover');
  });

  it('después de varios días sin entrenar dice que se la extraña', () => {
    expect(idOf(ctx('2026-03-10', [rest('2026-03-01')]))).toBe('lapse');
  });

  it('avisa cuando se ganó un congelador hoy', () => {
    const days = ['2026-02-28', '2026-03-01', '2026-03-02', '2026-03-03', '2026-03-04'];
    expect(idOf(ctx('2026-03-04', activeDays(days)))).toBe('freeze_earned');
  });

  it('racha en riesgo sin congelador', () => {
    expect(idOf(ctx('2026-03-04', activeDays(['2026-03-02', '2026-03-03'])))).toBe('streak_risk');
  });

  it('racha en riesgo pero con congelador a salvo', () => {
    const days = ['2026-02-27', '2026-02-28', '2026-03-01', '2026-03-02', '2026-03-03'];
    expect(idOf(ctx('2026-03-04', activeDays(days)))).toBe('streak_risk_freeze');
  });

  it('celebra la semana perfecta', () => {
    const week = [
      workout('2026-03-02'), run('2026-03-03'), workout('2026-03-04'),
      workout('2026-03-06'), run('2026-03-07'),
    ];
    expect(idOf(ctx('2026-03-07', week))).toBe('week_met');
  });

  it('si ya hubo actividad hoy, cuenta lo que falta de la semana', () => {
    const msg = pickCoachMessage(ctx('2026-03-04', [workout('2026-03-04')]));
    expect(msg.id).toBe('done_today');
    expect(msg.text).toContain('2 entrenos y 2 corridas');
  });

  it('si solo faltan corridas, lo dice', () => {
    const acts = [workout('2026-03-02'), workout('2026-03-03'), workout('2026-03-05')];
    const msg = pickCoachMessage(ctx('2026-03-07', acts));
    expect(msg.id).toBe('needs_run');
    expect(msg.text).toContain('te faltan 2 corridas');
  });

  it('si solo faltan entrenos, lo dice', () => {
    const acts = [run('2026-03-02'), run('2026-03-03'), run('2026-03-05')];
    expect(idOf(ctx('2026-03-07', acts))).toBe('needs_workout');
  });

  it('mensaje general cuando no aplica ninguna otra regla', () => {
    expect(idOf(ctx('2026-03-05', [workout('2026-03-02')]))).toBe('default');
  });

  it('usa el nombre cuando se conoce', () => {
    expect(pickCoachMessage(ctx('2026-03-04', [], [], { displayName: 'Juli' })).text).toContain('Juli');
  });
});

describe('computeGameSummary', () => {
  it('con datos vacíos devuelve un estado inicial consistente', () => {
    const s = computeGameSummary(ctx('2026-03-04'));
    expect(s.xp.total).toBe(0);
    expect(s.level.level).toBe(1);
    expect(s.streak.current).toBe(0);
    expect(s.weekly.current).toBe(0);
    expect(s.coach.id).toBe('welcome');
    expect(s.achievements.every((a) => !a.unlocked)).toBe(true);
  });

  it('descarta actividades con fecha inválida o futura', () => {
    const clean = computeGameSummary(ctx('2026-03-04', [workout('2026-03-04')]));
    const dirty = computeGameSummary(
      ctx('2026-03-04', [
        workout('2026-03-04'),
        workout('2026-03-20'),
        workout('ayer'),
        workout('2026-13-45'),
        workout(''),
      ]),
    );
    expect(dirty.xp.total).toBe(clean.xp.total);
    expect(dirty.week.workouts).toBe(1);
    expect(dirty.streak.current).toBe(1);
  });

  it('el orden de las actividades no cambia el resultado', () => {
    const acts = [workout('2026-03-02'), run('2026-03-03'), rest('2026-03-04'), workout('2026-03-05')];
    const sorted = computeGameSummary(ctx('2026-03-05', acts));
    const shuffled = computeGameSummary(ctx('2026-03-05', [acts[3], acts[0], acts[2], acts[1]]));
    expect(shuffled).toEqual(sorted);
  });

  it('ignora vacaciones con fechas inválidas o con fin anterior al inicio', () => {
    const s = computeGameSummary(
      ctx('2026-03-04', [rest('2026-03-04')], [vacation('basura', null), vacation('2026-03-03', '2026-03-01')]),
    );
    expect(s.vacation.active).toBe(false);
  });

  it('no modifica los datos de entrada', () => {
    const acts = [workout('2026-03-05'), workout('2026-03-02')];
    const snapshot = JSON.stringify(acts);
    computeGameSummary(ctx('2026-03-05', acts));
    expect(JSON.stringify(acts)).toBe(snapshot);
  });
});
