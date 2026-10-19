import { describe, expect, it } from 'vitest';
import { computeStreak } from '../streak';
import { activeDays, ctx, rest, run, vacation, workout } from './helpers';

describe('racha diaria', () => {
  it('sin actividades no hay racha', () => {
    const s = computeStreak(ctx('2026-03-10'));
    expect(s.current).toBe(0);
    expect(s.best).toBe(0);
    expect(s.atRisk).toBe(false);
    expect(s.lastActiveDay).toBeNull();
  });

  it('cuenta días consecutivos incluyendo hoy', () => {
    const s = computeStreak(ctx('2026-03-04', activeDays(['2026-03-02', '2026-03-03', '2026-03-04'])));
    expect(s.current).toBe(3);
    expect(s.activeToday).toBe(true);
    expect(s.atRisk).toBe(false);
  });

  it('hoy sin actividad no corta la racha pero queda en riesgo', () => {
    const s = computeStreak(ctx('2026-03-04', activeDays(['2026-03-02', '2026-03-03'])));
    expect(s.current).toBe(2);
    expect(s.atRisk).toBe(true);
    expect(s.activeToday).toBe(false);
  });

  it('múltiples actividades en el mismo día cuentan como un solo día', () => {
    const s = computeStreak(
      ctx('2026-03-03', [workout('2026-03-02'), run('2026-03-02'), rest('2026-03-02'), rest('2026-03-03')]),
    );
    expect(s.current).toBe(2);
  });

  it('cualquier tipo de actividad sostiene la racha', () => {
    const s = computeStreak(ctx('2026-03-04', [workout('2026-03-02'), run('2026-03-03'), rest('2026-03-04')]));
    expect(s.current).toBe(3);
  });

  it('un hueco sin congeladores corta la racha pero conserva la mejor', () => {
    const s = computeStreak(
      ctx('2026-03-10', [...activeDays(['2026-03-02', '2026-03-03', '2026-03-04']), rest('2026-03-08')]),
    );
    // 02,03,04 → racha 3; 05,06,07 vacíos → se corta; 08 → racha 1; 09 vacío (ayer) → se corta
    expect(s.best).toBe(3);
    expect(s.current).toBe(0);
  });

  it('gana un congelador cada 5 días de racha', () => {
    const days = ['2026-03-02', '2026-03-03', '2026-03-04', '2026-03-05', '2026-03-06'];
    const s = computeStreak(ctx('2026-03-06', activeDays(days)));
    expect(s.current).toBe(5);
    expect(s.freezes).toBe(1);
    expect(s.freezesEarned).toBe(1);
    expect(s.earnedFreezeToday).toBe(true);
  });

  it('el congelador se usa solo y salva el día faltante', () => {
    const days = ['2026-03-02', '2026-03-03', '2026-03-04', '2026-03-05', '2026-03-06'];
    // 07 sin actividad (congelador), 08 sí
    const s = computeStreak(ctx('2026-03-08', [...activeDays(days), rest('2026-03-08')]));
    expect(s.freezesUsedOn).toEqual(['2026-03-07']);
    expect(s.freezes).toBe(0);
    expect(s.current).toBe(6); // el día congelado no suma
  });

  it('el día congelado no suma a la racha', () => {
    const days = ['2026-03-02', '2026-03-03', '2026-03-04', '2026-03-05', '2026-03-06'];
    const s = computeStreak(ctx('2026-03-08', [...activeDays(days), rest('2026-03-08')]));
    expect(s.current).toBe(6);
    expect(s.best).toBe(6);
  });

  it('nunca acumula más de 2 congeladores', () => {
    const start = '2026-03-02';
    const days = Array.from({ length: 15 }, (_, i) => `2026-03-${String(2 + i).padStart(2, '0')}`);
    expect(days[0]).toBe(start);
    const s = computeStreak(ctx(days[14], activeDays(days)));
    expect(s.current).toBe(15);
    expect(s.freezesEarned).toBe(2);
    expect(s.freezes).toBe(2);
  });

  it('dos días faltantes con un solo congelador cortan la racha', () => {
    const days = ['2026-03-02', '2026-03-03', '2026-03-04', '2026-03-05', '2026-03-06'];
    const s = computeStreak(ctx('2026-03-10', activeDays(days)));
    // 07 consume el congelador, 08 corta, 09 (ayer) sin racha
    expect(s.freezesUsedOn).toEqual(['2026-03-07']);
    expect(s.current).toBe(0);
    expect(s.best).toBe(5);
  });

  it('un hueco largo reinicia y una nueva racha empieza de cero', () => {
    const s = computeStreak(
      ctx('2026-04-01', [...activeDays(['2026-03-02', '2026-03-03']), ...activeDays(['2026-03-31', '2026-04-01'])]),
    );
    expect(s.current).toBe(2);
    expect(s.best).toBe(2);
  });

  it('registra hitos de racha con bonus', () => {
    const days = ['2026-03-02', '2026-03-03', '2026-03-04', '2026-03-05'];
    const s = computeStreak(ctx('2026-03-05', activeDays(days)));
    expect(s.milestones).toEqual([{ day: '2026-03-04', value: 3 }]);
  });

  describe('vacaciones', () => {
    it('no rompen ni consumen congeladores', () => {
      const days = ['2026-03-02', '2026-03-03', '2026-03-04', '2026-03-05', '2026-03-06'];
      const s = computeStreak(
        ctx('2026-03-12', [...activeDays(days), rest('2026-03-12')], [vacation('2026-03-07', '2026-03-11')]),
      );
      expect(s.freezesUsedOn).toEqual([]);
      expect(s.freezes).toBe(1);
      expect(s.current).toBe(6);
    });

    it('los días de vacaciones no suman a la racha', () => {
      const s = computeStreak(
        ctx('2026-03-12', [rest('2026-03-02'), rest('2026-03-12')], [vacation('2026-03-03', '2026-03-11')]),
      );
      expect(s.current).toBe(2);
    });

    it('vacaciones abiertas (sin fin) congelan hasta hoy y no marcan riesgo', () => {
      const s = computeStreak(
        ctx('2026-03-20', activeDays(['2026-03-02', '2026-03-03']), [vacation('2026-03-04', null)]),
      );
      expect(s.current).toBe(2);
      expect(s.atRisk).toBe(false);
      expect(s.freezesUsedOn).toEqual([]);
    });

    it('vacaciones que cruzan semanas y meses', () => {
      const s = computeStreak(
        ctx('2026-04-03', [rest('2026-03-27'), rest('2026-04-03')], [vacation('2026-03-28', '2026-04-02')]),
      );
      expect(s.current).toBe(2);
    });

    it('un hueco antes de las vacaciones sí cuenta', () => {
      const s = computeStreak(
        ctx('2026-03-12', [rest('2026-03-02'), rest('2026-03-12')], [vacation('2026-03-08', '2026-03-11')]),
      );
      // 03..07 vacíos sin vacaciones → corta
      expect(s.current).toBe(1);
    });

    it('actividad durante vacaciones suma normalmente', () => {
      const s = computeStreak(
        ctx('2026-03-05', activeDays(['2026-03-02', '2026-03-03', '2026-03-04']), [vacation('2026-03-03', '2026-03-10')]),
      );
      expect(s.current).toBe(3);
    });
  });

  it('ignora el orden de las actividades de entrada', () => {
    const a = computeStreak(ctx('2026-03-04', activeDays(['2026-03-04', '2026-03-02', '2026-03-03'])));
    expect(a.current).toBe(3);
  });
});
