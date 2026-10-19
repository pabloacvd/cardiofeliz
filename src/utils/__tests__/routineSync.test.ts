import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  getDefaultRoutine,
  parseAndValidateRoutineCache,
  loadRoutineCache,
  saveRoutineCache,
  resolveRoutineConflict,
  getEffectiveRoutine,
  INITIAL_ROUTINE_CACHE,
  type RoutineCacheState,
} from '../routineSync';
import type { RutinaData } from '../../types/workout';

const SAMPLE_VALID_RUTINA: RutinaData = {
  usuario: 'TestUser',
  edad: 30,
  objetivo: 'Fuerza y acondicionamiento',
  dias_entrenamiento: [
    {
      id: 'dia_custom_1',
      nombre: 'Día Fuerza',
      ubicacion: 'Gimnasio',
      calentamiento: '10 min movilidad',
      bloques: [
        {
          id: 'bloque_custom_a',
          tipo: 'EMOM',
          nombre: 'EMOM Principal',
          duracion_minutos: 15,
          ejercicios: [{ detalle: '10 Dominadas', minuto: 1 }],
        },
      ],
    },
  ],
};

function createLocalStorageMock() {
  let store: Record<string, string> = {};
  return {
    getItem: vi.fn((key: string) => store[key] ?? null),
    setItem: vi.fn((key: string, value: string) => {
      store[key] = String(value);
    }),
    removeItem: vi.fn((key: string) => {
      delete store[key];
    }),
    clear: vi.fn(() => {
      store = {};
    }),
  };
}

let storageMock = createLocalStorageMock();

describe('routineSync - Lógica de caché y sincronización', () => {
  beforeEach(() => {
    storageMock = createLocalStorageMock();
    vi.stubGlobal('localStorage', storageMock);
  });

  describe('getDefaultRoutine', () => {
    it('devuelve la rutina default normalizada asignando el displayName', () => {
      const def = getDefaultRoutine('Carlos');
      expect(def.usuario).toBe('Carlos');
      expect(def.dias_entrenamiento.length).toBeGreaterThan(0);
      // Todos los bloques deben tener id
      for (const dia of def.dias_entrenamiento) {
        for (const bloque of dia.bloques) {
          expect(bloque.id).toBeDefined();
          expect(bloque.id!.length).toBeGreaterThan(0);
        }
      }
    });

    it('respeta el usuario original si displayName viene vacío', () => {
      const def = getDefaultRoutine('');
      expect(def.usuario).toBeTruthy();
    });
  });

  describe('parseAndValidateRoutineCache', () => {
    it('retorna estado inicial ante input nulo o vacío', () => {
      expect(parseAndValidateRoutineCache(null)).toEqual(INITIAL_ROUTINE_CACHE);
      expect(parseAndValidateRoutineCache('')).toEqual(INITIAL_ROUTINE_CACHE);
    });

    it('retorna estado inicial ante JSON malformado o tipos no objeto', () => {
      expect(parseAndValidateRoutineCache('{ invalido ')).toEqual(INITIAL_ROUTINE_CACHE);
      expect(parseAndValidateRoutineCache('["array"]')).toEqual(INITIAL_ROUTINE_CACHE);
      expect(parseAndValidateRoutineCache('123')).toEqual(INITIAL_ROUTINE_CACHE);
    });

    it('parsea y valida una rutina personalizada correcta', () => {
      const cacheData: RoutineCacheState = {
        customRoutine: SAMPLE_VALID_RUTINA,
        updatedAt: '2025-01-01T12:00:00.000Z',
        pendingAction: 'save',
      };

      const result = parseAndValidateRoutineCache(JSON.stringify(cacheData));
      expect(result.customRoutine).not.toBeNull();
      expect(result.customRoutine?.dias_entrenamiento[0].id).toBe('dia_custom_1');
      expect(result.updatedAt).toBe('2025-01-01T12:00:00.000Z');
      expect(result.pendingAction).toBe('save');
    });

    it('descarta customRoutine si es inválida pero preserva updatedAt y pendingAction', () => {
      const corruptData = {
        customRoutine: { usuario: '', edad: -5, dias_entrenamiento: [] }, // Inválido
        updatedAt: '2025-01-01T12:00:00.000Z',
        pendingAction: 'delete',
      };

      const result = parseAndValidateRoutineCache(JSON.stringify(corruptData));
      expect(result.customRoutine).toBeNull();
      expect(result.updatedAt).toBe('2025-01-01T12:00:00.000Z');
      expect(result.pendingAction).toBe('delete');
    });

    it('descarta pendingAction no reconocidas', () => {
      const data = {
        customRoutine: null,
        updatedAt: null,
        pendingAction: 'unknown_action',
      };
      const result = parseAndValidateRoutineCache(JSON.stringify(data));
      expect(result.pendingAction).toBeNull();
    });
  });

  describe('loadRoutineCache y saveRoutineCache', () => {
    it('guarda y lee del localStorage con la clave por usuario', () => {
      const state: RoutineCacheState = {
        customRoutine: SAMPLE_VALID_RUTINA,
        updatedAt: '2025-02-01T10:00:00.000Z',
        pendingAction: null,
      };

      saveRoutineCache('user_123', state);
      const loaded = loadRoutineCache('user_123');

      expect(loaded.customRoutine?.dias_entrenamiento[0].id).toBe('dia_custom_1');
      expect(loaded.updatedAt).toBe('2025-02-01T10:00:00.000Z');
      expect(loaded.pendingAction).toBeNull();

      // No contamina a otro usuario
      const otherLoaded = loadRoutineCache('user_456');
      expect(otherLoaded).toEqual(INITIAL_ROUTINE_CACHE);
    });

    it('maneja fallas de localStorage sin lanzar error', () => {
      storageMock.getItem.mockImplementation(() => {
        throw new Error('Storage denied');
      });
      expect(loadRoutineCache('user_123')).toEqual(INITIAL_ROUTINE_CACHE);

      storageMock.setItem.mockImplementation(() => {
        throw new Error('Storage denied');
      });
      expect(() =>
        saveRoutineCache('user_123', { customRoutine: null, updatedAt: null, pendingAction: null }),
      ).not.toThrow();
    });
  });

  describe('resolveRoutineConflict', () => {
    it('si hay pendingAction local (cambio pendiente sin subir), local gana siempre', () => {
      const local: RoutineCacheState = {
        customRoutine: SAMPLE_VALID_RUTINA,
        updatedAt: '2025-01-01T10:00:00.000Z',
        pendingAction: 'save',
      };

      const remote = {
        data: SAMPLE_VALID_RUTINA,
        updatedAt: '2025-01-02T10:00:00.000Z', // Remoto más nuevo
      };

      const resolved = resolveRoutineConflict(local, remote);
      expect(resolved).toEqual(local);
    });

    it('si remoto es null y no hay pendingAction local, se elimina la rutina personalizada (reseteo remoto)', () => {
      const local: RoutineCacheState = {
        customRoutine: SAMPLE_VALID_RUTINA,
        updatedAt: '2025-01-01T10:00:00.000Z',
        pendingAction: null,
      };

      const resolved = resolveRoutineConflict(local, null);
      expect(resolved).toEqual({
        customRoutine: null,
        updatedAt: null,
        pendingAction: null,
      });
    });

    it('si los datos remotos son corruptos, conserva el estado local', () => {
      const local: RoutineCacheState = {
        customRoutine: SAMPLE_VALID_RUTINA,
        updatedAt: '2025-01-01T10:00:00.000Z',
        pendingAction: null,
      };

      const remote = {
        data: { basura: true }, // Inválido según validateRutina
        updatedAt: '2025-01-02T10:00:00.000Z',
      };

      const resolved = resolveRoutineConflict(local, remote);
      expect(resolved).toEqual(local);
    });

    it('si remoto es más reciente que local, remoto gana', () => {
      const local: RoutineCacheState = {
        customRoutine: SAMPLE_VALID_RUTINA,
        updatedAt: '2025-01-01T10:00:00.000Z',
        pendingAction: null,
      };

      const remoteRutina: RutinaData = {
        ...SAMPLE_VALID_RUTINA,
        usuario: 'RemoteUser',
        objetivo: 'Objetivo Remoto',
      };

      const remote = {
        data: remoteRutina,
        updatedAt: '2025-01-02T10:00:00.000Z',
      };

      const resolved = resolveRoutineConflict(local, remote);
      expect(resolved.customRoutine?.objetivo).toBe('Objetivo Remoto');
      expect(resolved.updatedAt).toBe('2025-01-02T10:00:00.000Z');
      expect(resolved.pendingAction).toBeNull();
    });

    it('si remoto es igual de reciente que local, converge a remoto', () => {
      const local: RoutineCacheState = {
        customRoutine: SAMPLE_VALID_RUTINA,
        updatedAt: '2025-01-01T10:00:00.000Z',
        pendingAction: null,
      };

      const remote = {
        data: SAMPLE_VALID_RUTINA,
        updatedAt: '2025-01-01T10:00:00.000Z',
      };

      const resolved = resolveRoutineConflict(local, remote);
      expect(resolved.updatedAt).toBe('2025-01-01T10:00:00.000Z');
    });

    it('si local es más reciente que remoto, local gana', () => {
      const local: RoutineCacheState = {
        customRoutine: SAMPLE_VALID_RUTINA,
        updatedAt: '2025-01-02T10:00:00.000Z',
        pendingAction: null,
      };

      const remote = {
        data: { ...SAMPLE_VALID_RUTINA, objetivo: 'Remoto Viejo' },
        updatedAt: '2025-01-01T10:00:00.000Z',
      };

      const resolved = resolveRoutineConflict(local, remote);
      expect(resolved).toEqual(local);
    });

    it('si local no tiene updatedAt, remoto gana', () => {
      const local: RoutineCacheState = {
        customRoutine: null,
        updatedAt: null,
        pendingAction: null,
      };

      const remote = {
        data: SAMPLE_VALID_RUTINA,
        updatedAt: '2025-01-01T10:00:00.000Z',
      };

      const resolved = resolveRoutineConflict(local, remote);
      expect(resolved.customRoutine).not.toBeNull();
      expect(resolved.updatedAt).toBe('2025-01-01T10:00:00.000Z');
    });
  });

  describe('getEffectiveRoutine', () => {
    it('devuelve la rutina personalizada con el displayName actual', () => {
      const cache: RoutineCacheState = {
        customRoutine: SAMPLE_VALID_RUTINA,
        updatedAt: '2025-01-01T10:00:00.000Z',
        pendingAction: null,
      };

      const effective = getEffectiveRoutine(cache, 'Mariana');
      expect(effective.isCustom).toBe(true);
      expect(effective.rutina.usuario).toBe('Mariana');
      expect(effective.rutina.dias_entrenamiento[0].id).toBe('dia_custom_1');
    });

    it('devuelve la rutina default cuando no hay customRoutine', () => {
      const cache: RoutineCacheState = {
        customRoutine: null,
        updatedAt: null,
        pendingAction: null,
      };

      const effective = getEffectiveRoutine(cache, 'Mariana');
      expect(effective.isCustom).toBe(false);
      expect(effective.rutina.usuario).toBe('Mariana');
      expect(effective.rutina.dias_entrenamiento.length).toBeGreaterThan(0);
    });
  });
});
