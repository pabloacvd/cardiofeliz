import { describe, expect, it } from 'vitest';
import type { DiaEntrenamiento } from '../../types/workout';
import { mergeRemoteActivities, newActivityId, sortActivities } from '../../utils/activitySync';
import {
  blockKey,
  buildWorkoutDayActivity,
  isDayFinished,
  pruneBlockProgress,
  weekCompletedDays,
  type BlockProgress,
  type BlockProgressEntry,
} from '../../utils/workoutDay';
import { run, workout } from './helpers';

const dia: DiaEntrenamiento = {
  id: 'dia_1',
  nombre: 'Día 1',
  ubicacion: 'Gym',
  calentamiento: '',
  bloques: [
    { tipo: 'EMOM', nombre: 'A', duracion_minutos: 10, ejercicios: [] },
    { tipo: 'AMRAP', nombre: 'B', duracion_minutos: 8, ejercicios: [] },
    { tipo: 'FINISHER', nombre: 'C', ejercicios: [] },
  ],
};

function entry(extra: Partial<BlockProgressEntry> = {}): BlockProgressEntry {
  return {
    date: '2026-03-10',
    completedAt: '2026-03-10T10:10:00.000Z',
    durationSeconds: 600,
    tipoBloque: 'EMOM',
    bloqueNombre: 'A',
    ...extra,
  };
}

describe('progreso de bloques del día', () => {
  it('descarta los bloques de fechas anteriores', () => {
    const progress: BlockProgress = {
      [blockKey('dia_1', 0)]: entry({ date: '2026-03-09' }),
      [blockKey('dia_1', 1)]: entry({ date: '2026-03-10' }),
    };
    expect(Object.keys(pruneBlockProgress(progress, '2026-03-10'))).toEqual([blockKey('dia_1', 1)]);
  });

  it('el día termina cuando están todos los bloques, en cualquier orden', () => {
    const partial: BlockProgress = { [blockKey('dia_1', 2)]: entry(), [blockKey('dia_1', 0)]: entry() };
    expect(isDayFinished(dia, partial)).toBe(false);
    expect(isDayFinished(dia, { ...partial, [blockKey('dia_1', 1)]: entry() })).toBe(true);
  });

  it('un día sin bloques nunca se considera terminado', () => {
    expect(isDayFinished({ ...dia, bloques: [] }, {})).toBe(false);
  });

  it('arma la actividad sumando duración, rondas y bloques', () => {
    const progress: BlockProgress = {
      [blockKey('dia_1', 0)]: entry({ durationSeconds: 600, completedAt: '2026-03-10T10:10:00.000Z' }),
      [blockKey('dia_1', 1)]: entry({ durationSeconds: 480, rounds: 5, completedAt: '2026-03-10T10:20:00.000Z' }),
      [blockKey('dia_1', 2)]: entry({ durationSeconds: 300, rounds: 2, completedAt: '2026-03-10T10:26:00.000Z' }),
    };
    const draft = buildWorkoutDayActivity(dia, progress, '2026-03-10');
    expect(draft).toMatchObject({
      type: 'workout_day',
      occurredOn: '2026-03-10',
      dayId: 'dia_1',
      durationSeconds: 1380,
      blocksCompleted: 3,
      roundsTotal: 7,
      startedAt: '2026-03-10T10:00:00.000Z',
    });
  });

  it('sin rondas informadas, roundsTotal es null', () => {
    const draft = buildWorkoutDayActivity(dia, { [blockKey('dia_1', 0)]: entry() }, '2026-03-10');
    expect(draft.roundsTotal).toBeNull();
  });
});

describe('"completado" derivado de la semana actual', () => {
  const today = '2026-03-11'; // miércoles
  const monday = '2026-03-09';

  it('distingue hoy de antes en la semana y excluye semanas anteriores', () => {
    const activities = [
      workout('2026-03-11', { dayId: 'dia_1' }),
      workout('2026-03-09', { dayId: 'dia_2' }),
      workout('2026-03-08', { dayId: 'dia_3' }), // domingo anterior
      run('2026-03-10'),
    ];
    expect(weekCompletedDays(activities, today, monday)).toEqual({ dia_1: 'today', dia_2: 'week' });
  });

  it('"hoy" gana si el mismo día se hizo antes y hoy', () => {
    const activities = [workout('2026-03-09', { dayId: 'dia_1' }), workout('2026-03-11', { dayId: 'dia_1' })];
    expect(weekCompletedDays(activities, today, monday)).toEqual({ dia_1: 'today' });
  });
});

describe('merge de sincronización', () => {
  it('conserva lo pendiente local y toma el resto del servidor', () => {
    const local = [workout('2026-03-10', { id: 'a' }), workout('2026-03-09', { id: 'b' })];
    const remote = [workout('2026-03-09', { id: 'b' }), workout('2026-03-01', { id: 'c' })];
    const merged = mergeRemoteActivities(local, remote, new Set(['a']));
    expect(merged.map((m) => m.id)).toEqual(['a', 'b', 'c']);
  });

  it('una actividad local ya sincronizada pero ausente en el servidor se descarta', () => {
    const local = [workout('2026-03-10', { id: 'a' })];
    expect(mergeRemoteActivities(local, [], new Set())).toEqual([]);
  });

  it('no duplica por id y prioriza la versión local pendiente', () => {
    const local = [workout('2026-03-10', { id: 'a', xpEarned: 150 })];
    const remote = [workout('2026-03-10', { id: 'a', xpEarned: 100 })];
    const merged = mergeRemoteActivities(local, remote, new Set(['a']));
    expect(merged).toHaveLength(1);
    expect(merged[0].xpEarned).toBe(150);
  });

  it('ordena de más reciente a más antigua', () => {
    const sorted = sortActivities([
      workout('2026-03-01', { id: 'x' }),
      workout('2026-03-10', { id: 'y' }),
      workout('2026-03-05', { id: 'z' }),
    ]);
    expect(sorted.map((s) => s.occurredOn)).toEqual(['2026-03-10', '2026-03-05', '2026-03-01']);
  });
});

describe('id de actividad', () => {
  it('genera UUID v4 únicos', () => {
    const ids = new Set(Array.from({ length: 50 }, () => newActivityId()));
    expect(ids.size).toBe(50);
    for (const id of ids) {
      expect(id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    }
  });
});
