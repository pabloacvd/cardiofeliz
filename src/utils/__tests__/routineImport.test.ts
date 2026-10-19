import { describe, expect, it } from 'vitest';
import defaultRutinaJson from '../../data/rutina.json';
import type { RutinaData } from '../../types/workout';
import { validateRutina } from '../routine';
import { getDefaultRoutine } from '../routineSync';
import {
  isDefaultRoutine,
  MAX_IMPORT_SIZE_BYTES,
  parseImportedRoutine,
  serializeRoutine,
} from '../routineImport';

describe('routineImport utils', () => {
  const sampleRoutine = getDefaultRoutine('UsuarioTest');

  describe('serializeRoutine', () => {
    it('serializa la rutina a un string JSON formateado con 2 espacios', () => {
      const serialized = serializeRoutine(sampleRoutine);
      expect(typeof serialized).toBe('string');
      expect(serialized).toContain('UsuarioTest');
      const parsed = JSON.parse(serialized);
      expect(parsed.usuario).toBe('UsuarioTest');
      expect(parsed.dias_entrenamiento.length).toBe(sampleRoutine.dias_entrenamiento.length);
    });
  });

  describe('parseImportedRoutine', () => {
    it('parsea correctamente un JSON válido y devuelve ok: true con la rutina normalizada', () => {
      const jsonStr = JSON.stringify(sampleRoutine);
      const res = parseImportedRoutine(jsonStr, 'UsuarioActivo');

      expect(res.ok).toBe(true);
      if (res.ok) {
        expect(res.rutina.usuario).toBe('UsuarioActivo');
        expect(res.rutina.dias_entrenamiento.length).toBe(sampleRoutine.dias_entrenamiento.length);
        expect(res.rutina.dias_entrenamiento[0].bloques[0].id).toBeTruthy();
      }
    });

    it('devuelve error genérico ante un JSON sintácticamente inválido', () => {
      const res = parseImportedRoutine('{ json inválido...', 'UsuarioActivo');
      expect(res.ok).toBe(false);
      if (!res.ok) {
        expect(res.errors).toEqual(['El archivo no es un JSON válido.']);
      }
    });

    it('devuelve error si el contenido está vacío o en blanco', () => {
      const res1 = parseImportedRoutine('', 'UsuarioActivo');
      expect(res1.ok).toBe(false);
      if (!res1.ok) {
        expect(res1.errors).toEqual(['El archivo o texto está vacío.']);
      }

      const res2 = parseImportedRoutine('   ', 'UsuarioActivo');
      expect(res2.ok).toBe(false);
      if (!res2.ok) {
        expect(res2.errors).toEqual(['El archivo o texto está vacío.']);
      }
    });

    it('devuelve error si la entrada no es un string', () => {
      const res = parseImportedRoutine(12345, 'UsuarioActivo');
      expect(res.ok).toBe(false);
      if (!res.ok) {
        expect(res.errors).toEqual(['El contenido debe ser una cadena de texto.']);
      }
    });

    it('devuelve error cuando el tamaño supera el límite de 500 KB sin parsear', () => {
      const hugeString = 'a'.repeat(MAX_IMPORT_SIZE_BYTES + 1);
      const res = parseImportedRoutine(hugeString, 'UsuarioActivo');
      expect(res.ok).toBe(false);
      if (!res.ok) {
        expect(res.errors).toEqual([
          'El archivo o texto supera el tamaño máximo permitido (500 KB).',
        ]);
      }
    });

    it('devuelve error si el JSON parseado es un array o primitivo', () => {
      const resArray = parseImportedRoutine('[]', 'UsuarioActivo');
      expect(resArray.ok).toBe(false);
      if (!resArray.ok) {
        expect(resArray.errors).toEqual(['La rutina debe ser un objeto JSON válido.']);
      }

      const resNumber = parseImportedRoutine('123', 'UsuarioActivo');
      expect(resNumber.ok).toBe(false);

      const resNull = parseImportedRoutine('null', 'UsuarioActivo');
      expect(resNull.ok).toBe(false);
    });

    it('ignora el usuario del JSON importado y fuerza el de la sesión activa', () => {
      const customPayload = {
        ...sampleRoutine,
        usuario: 'OtroUsuarioHacker',
      };
      const res = parseImportedRoutine(JSON.stringify(customPayload), 'MiUsuarioLogueado');

      expect(res.ok).toBe(true);
      if (res.ok) {
        expect(res.rutina.usuario).toBe('MiUsuarioLogueado');
      }
    });

    it('asigna ids a bloques que no los tengan', () => {
      const copyWithoutBlockIds = JSON.parse(JSON.stringify(sampleRoutine));
      delete copyWithoutBlockIds.dias_entrenamiento[0].bloques[0].id;

      const res = parseImportedRoutine(JSON.stringify(copyWithoutBlockIds), 'UsuarioActivo');
      expect(res.ok).toBe(true);
      if (res.ok) {
        expect(res.rutina.dias_entrenamiento[0].bloques[0].id).toBeTruthy();
      }
    });

    it('devuelve errores de validación si faltan campos requeridos o hay datos inválidos', () => {
      const invalidRoutine = {
        usuario: 'Test',
        // missing edad, objetivo, dias_entrenamiento
      };
      const res = parseImportedRoutine(JSON.stringify(invalidRoutine), 'UsuarioActivo');
      expect(res.ok).toBe(false);
      if (!res.ok) {
        expect(res.errors.length).toBeGreaterThan(0);
        expect(res.errors.some((e) => e.includes('edad'))).toBe(true);
        expect(res.errors.some((e) => e.includes('objetivo'))).toBe(true);
      }
    });

    it('maneja payloads con __proto__ sin vulnerabilidad de polución ni fallos', () => {
      const payloadWithProto = `{"__proto__":{"polluted":true},"edad":30,"objetivo":"Salud","dias_entrenamiento":[]}`;
      const res = parseImportedRoutine(payloadWithProto, 'UsuarioActivo');
      // Debe fallar por dias_entrenamiento vacío o validar limpiamente
      expect(res.ok).toBe(false);
      expect((Object.prototype as { polluted?: boolean }).polluted).toBeUndefined();
    });

    it('realiza round-trip exportar -> importar sin pérdida de datos', () => {
      const serialized = serializeRoutine(sampleRoutine);
      const res = parseImportedRoutine(serialized, sampleRoutine.usuario);

      expect(res.ok).toBe(true);
      if (res.ok) {
        expect(res.rutina).toEqual(sampleRoutine);
      }
    });
  });

  describe('isDefaultRoutine', () => {
    it('devuelve true para la rutina default original con cualquier usuario', () => {
      const def1 = getDefaultRoutine('UsuarioUno');
      const def2 = getDefaultRoutine('UsuarioDos');

      expect(isDefaultRoutine(def1)).toBe(true);
      expect(isDefaultRoutine(def2)).toBe(true);
      expect(isDefaultRoutine(defaultRutinaJson as RutinaData)).toBe(true);
    });

    it('devuelve false si se modifica la edad, objetivo o días', () => {
      const modifiedEdad: RutinaData = {
        ...sampleRoutine,
        edad: 99,
      };
      expect(isDefaultRoutine(modifiedEdad)).toBe(false);

      const modifiedObj: RutinaData = {
        ...sampleRoutine,
        objetivo: 'Otro objetivo modificado',
      };
      expect(isDefaultRoutine(modifiedObj)).toBe(false);

      const modifiedDias: RutinaData = {
        ...sampleRoutine,
        dias_entrenamiento: sampleRoutine.dias_entrenamiento.slice(0, 1),
      };
      expect(isDefaultRoutine(modifiedDias)).toBe(false);
    });

    it('devuelve false ante entradas nulas o no válidas', () => {
      // @ts-expect-error test invalid argument
      expect(isDefaultRoutine(null)).toBe(false);
      // @ts-expect-error test invalid argument
      expect(isDefaultRoutine(undefined)).toBe(false);
      // @ts-expect-error test invalid argument
      expect(isDefaultRoutine({})).toBe(false);
    });
  });

  describe('validateRutina robustness with odd inputs', () => {
    it('no revienta con null, undefined, primitivos o arrays', () => {
      expect(validateRutina(null).valid).toBe(false);
      expect(validateRutina(undefined).valid).toBe(false);
      expect(validateRutina(123).valid).toBe(false);
      expect(validateRutina('string').valid).toBe(false);
      expect(validateRutina([]).valid).toBe(false);
    });

    it('no revienta con objetos creados con Object.create(null)', () => {
      const bareObj = Object.create(null);
      const res = validateRutina(bareObj);
      expect(res.valid).toBe(false);
      expect(res.errors.length).toBeGreaterThan(0);
    });

    it('no revienta con campos que contienen tipos inválidos o raros', () => {
      const weirdData = {
        usuario: 'Pepe',
        edad: true, // boolean en vez de number
        objetivo: 12345, // number en vez de string
        dias_entrenamiento: [
          null,
          'no un objeto',
          {
            id: 'dia_1',
            nombre: 'Día 1',
            ubicacion: 'Gym',
            calentamiento: '5m',
            bloques: [
              null,
              {
                tipo: 'EMOM',
                nombre: 'Bloque A',
                duracion_minutos: '16', // string en vez de int
                rondas: true,
                ejercicios: [
                  null,
                  {
                    detalle: 'Ejercicio 1',
                    segundos: 'sesenta',
                  },
                ],
              },
            ],
          },
        ],
      };

      const res = validateRutina(weirdData);
      expect(res.valid).toBe(false);
      expect(res.errors.length).toBeGreaterThan(0);
    });
  });
});
