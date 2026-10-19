import { describe, it, expect } from 'vitest';
import type { RutinaData, BloqueTabata, BloqueTriserie, BloqueEMOM } from '../../types/workout';
import {
  cloneRutina,
  hasRoutineChanges,
  updateRoutineMeta,
  addDay,
  updateDay,
  removeDay,
  moveDay,
  addBlock,
  updateBlock,
  changeBlockType,
  duplicateBlock,
  removeBlock,
  moveBlock,
  addExercise,
  updateExercise,
  removeExercise,
  moveExercise,
  regenerateTabataStructure,
  renumberEmomExercises,
} from '../routineEdit';

const SAMPLE_RUTINA: RutinaData = {
  usuario: 'Pao',
  edad: 30,
  objetivo: 'Quema de grasa y tonificación',
  dias_entrenamiento: [
    {
      id: 'dia_1',
      nombre: 'Día 1 - Tren Superior',
      ubicacion: 'Gym',
      calentamiento: '5 min trote',
      bloques: [
        {
          id: 'b1',
          tipo: 'EMOM',
          nombre: 'Bloque A',
          duracion_minutos: 12,
          ejercicios: [
            { minuto: 1, detalle: '12 Push-ups' },
            { minuto: 2, detalle: '15 Squats' },
            { minuto: 3, detalle: 'Descanso' },
          ],
        },
      ],
    },
    {
      id: 'dia_2',
      nombre: 'Día 2 - Cardio',
      ubicacion: 'Parque',
      calentamiento: 'Movilidad articular',
      bloques: [
        {
          id: 'b2',
          tipo: 'TABATA',
          nombre: 'Finisher Tabata',
          rondas: 8,
          trabajo_seg: 20,
          descanso_tabata_seg: 10,
          estructura: '20 seg trabajo / 10 seg descanso x 8 rondas',
          ejercicios: [{ detalle: 'Burpees' }],
        },
      ],
    },
  ],
};

describe('routineEdit', () => {
  describe('cloneRutina & hasRoutineChanges', () => {
    it('clones routine deeply without shared references', () => {
      const cloned = cloneRutina(SAMPLE_RUTINA);
      expect(cloned).toEqual(SAMPLE_RUTINA);
      expect(cloned).not.toBe(SAMPLE_RUTINA);
      expect(cloned.dias_entrenamiento).not.toBe(SAMPLE_RUTINA.dias_entrenamiento);
      expect(cloned.dias_entrenamiento[0].bloques).not.toBe(
        SAMPLE_RUTINA.dias_entrenamiento[0].bloques,
      );
    });

    it('detects changes accurately', () => {
      const cloned = cloneRutina(SAMPLE_RUTINA);
      expect(hasRoutineChanges(SAMPLE_RUTINA, cloned)).toBe(false);

      const modified = updateRoutineMeta(SAMPLE_RUTINA, { edad: 31 });
      expect(hasRoutineChanges(SAMPLE_RUTINA, modified)).toBe(true);
    });
  });

  describe('updateRoutineMeta', () => {
    it('updates objetivo and edad', () => {
      const updated = updateRoutineMeta(SAMPLE_RUTINA, {
        objetivo: 'Fuerza y resistencia',
        edad: 35,
      });
      expect(updated.objetivo).toBe('Fuerza y resistencia');
      expect(updated.edad).toBe(35);
      expect(updated.usuario).toBe('Pao');
    });
  });

  describe('Day operations', () => {
    it('addDay adds a new day with generated id and default block', () => {
      const updated = addDay(SAMPLE_RUTINA);
      expect(updated.dias_entrenamiento).toHaveLength(3);
      const newDay = updated.dias_entrenamiento[2];
      expect(newDay.id).toMatch(/^dia_/);
      expect(newDay.nombre).toBe('Día 3');
      expect(newDay.bloques).toHaveLength(1);
      expect(newDay.bloques[0].id).toBeDefined();
    });

    it('updateDay modifies day fields preserving id and blocks', () => {
      const updated = updateDay(SAMPLE_RUTINA, 'dia_1', {
        nombre: 'Día 1 Modificado',
        ubicacion: 'Casa',
        calentamiento: 'Estiramientos dinámicos',
      });
      expect(updated.dias_entrenamiento[0].id).toBe('dia_1');
      expect(updated.dias_entrenamiento[0].nombre).toBe('Día 1 Modificado');
      expect(updated.dias_entrenamiento[0].ubicacion).toBe('Casa');
      expect(updated.dias_entrenamiento[0].calentamiento).toBe('Estiramientos dinámicos');
      expect(updated.dias_entrenamiento[0].bloques).toHaveLength(1);
    });

    it('removeDay removes the day by id', () => {
      const updated = removeDay(SAMPLE_RUTINA, 'dia_1');
      expect(updated.dias_entrenamiento).toHaveLength(1);
      expect(updated.dias_entrenamiento[0].id).toBe('dia_2');
    });

    it('moveDay reorders days', () => {
      const updated = moveDay(SAMPLE_RUTINA, 0, 1);
      expect(updated.dias_entrenamiento[0].id).toBe('dia_2');
      expect(updated.dias_entrenamiento[1].id).toBe('dia_1');
    });
  });

  describe('Block operations', () => {
    it('addBlock adds a block with defaults to the specified day', () => {
      const updated = addBlock(SAMPLE_RUTINA, 'dia_1', 'TRISERIE');
      const day = updated.dias_entrenamiento[0];
      expect(day.bloques).toHaveLength(2);
      const newBlock = day.bloques[1];
      expect(newBlock.tipo).toBe('TRISERIE');
      expect(newBlock.nombre).toBe('Bloque B');
      expect(newBlock.id).toBeDefined();
    });

    it('updateBlock updates fields and regenerates Tabata structure', () => {
      const updated = updateBlock(SAMPLE_RUTINA, 'dia_2', 'b2', {
        rondas: 6,
        trabajo_seg: 30,
        descanso_tabata_seg: 15,
      });
      const block = updated.dias_entrenamiento[1].bloques[0] as BloqueTabata;
      expect(block.rondas).toBe(6);
      expect(block.trabajo_seg).toBe(30);
      expect(block.descanso_tabata_seg).toBe(15);
      expect(block.estructura).toBe('30 seg trabajo / 15 seg descanso x 6 rondas');
    });

    it('updateBlock clears legacy descanso_entre_rondas when descanso_seg is updated', () => {
      const rutinaWithLegacy: RutinaData = {
        ...SAMPLE_RUTINA,
        dias_entrenamiento: [
          {
            id: 'dia_legacy',
            nombre: 'Legacy Day',
            ubicacion: 'Gym',
            calentamiento: 'Trote',
            bloques: [
              {
                id: 'b_leg',
                tipo: 'TRISERIE',
                nombre: 'Triserie 1',
                rondas: 4,
                descanso_seg: 45,
                descanso_entre_rondas: '45 seg',
                ejercicios: [{ detalle: 'Ej 1' }],
              },
            ],
          },
        ],
      };

      const updated = updateBlock(rutinaWithLegacy, 'dia_legacy', 'b_leg', {
        descanso_seg: 60,
      });
      const block = updated.dias_entrenamiento[0].bloques[0] as BloqueTriserie;
      expect(block.descanso_seg).toBe(60);
      expect(block.descanso_entre_rondas).toBeUndefined();
    });

    it('changeBlockType converts block keeping id, name, and adapts exercises', () => {
      // From EMOM to AMRAP: exercises should lose minuto
      const toAmrap = changeBlockType(SAMPLE_RUTINA, 'dia_1', 'b1', 'AMRAP');
      const amrapBlock = toAmrap.dias_entrenamiento[0].bloques[0];
      expect(amrapBlock.id).toBe('b1');
      expect(amrapBlock.tipo).toBe('AMRAP');
      expect(amrapBlock.nombre).toBe('Bloque A');
      expect(amrapBlock.ejercicios).toHaveLength(3);
      expect(amrapBlock.ejercicios[0]).toEqual({ detalle: '12 Push-ups' });

      // From AMRAP to EMOM: exercises should gain minuto (1..3)
      const toEmom = changeBlockType(toAmrap, 'dia_1', 'b1', 'EMOM');
      const emomBlock = toEmom.dias_entrenamiento[0].bloques[0] as BloqueEMOM;
      expect(emomBlock.tipo).toBe('EMOM');
      expect(emomBlock.ejercicios[0]).toEqual({ minuto: 1, detalle: '12 Push-ups' });
      expect(emomBlock.ejercicios[1]).toEqual({ minuto: 2, detalle: '15 Squats' });
      expect(emomBlock.ejercicios[2]).toEqual({ minuto: 3, detalle: 'Descanso' });
    });

    it('duplicateBlock duplicates block with new id and copies exercises', () => {
      const updated = duplicateBlock(SAMPLE_RUTINA, 'dia_1', 'b1');
      const day = updated.dias_entrenamiento[0];
      expect(day.bloques).toHaveLength(2);
      expect(day.bloques[0].id).toBe('b1');
      expect(day.bloques[1].id).not.toBe('b1');
      expect(day.bloques[1].nombre).toBe('Bloque A (Copia)');
      expect(day.bloques[1].ejercicios).toEqual(day.bloques[0].ejercicios);
    });

    it('removeBlock removes block from day', () => {
      const updated = removeBlock(SAMPLE_RUTINA, 'dia_1', 'b1');
      expect(updated.dias_entrenamiento[0].bloques).toHaveLength(0);
    });

    it('moveBlock reorders blocks in day', () => {
      const withTwoBlocks = addBlock(SAMPLE_RUTINA, 'dia_1', 'AMRAP');
      const b2Id = withTwoBlocks.dias_entrenamiento[0].bloques[1].id!;
      const moved = moveBlock(withTwoBlocks, 'dia_1', 0, 1);
      expect(moved.dias_entrenamiento[0].bloques[0].id).toBe(b2Id);
      expect(moved.dias_entrenamiento[0].bloques[1].id).toBe('b1');
    });
  });

  describe('Exercise operations', () => {
    it('addExercise appends exercise and assigns minuto if EMOM', () => {
      const updated = addExercise(SAMPLE_RUTINA, 'dia_1', 'b1', '20 Lunges');
      const block = updated.dias_entrenamiento[0].bloques[0];
      expect(block.ejercicios).toHaveLength(4);
      expect(block.ejercicios[3]).toEqual({ minuto: 4, detalle: '20 Lunges' });
    });

    it('addExercise adds generic exercise with optional seconds', () => {
      const updated = addExercise(SAMPLE_RUTINA, 'dia_2', 'b2', 'Plank', 45);
      const block = updated.dias_entrenamiento[1].bloques[0];
      expect(block.ejercicios).toHaveLength(2);
      expect(block.ejercicios[1]).toEqual({ detalle: 'Plank', segundos: 45 });
    });

    it('updateExercise updates detalle and seconds', () => {
      const updated = updateExercise(SAMPLE_RUTINA, 'dia_2', 'b2', 0, {
        detalle: 'Burpees modificados',
        segundos: 20,
      });
      const block = updated.dias_entrenamiento[1].bloques[0];
      expect(block.ejercicios[0]).toEqual({
        detalle: 'Burpees modificados',
        segundos: 20,
      });
    });

    it('removeExercise removes exercise and renumbers EMOM', () => {
      // Remove middle exercise (index 1)
      const updated = removeExercise(SAMPLE_RUTINA, 'dia_1', 'b1', 1);
      const block = updated.dias_entrenamiento[0].bloques[0];
      expect(block.ejercicios).toHaveLength(2);
      expect(block.ejercicios[0]).toEqual({ minuto: 1, detalle: '12 Push-ups' });
      expect(block.ejercicios[1]).toEqual({ minuto: 2, detalle: 'Descanso' });
    });

    it('moveExercise reorders exercises and renumbers EMOM', () => {
      // Move first exercise to end (from 0 to 2)
      const updated = moveExercise(SAMPLE_RUTINA, 'dia_1', 'b1', 0, 2);
      const block = updated.dias_entrenamiento[0].bloques[0];
      expect(block.ejercicios[0]).toEqual({ minuto: 1, detalle: '15 Squats' });
      expect(block.ejercicios[1]).toEqual({ minuto: 2, detalle: 'Descanso' });
      expect(block.ejercicios[2]).toEqual({ minuto: 3, detalle: '12 Push-ups' });
    });
  });

  describe('helpers', () => {
    it('regenerateTabataStructure formats correctly', () => {
      expect(regenerateTabataStructure(8, 20, 10)).toBe(
        '20 seg trabajo / 10 seg descanso x 8 rondas',
      );
    });

    it('renumberEmomExercises numbers sequentially from 1', () => {
      const list = [{ detalle: 'A' }, { detalle: 'B' }, { detalle: 'C' }];
      expect(renumberEmomExercises(list)).toEqual([
        { minuto: 1, detalle: 'A' },
        { minuto: 2, detalle: 'B' },
        { minuto: 3, detalle: 'C' },
      ]);
    });
  });
});
