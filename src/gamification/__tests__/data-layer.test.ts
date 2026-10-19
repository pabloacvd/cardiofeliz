import { describe, expect, it } from 'vitest';
import type { Bloque, DiaEntrenamiento, RutinaData } from '../../types/workout';
import { mergeRemoteActivities, newActivityId, sortActivities } from '../../utils/activitySync';
import {
  blockKey,
  buildWorkoutDayActivity,
  isDayFinished,
  migrateBlockProgress,
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
    { id: 'a', tipo: 'EMOM', nombre: 'A', duracion_minutos: 10, ejercicios: [] },
    { id: 'b', tipo: 'AMRAP', nombre: 'B', duracion_minutos: 8, ejercicios: [] },
    { id: 'c', tipo: 'FINISHER', nombre: 'C', ejercicios: [] },
  ],
};

const rutina: RutinaData = { usuario: 'Test', edad: 30, objetivo: 'x', dias_entrenamiento: [dia] };

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
      [blockKey('dia_1', 'a')]: entry({ date: '2026-03-09' }),
      [blockKey('dia_1', 'b')]: entry({ date: '2026-03-10' }),
    };
    expect(Object.keys(pruneBlockProgress(progress, '2026-03-10'))).toEqual([blockKey('dia_1', 'b')]);
  });

  it('el día termina cuando están todos los bloques, en cualquier orden', () => {
    const partial: BlockProgress = { [blockKey('dia_1', 'c')]: entry(), [blockKey('dia_1', 'a')]: entry() };
    expect(isDayFinished(dia, partial)).toBe(false);
    expect(isDayFinished(dia, { ...partial, [blockKey('dia_1', 'b')]: entry() })).toBe(true);
  });

  it('un día sin bloques nunca se considera terminado', () => {
    expect(isDayFinished({ ...dia, bloques: [] }, {})).toBe(false);
  });

  it('un bloque sin id nunca cuenta como completado', () => {
    const sinId: Bloque = { tipo: 'EMOM', nombre: 'X', duracion_minutos: 5, ejercicios: [] };
    expect(isDayFinished({ ...dia, bloques: [sinId] }, { [blockKey('dia_1', 'undefined')]: entry() })).toBe(false);
  });

  it('un bloque agregado después de completar el resto reabre el día', () => {
    const all: BlockProgress = {
      [blockKey('dia_1', 'a')]: entry(),
      [blockKey('dia_1', 'b')]: entry(),
      [blockKey('dia_1', 'c')]: entry(),
    };
    expect(isDayFinished(dia, all)).toBe(true);
    const nuevo: Bloque = { id: 'd', tipo: 'AMRAP', nombre: 'D', duracion_minutos: 5, ejercicios: [] };
    expect(isDayFinished({ ...dia, bloques: [...dia.bloques, nuevo] }, all)).toBe(false);
  });

  it('un bloque borrado no bloquea el día y su progreso se ignora', () => {
    const progress: BlockProgress = { [blockKey('dia_1', 'a')]: entry(), [blockKey('dia_1', 'c')]: entry() };
    const sinB = { ...dia, bloques: [dia.bloques[0], dia.bloques[2]] };
    expect(isDayFinished(dia, progress)).toBe(false);
    expect(isDayFinished(sinB, progress)).toBe(true);
    expect(buildWorkoutDayActivity(sinB, progress, '2026-03-10').blocksCompleted).toBe(2);
  });

  it('reordenar bloques conserva el progreso de cada uno', () => {
    const progress: BlockProgress = { [blockKey('dia_1', 'c')]: entry({ durationSeconds: 300 }) };
    const reordenado = { ...dia, bloques: [dia.bloques[2], dia.bloques[0], dia.bloques[1]] };
    const draft = buildWorkoutDayActivity(reordenado, progress, '2026-03-10');
    expect(draft.blocksCompleted).toBe(1);
    expect(draft.durationSeconds).toBe(300);
  });

  it('arma la actividad sumando duración, rondas y bloques', () => {
    const progress: BlockProgress = {
      [blockKey('dia_1', 'a')]: entry({ durationSeconds: 600, completedAt: '2026-03-10T10:10:00.000Z' }),
      [blockKey('dia_1', 'b')]: entry({ durationSeconds: 480, rounds: 5, completedAt: '2026-03-10T10:20:00.000Z' }),
      [blockKey('dia_1', 'c')]: entry({ durationSeconds: 300, rounds: 2, completedAt: '2026-03-10T10:26:00.000Z' }),
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
    const draft = buildWorkoutDayActivity(dia, { [blockKey('dia_1', 'a')]: entry() }, '2026-03-10');
    expect(draft.roundsTotal).toBeNull();
  });
});

describe('migración de claves de progreso por índice a id', () => {
  it('convierte dia_X_bloque_N a la clave por id con la rutina vigente', () => {
    const old: BlockProgress = { dia_1_bloque_0: entry(), dia_1_bloque_2: entry({ bloqueNombre: 'C' }) };
    const migrated = migrateBlockProgress(old, rutina);
    expect(Object.keys(migrated).sort()).toEqual([blockKey('dia_1', 'a'), blockKey('dia_1', 'c')].sort());
    expect(migrated[blockKey('dia_1', 'c')].bloqueNombre).toBe('C');
    expect(isDayFinished({ ...dia, bloques: [dia.bloques[0], dia.bloques[2]] }, migrated)).toBe(true);
  });

  it('es idempotente: migrar dos veces da el mismo resultado', () => {
    const once = migrateBlockProgress({ dia_1_bloque_1: entry() }, rutina);
    expect(migrateBlockProgress(once, rutina)).toEqual(once);
  });

  it('no pierde datos: conserva claves no resolubles (día borrado, índice fuera de rango)', () => {
    const old: BlockProgress = { dia_9_bloque_0: entry(), dia_1_bloque_7: entry(), dia_1_bloque_0: entry() };
    const migrated = migrateBlockProgress(old, rutina);
    expect(Object.keys(migrated)).toHaveLength(3);
    expect(migrated.dia_9_bloque_0).toBeDefined();
    expect(migrated.dia_1_bloque_7).toBeDefined();
    expect(migrated[blockKey('dia_1', 'a')]).toBeDefined();
  });

  it('si ya existe la clave nueva, esa gana sobre la vieja', () => {
    const nueva = entry({ durationSeconds: 999 });
    const old: BlockProgress = { dia_1_bloque_0: entry({ durationSeconds: 1 }), [blockKey('dia_1', 'a')]: nueva };
    expect(migrateBlockProgress(old, rutina)[blockKey('dia_1', 'a')]).toBe(nueva);
  });

  it('no modifica el objeto original', () => {
    const old: BlockProgress = { dia_1_bloque_0: entry() };
    migrateBlockProgress(old, rutina);
    expect(Object.keys(old)).toEqual(['dia_1_bloque_0']);
  });

  it('no hace nada con progreso vacío', () => {
    expect(migrateBlockProgress({}, rutina)).toEqual({});
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
