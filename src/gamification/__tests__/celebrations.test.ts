import { describe, expect, it } from 'vitest';
import { logOutcome, withActivity } from '../outcome';
import { buildToasts, withClaimedAchievements } from '../../utils/celebrations';
import { ctx, run, workout } from './helpers';

const TODAY = '2026-03-11';

describe('avisos de celebración', () => {
  it('avisa de los logros nuevos de un registro', () => {
    const before = ctx(TODAY, []);
    const outcome = logOutcome(before, withActivity(before, run(TODAY)));
    const toasts = buildToasts(outcome);
    expect(toasts.map((t) => t.id)).toContain('achievement-first_run');
    expect(toasts.find((t) => t.id === 'achievement-first_run')?.kind).toBe('achievement');
  });

  it('solo celebra los logros que se registraron por primera vez', () => {
    const before = ctx(TODAY, []);
    const outcome = logOutcome(before, withActivity(before, run(TODAY)));
    const none = withClaimedAchievements(outcome, []);
    expect(none.newAchievements).toEqual([]);
    expect(buildToasts(none).some((t) => t.kind === 'achievement')).toBe(false);

    const one = withClaimedAchievements(outcome, ['first_run']);
    expect(one.newAchievements.map((a) => a.id)).toEqual(['first_run']);
  });

  it('avisa la subida de nivel con el nombre del tramo', () => {
    // 100 XP de entreno = 2 niveles con stepXp 50: pasa del nivel 1 al 2.
    const before = ctx(TODAY, []);
    const outcome = logOutcome(before, withActivity(before, workout(TODAY)));
    const level = buildToasts(outcome).find((t) => t.kind === 'level');
    expect(outcome.leveledUp).toBe(true);
    expect(level?.title).toBe(`¡Nivel ${outcome.levelAfter}!`);
    expect(level?.detail).toBe(outcome.tierName);
  });

  it('un registro sin novedades no genera avisos', () => {
    const before = ctx(TODAY, [workout('2026-03-10'), run('2026-03-10')]);
    const outcome = logOutcome(before, withActivity(before, run(TODAY, { durationSeconds: 60 })));
    const quiet = withClaimedAchievements({ ...outcome, leveledUp: false, earnedFreeze: false }, []);
    expect(buildToasts(quiet)).toEqual([]);
  });

  it('avisa el congelador ganado', () => {
    const before = ctx(TODAY, []);
    const outcome = logOutcome(before, withActivity(before, run(TODAY)));
    const toasts = buildToasts({ ...outcome, earnedFreeze: true });
    expect(toasts.some((t) => t.kind === 'freeze')).toBe(true);
  });
});
