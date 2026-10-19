import { describe, expect, it } from 'vitest';
import { estimateCalories, metForRun, sanitizeWeight } from '../calories';
import { levelFromXp, mascotStage, tierNameForLevel, xpForLevel } from '../levels';
import { activityBaseXp, computeActivityXp, computeXp } from '../xp';
import { GAME_CONFIG } from '../config';
import { activeDays, ctx, rest, run, vacation, workout } from './helpers';

describe('calorías', () => {
  it('sin peso válido no estima', () => {
    expect(estimateCalories({ type: 'run', durationSeconds: 1800 }, null)).toBeNull();
    expect(estimateCalories({ type: 'run', durationSeconds: 1800 }, undefined)).toBeNull();
    expect(estimateCalories({ type: 'run', durationSeconds: 1800 }, 5)).toBeNull();
    expect(estimateCalories({ type: 'run', durationSeconds: 1800 }, 500)).toBeNull();
    expect(estimateCalories({ type: 'run', durationSeconds: 1800 }, Number.NaN)).toBeNull();
    expect(sanitizeWeight(60)).toBe(60);
  });

  it('entrenamiento: MET 8 × peso × horas', () => {
    expect(estimateCalories({ type: 'workout_day', durationSeconds: 3600 }, 60)).toBe(480);
    expect(estimateCalories({ type: 'workout_day', durationSeconds: 1800 }, 70)).toBe(280);
  });

  it('descanso activo usa MET bajo', () => {
    expect(estimateCalories({ type: 'active_rest', durationSeconds: 3600 }, 60)).toBe(180);
  });

  it('corrida sin distancia usa el MET moderado', () => {
    expect(metForRun(null, 30)).toBe(GAME_CONFIG.calories.met.runDefault);
    expect(estimateCalories({ type: 'run', durationSeconds: 1800 }, 60)).toBe(Math.round(8.3 * 60 * 0.5));
  });

  it('corrida con distancia interpola por velocidad', () => {
    // 4 km en 30 min = 8 km/h → MET 8.3
    expect(metForRun(4, 30)).toBeCloseTo(8.3, 5);
    // 5 km en 30 min = 10 km/h → entre 9.8 y 11.0
    const met = metForRun(5, 30);
    expect(met).toBeGreaterThan(9.8);
    expect(met).toBeLessThan(11);
  });

  it('una corrida más rápida quema más por minuto', () => {
    expect(metForRun(6, 30)).toBeGreaterThan(metForRun(4, 30));
  });

  it('velocidades inverosímiles usan el valor por defecto', () => {
    expect(metForRun(50, 10)).toBe(GAME_CONFIG.calories.met.runDefault); // 300 km/h
    expect(metForRun(0.1, 60)).toBe(GAME_CONFIG.calories.met.runDefault); // 0.1 km/h
    expect(metForRun(-3, 30)).toBe(GAME_CONFIG.calories.met.runDefault);
    expect(metForRun(5, 0)).toBe(GAME_CONFIG.calories.met.runDefault);
  });

  it('duración inválida da 0 calorías', () => {
    expect(estimateCalories({ type: 'workout_day', durationSeconds: -10 }, 60)).toBe(0);
    expect(estimateCalories({ type: 'workout_day', durationSeconds: Number.NaN }, 60)).toBe(0);
  });
});

describe('niveles', () => {
  it('el nivel 1 empieza en 0 XP', () => {
    expect(xpForLevel(1)).toBe(0);
    expect(levelFromXp(0)).toMatchObject({ level: 1, xpIntoLevel: 0, progress: 0 });
  });

  it('la curva es creciente', () => {
    expect(xpForLevel(2)).toBe(100);
    expect(xpForLevel(3)).toBe(300);
    expect(xpForLevel(4)).toBe(600);
  });

  it('sube de nivel justo en el umbral', () => {
    expect(levelFromXp(99).level).toBe(1);
    expect(levelFromXp(100).level).toBe(2);
    expect(levelFromXp(299).level).toBe(2);
    expect(levelFromXp(300).level).toBe(3);
  });

  it('calcula el progreso dentro del nivel', () => {
    const l = levelFromXp(200);
    expect(l.level).toBe(2);
    expect(l.xpIntoLevel).toBe(100);
    expect(l.xpForNextLevel).toBe(200);
    expect(l.progress).toBe(0.5);
  });

  it('valores inválidos o negativos caen al nivel 1', () => {
    expect(levelFromXp(-50).level).toBe(1);
    expect(levelFromXp(Number.NaN).level).toBe(1);
    expect(levelFromXp(Number.POSITIVE_INFINITY).level).toBe(1);
  });

  it('XP muy alto no se rompe', () => {
    const l = levelFromXp(5_000_000);
    expect(l.level).toBeGreaterThan(100);
    expect(l.xpIntoLevel).toBeGreaterThanOrEqual(0);
    expect(l.progress).toBeLessThan(1);
  });

  it('nombre de rango y etapa de la mascota según el nivel', () => {
    expect(tierNameForLevel(1)).toBe('Calentando motores');
    expect(tierNameForLevel(10)).toBe('Imparable');
    expect(tierNameForLevel(99)).toBe('Leyenda');
    expect(mascotStage(1).stage).toBe(1);
    expect(mascotStage(4).stage).toBe(2);
    expect(mascotStage(7).stage).toBe(2);
    expect(mascotStage(8).stage).toBe(3);
    expect(mascotStage(100).stage).toBe(5);
  });
});

describe('XP por actividad', () => {
  it('entrenamiento base y bloques extra', () => {
    expect(activityBaseXp({ type: 'workout_day', durationSeconds: 0, blocksCompleted: 3 })).toBe(100);
    expect(activityBaseXp({ type: 'workout_day', durationSeconds: 0, blocksCompleted: 5 })).toBe(120);
    expect(activityBaseXp({ type: 'workout_day', durationSeconds: 0, blocksCompleted: 1 })).toBe(100);
    expect(activityBaseXp({ type: 'workout_day', durationSeconds: 0 })).toBe(100);
  });

  it('corrida: base, bonus por tiempo (tope) y por km', () => {
    expect(activityBaseXp({ type: 'run', durationSeconds: 30 * 60 })).toBe(60);
    expect(activityBaseXp({ type: 'run', durationSeconds: 45 * 60 })).toBe(63);
    expect(activityBaseXp({ type: 'run', durationSeconds: 20 * 60 })).toBe(60);
    expect(activityBaseXp({ type: 'run', durationSeconds: 30 * 60, distanceKm: 4 })).toBe(70);
    expect(activityBaseXp({ type: 'run', durationSeconds: 24 * 3600 })).toBe(60 + 20);
  });

  it('descanso activo', () => {
    expect(activityBaseXp({ type: 'active_rest', durationSeconds: 600 })).toBe(20);
  });

  it('el bono de regreso multiplica el XP de la actividad', () => {
    const v = [vacation('2026-03-01', '2026-03-10')];
    const a = workout('2026-03-11');
    expect(computeActivityXp(ctx('2026-03-11', [a], v), a)).toBe(150);
    const later = workout('2026-03-20');
    expect(computeActivityXp(ctx('2026-03-20', [later], v), later)).toBe(100);
  });
});

describe('XP total derivado', () => {
  it('sin actividades es 0', () => {
    expect(computeXp(ctx('2026-03-10')).total).toBe(0);
  });

  it('suma actividades más sus misiones', () => {
    const c = ctx('2026-03-02', [workout('2026-03-02')]);
    const xp = computeXp(c);
    expect(xp.activities).toBe(100);
    expect(xp.total).toBeGreaterThanOrEqual(100);
    expect(xp.total).toBe(
      xp.activities + xp.comebackBonus + xp.perfectWeeks + xp.challenges + xp.missions + xp.streakMilestones,
    );
  });

  it('solo el primer descanso activo del día suma XP', () => {
    const one = computeXp(ctx('2026-03-02', [rest('2026-03-02')]));
    const three = computeXp(ctx('2026-03-02', [rest('2026-03-02'), rest('2026-03-02'), rest('2026-03-02')]));
    expect(three.activities).toBe(one.activities);
  });

  it('no usa el xpEarned guardado: se recalcula con las reglas vigentes', () => {
    const inflated = computeXp(ctx('2026-03-02', [workout('2026-03-02', { xpEarned: 99999 })]));
    expect(inflated.activities).toBe(100);
  });

  it('el bono de regreso aparece en el desglose', () => {
    const v = [vacation('2026-03-01', '2026-03-10')];
    const xp = computeXp(ctx('2026-03-11', [workout('2026-03-11')], v));
    expect(xp.activities).toBe(100);
    expect(xp.comebackBonus).toBe(50);
  });

  it('una semana perfecta suma su bonus', () => {
    const acts = [
      workout('2026-03-02'), run('2026-03-03'), workout('2026-03-04'), run('2026-03-05'), workout('2026-03-06'),
    ];
    const xp = computeXp(ctx('2026-03-08', acts));
    expect(xp.perfectWeeks).toBe(150);
  });

  it('los hitos de racha suman bonus una sola vez', () => {
    const xp = computeXp(ctx('2026-03-04', activeDays(['2026-03-02', '2026-03-03', '2026-03-04'])));
    expect(xp.streakMilestones).toBe(20);
  });
});
