import { describe, expect, it } from 'vitest';
import rutinaJson from '../../data/rutina.json';
import type { Bloque, RutinaData } from '../../types/workout';
import {
  buildFinisherPhases,
  DEFAULT_FINISHER_REST_SECONDS,
  finisherProgress,
  finisherTotalSeconds,
  getFinisherRounds,
  getTabataConfig,
  getTriserieConfig,
  isRestExercise,
  parseRestSeconds,
} from '../timerConfig';

const rutina = rutinaJson as unknown as RutinaData;

function findBloque(diaId: string, bloqueId: string): Bloque {
  const bloque = rutina.dias_entrenamiento
    .find((d) => d.id === diaId)
    ?.bloques.find((b) => b.id === bloqueId);
  if (!bloque) throw new Error(`Bloque no encontrado: ${diaId}/${bloqueId}`);
  return bloque;
}

describe('parseRestSeconds', () => {
  it('interpreta segundos y minutos', () => {
    expect(parseRestSeconds('45 seg')).toBe(45);
    expect(parseRestSeconds('45s')).toBe(45);
    expect(parseRestSeconds('1 min')).toBe(60);
  });

  it('devuelve undefined si no hay número', () => {
    expect(parseRestSeconds(undefined)).toBeUndefined();
    expect(parseRestSeconds('sin descanso')).toBeUndefined();
  });
});

describe('getTriserieConfig', () => {
  it('usa defaults 4 rondas y 45 s', () => {
    expect(getTriserieConfig({})).toEqual({ rounds: 4, restSeconds: 45 });
  });

  it('prioriza rondas y descanso_seg del bloque', () => {
    expect(getTriserieConfig({ rondas: 6, descanso_seg: 20, descanso_entre_rondas: '45 seg' })).toEqual({
      rounds: 6,
      restSeconds: 20,
    });
  });

  it('acepta descanso_seg = 0 (sin descanso)', () => {
    expect(getTriserieConfig({ descanso_seg: 0 }).restSeconds).toBe(0);
  });

  it('cae al string descanso_entre_rondas si no hay descanso_seg', () => {
    expect(getTriserieConfig({ descanso_entre_rondas: '60 seg' }).restSeconds).toBe(60);
  });

  it('ignora valores inválidos', () => {
    expect(getTriserieConfig({ rondas: -2, descanso_seg: 1.5 })).toEqual({ rounds: 4, restSeconds: 45 });
  });

  it('lee el Density del Día 2 A', () => {
    expect(getTriserieConfig(findBloque('dia_2', 'dia_2_bloque_a'))).toEqual({ rounds: 4, restSeconds: 45 });
  });
});

describe('getTabataConfig', () => {
  it('usa defaults 8 / 20 / 10', () => {
    expect(getTabataConfig({})).toEqual({ rounds: 8, workSeconds: 20, restSeconds: 10 });
  });

  it('lee los campos del bloque', () => {
    expect(getTabataConfig({ rondas: 6, trabajo_seg: 30, descanso_tabata_seg: 15 })).toEqual({
      rounds: 6,
      workSeconds: 30,
      restSeconds: 15,
    });
  });

  it('lee el Tabata del Día 3 C', () => {
    expect(getTabataConfig(findBloque('dia_3', 'dia_3_bloque_c'))).toEqual({
      rounds: 8,
      workSeconds: 20,
      restSeconds: 10,
    });
  });
});

describe('isRestExercise / getFinisherRounds', () => {
  it('detecta descanso sin importar mayúsculas', () => {
    expect(isRestExercise({ detalle: 'Descanso total' })).toBe(true);
    expect(isRestExercise({ detalle: 'Burpees' })).toBe(false);
    expect(isRestExercise(undefined)).toBe(false);
  });

  it('default de 3 rondas', () => {
    expect(getFinisherRounds({})).toBe(3);
    expect(getFinisherRounds({ rondas: 5 })).toBe(5);
  });
});

describe('buildFinisherPhases', () => {
  it('HIIT Día 1 B: divide en trabajo/transición y descansa 60 s, 4 rondas = 12 min', () => {
    const phases = buildFinisherPhases(findBloque('dia_1', 'dia_1_bloque_b') as never);

    expect(phases).toHaveLength(20);
    const firstRound = phases.slice(0, 5).map((p) => [p.kind, p.seconds, p.exerciseIndex]);
    expect(firstRound).toEqual([
      ['WORK', 40, 0],
      ['TRANSITION', 20, 0],
      ['WORK', 40, 1],
      ['TRANSITION', 20, 1],
      ['REST', 60, 2],
    ]);
    expect(phases[5].round).toBe(2);
    expect(phases[19].round).toBe(4);
    expect(finisherTotalSeconds(phases)).toBe(720);
  });

  it('Finisher Día 1: pasos por repeticiones son manuales y el descanso corre solo', () => {
    const phases = buildFinisherPhases(findBloque('dia_1', 'dia_1_bloque_c') as never);

    expect(phases).toHaveLength(9);
    expect(phases.slice(0, 3).map((p) => [p.kind, p.seconds])).toEqual([
      ['MANUAL', null],
      ['MANUAL', null],
      ['REST', 30],
    ]);
    expect(finisherTotalSeconds(phases)).toBeNull();
  });

  it('Finisher Día 2: tres pasos de 30 s por 3 rondas', () => {
    const phases = buildFinisherPhases(findBloque('dia_2', 'dia_2_bloque_c') as never);

    expect(phases).toHaveLength(9);
    expect(phases.map((p) => p.kind)).toEqual(['WORK', 'WORK', 'REST', 'WORK', 'WORK', 'REST', 'WORK', 'WORK', 'REST']);
    expect(finisherTotalSeconds(phases)).toBe(270);
  });

  it('sin trabajo_seg el paso corre entero', () => {
    const phases = buildFinisherPhases({
      rondas: 1,
      ejercicios: [{ detalle: 'Bike', segundos: 60 }],
    });
    expect(phases).toEqual([
      { kind: 'WORK', round: 1, exerciseIndex: 0, detalle: 'Bike', seconds: 60 },
    ]);
  });

  it('si segundos <= trabajo_seg no divide', () => {
    const phases = buildFinisherPhases({
      rondas: 1,
      trabajo_seg: 40,
      ejercicios: [{ detalle: 'Bike', segundos: 40 }],
    });
    expect(phases.map((p) => [p.kind, p.seconds])).toEqual([['WORK', 40]]);
  });

  it('descanso sin segundos usa el default y nunca se divide', () => {
    const phases = buildFinisherPhases({
      rondas: 1,
      trabajo_seg: 10,
      ejercicios: [{ detalle: 'Descanso' }, { detalle: 'Descanso largo', segundos: 90 }],
    });
    expect(phases.map((p) => [p.kind, p.seconds])).toEqual([
      ['REST', DEFAULT_FINISHER_REST_SECONDS],
      ['REST', 90],
    ]);
  });

  it('sin ejercicios no hay fases', () => {
    expect(buildFinisherPhases({ ejercicios: [] })).toEqual([]);
  });
});

describe('finisherProgress', () => {
  const phases = buildFinisherPhases({
    rondas: 2,
    ejercicios: [{ detalle: 'A', segundos: 30 }, { detalle: 'Descanso', segundos: 30 }],
  });

  it('empieza en 0 y termina en 1', () => {
    expect(finisherProgress(phases, 0, 30)).toBe(0);
    expect(finisherProgress(phases, 3, 0)).toBe(1);
  });

  it('cuenta fases previas y avance dentro de la fase', () => {
    // 4 fases de 30 s = 120 s; fase 2 con 15 s restantes → 30+30+15 = 75 s
    expect(finisherProgress(phases, 2, 15)).toBeCloseTo(75 / 120);
  });

  it('devuelve 0 sin fases', () => {
    expect(finisherProgress([], 0, 0)).toBe(0);
  });

  it('los pasos manuales avanzan por fase, sin depender de segundos', () => {
    const manual = buildFinisherPhases({
      rondas: 1,
      ejercicios: [{ detalle: '20 Twists' }, { detalle: '20 Climbers' }],
    });
    expect(finisherProgress(manual, 0, 0)).toBe(0);
    expect(finisherProgress(manual, 1, 0)).toBeCloseTo(0.5);
  });
});
