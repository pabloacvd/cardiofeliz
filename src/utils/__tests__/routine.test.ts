import { describe, expect, it } from 'vitest';
import type { RutinaData } from '../../types/workout';
import {
  generateId,
  newBloqueDefaults,
  normalizeRutina,
  TIPOS_VALIDOS,
  validateRutina,
} from '../../utils/routine';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function makeRutina(overrides: Partial<RutinaData> = {}): RutinaData {
  return {
    usuario: 'Test',
    edad: 30,
    objetivo: 'Fitness general',
    dias_entrenamiento: [
      {
        id: 'dia_1',
        nombre: 'Día 1',
        ubicacion: 'Gym',
        calentamiento: '5 min',
        bloques: [
          { tipo: 'EMOM', nombre: 'A', duracion_minutos: 10, ejercicios: [] },
          { tipo: 'FINISHER', nombre: 'B', ejercicios: [] },
        ],
      },
    ],
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// generateId
// ---------------------------------------------------------------------------

describe('generateId', () => {
  it('genera ids de 12 caracteres por defecto', () => {
    expect(generateId()).toHaveLength(12);
  });

  it('genera ids únicos', () => {
    const ids = new Set(Array.from({ length: 100 }, () => generateId()));
    expect(ids.size).toBe(100);
  });
});

// ---------------------------------------------------------------------------
// normalizeRutina
// ---------------------------------------------------------------------------

describe('normalizeRutina', () => {
  it('asigna id a los bloques que no lo tienen', () => {
    const rutina = makeRutina();
    const normalized = normalizeRutina(rutina);
    for (const dia of normalized.dias_entrenamiento) {
      for (const bloque of dia.bloques) {
        expect(typeof bloque.id).toBe('string');
        expect(bloque.id!.length).toBeGreaterThan(0);
      }
    }
  });

  it('no reasigna el id si ya existe', () => {
    const rutina = makeRutina();
    rutina.dias_entrenamiento[0].bloques[0] = {
      ...rutina.dias_entrenamiento[0].bloques[0],
      id: 'id_estable',
    } as typeof rutina.dias_entrenamiento[0]['bloques'][0];
    const normalized = normalizeRutina(rutina);
    expect(normalized.dias_entrenamiento[0].bloques[0].id).toBe('id_estable');
  });

  it('no muta el objeto original', () => {
    const rutina = makeRutina();
    const copy = JSON.stringify(rutina);
    normalizeRutina(rutina);
    expect(JSON.stringify(rutina)).toBe(copy);
  });

  it('preserva todos los campos del bloque al normalizar', () => {
    const rutina = makeRutina();
    const bloque = rutina.dias_entrenamiento[0].bloques[0];
    const normalized = normalizeRutina(rutina);
    const normalizedBloque = normalized.dias_entrenamiento[0].bloques[0];
    expect(normalizedBloque.tipo).toBe(bloque.tipo);
    expect(normalizedBloque.nombre).toBe(bloque.nombre);
  });
});

// ---------------------------------------------------------------------------
// validateRutina
// ---------------------------------------------------------------------------

describe('validateRutina – estructura válida', () => {
  it('acepta una rutina bien formada', () => {
    const result = validateRutina(makeRutina());
    expect(result.valid).toBe(true);
    expect(result.errors).toHaveLength(0);
  });

  it('acepta todos los tipos válidos', () => {
    for (const tipo of TIPOS_VALIDOS) {
      // Construimos el bloque como unknown para evitar restricciones de tipo en el test
      const bloqueRaw: Record<string, unknown> = { tipo, nombre: 'X', ejercicios: [] };
      if (tipo === 'FOR_TIME') bloqueRaw.cap_minutos = 15;
      if (tipo === 'EMOM' || tipo === 'AMRAP') bloqueRaw.duracion_minutos = 10;

      const rutinaRaw = {
        ...makeRutina(),
        dias_entrenamiento: [
          {
            ...makeRutina().dias_entrenamiento[0],
            bloques: [bloqueRaw],
          },
        ],
      };
      const result = validateRutina(rutinaRaw);
      expect(result.valid, `tipo ${tipo} debería ser válido; errores: ${result.errors.join(', ')}`).toBe(true);
    }
  });
});

describe('validateRutina – errores esperados', () => {
  it('rechaza entradas que no son objetos', () => {
    expect(validateRutina(null).valid).toBe(false);
    expect(validateRutina('hola').valid).toBe(false);
    expect(validateRutina([]).valid).toBe(false);
  });

  it('rechaza usuario vacío', () => {
    const result = validateRutina({ ...makeRutina(), usuario: '' });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('usuario'))).toBe(true);
  });

  it('rechaza edad fuera de rango', () => {
    expect(validateRutina({ ...makeRutina(), edad: 0 }).valid).toBe(false);
    expect(validateRutina({ ...makeRutina(), edad: 200 }).valid).toBe(false);
    expect(validateRutina({ ...makeRutina(), edad: 1.5 }).valid).toBe(false);
  });

  it('rechaza objetivo vacío', () => {
    const result = validateRutina({ ...makeRutina(), objetivo: '' });
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('objetivo'))).toBe(true);
  });

  it('rechaza tipo de bloque desconocido', () => {
    const rutinaRaw = {
      ...makeRutina(),
      dias_entrenamiento: [
        {
          ...makeRutina().dias_entrenamiento[0],
          bloques: [{ tipo: 'CIRCUITO', nombre: 'X', ejercicios: [] }],
        },
      ],
    };
    const result = validateRutina(rutinaRaw);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('CIRCUITO'))).toBe(true);
  });

  it('rechaza ids de día duplicados', () => {
    const rutina = makeRutina();
    rutina.dias_entrenamiento.push({ ...rutina.dias_entrenamiento[0] });
    const result = validateRutina(rutina);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('duplicado'))).toBe(true);
  });

  it('rechaza duracion_minutos negativa', () => {
    const rutinaRaw = {
      ...makeRutina(),
      dias_entrenamiento: [
        {
          ...makeRutina().dias_entrenamiento[0],
          bloques: [{ tipo: 'EMOM', nombre: 'A', duracion_minutos: -5, ejercicios: [] }],
        },
      ],
    };
    const result = validateRutina(rutinaRaw);
    expect(result.valid).toBe(false);
  });

  it('rechaza rondas que no son enteros', () => {
    const rutinaRaw = {
      ...makeRutina(),
      dias_entrenamiento: [
        {
          ...makeRutina().dias_entrenamiento[0],
          bloques: [{ tipo: 'FINISHER', nombre: 'B', rondas: 2.5, ejercicios: [] }],
        },
      ],
    };
    const result = validateRutina(rutinaRaw);
    expect(result.valid).toBe(false);
  });

  it('rechaza detalle de ejercicio vacío', () => {
    const rutina = makeRutina();
    rutina.dias_entrenamiento[0].bloques[0] = {
      tipo: 'FINISHER',
      nombre: 'B',
      ejercicios: [{ detalle: '' }],
    };
    const result = validateRutina(rutina);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes('detalle'))).toBe(true);
  });

  it('rechaza rutina sin días', () => {
    const result = validateRutina({ ...makeRutina(), dias_entrenamiento: [] });
    expect(result.valid).toBe(false);
  });

  it('rechaza cuando dias_entrenamiento no es array', () => {
    const result = validateRutina({ ...makeRutina(), dias_entrenamiento: 'no-array' });
    expect(result.valid).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// newBloqueDefaults
// ---------------------------------------------------------------------------

describe('newBloqueDefaults', () => {
  it('genera un bloque con id para cada tipo válido', () => {
    for (const tipo of TIPOS_VALIDOS) {
      const bloque = newBloqueDefaults(tipo);
      expect(bloque.tipo).toBe(tipo);
      expect(typeof bloque.id).toBe('string');
      expect(bloque.id!.length).toBeGreaterThan(0);
    }
  });

  it('el bloque generado pasa la validación', () => {
    for (const tipo of TIPOS_VALIDOS) {
      const bloque = newBloqueDefaults(tipo);
      // Construimos una rutina mínima para validar el bloque
      const rutina = makeRutina();
      rutina.dias_entrenamiento[0].bloques = [{ ...bloque, nombre: 'Test' }];
      const result = validateRutina(rutina);
      expect(
        result.valid,
        `newBloqueDefaults('${tipo}') genera un bloque inválido: ${result.errors.join(', ')}`,
      ).toBe(true);
    }
  });

  it('cada llamada genera un id distinto', () => {
    const ids = new Set(
      Array.from({ length: 50 }, () => newBloqueDefaults('EMOM').id),
    );
    expect(ids.size).toBe(50);
  });
});
