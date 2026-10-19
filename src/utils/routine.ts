/**
 * src/utils/routine.ts
 *
 * Utilidades puras para rutinas de entrenamiento:
 * - generateId: genera un id corto basado en crypto.randomUUID.
 * - normalizeRutina: asigna ids de bloque faltantes y completa defaults.
 * - validateRutina: valida una rutina y devuelve errores legibles en español.
 * - newBloqueDefaults: fábrica de bloque nuevo con defaults por tipo.
 */

import type {
  Bloque,
  BloqueBase,
  DiaEntrenamiento,
  RutinaData,
  TipoBloque,
} from '../types/workout';

// ---------------------------------------------------------------------------
// Constantes de validación
// ---------------------------------------------------------------------------

export const TIPOS_VALIDOS: readonly TipoBloque[] = [
  'EMOM',
  'AMRAP',
  'TRISERIE',
  'DENSITY',
  'FOR_TIME',
  'TABATA',
  'FINISHER',
  'HIIT_INTERVALS',
] as const;

const MAX_DIAS = 10;
const MAX_BLOQUES_POR_DIA = 8;
const MAX_EJERCICIOS_POR_BLOQUE = 20;
const MAX_LEN_NOMBRE = 120;
const MAX_LEN_TEXTO_LARGO = 300;
const MAX_DURACION_MIN = 120;
const MAX_CAP_MIN = 120;
const MAX_RONDAS = 99;
const MAX_SEG = 600; // 10 min
const MAX_LEN_ID = 80;
const MAX_LEN_OBJETIVO = 300;
const MAX_EDAD = 120;

// ---------------------------------------------------------------------------
// Generador de ids
// ---------------------------------------------------------------------------

/** Genera un id estable corto (8 caracteres hex). Usa crypto.randomUUID si está disponible. */
export function generateId(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID().replace(/-/g, '').slice(0, 12);
  }
  // Fallback para entornos sin crypto.randomUUID (tests de Node < 19)
  return Math.random().toString(36).slice(2, 14).padEnd(12, '0');
}

// ---------------------------------------------------------------------------
// Normalización
// ---------------------------------------------------------------------------

/**
 * Recibe una rutina (tal como viene de JSON, import o Supabase) y devuelve
 * una copia con ids de bloque asignados donde faltaban.
 * No modifica el objeto original.
 */
export function normalizeRutina(rutina: RutinaData): RutinaData {
  return {
    ...rutina,
    dias_entrenamiento: rutina.dias_entrenamiento.map((dia) =>
      normalizeDia(dia),
    ),
  };
}

function normalizeDia(dia: DiaEntrenamiento): DiaEntrenamiento {
  return {
    ...dia,
    bloques: dia.bloques.map((bloque, idx) => normalizeBloque(bloque, dia.id, idx)),
  };
}

function normalizeBloque(bloque: Bloque, diaId: string, idx: number): Bloque {
  if (bloque.id) return bloque;
  return { ...bloque, id: `${diaId}_bloque_${idx}_${generateId()}` } as Bloque;
}

// ---------------------------------------------------------------------------
// Validación
// ---------------------------------------------------------------------------

export interface ValidationResult {
  valid: boolean;
  errors: string[];
}

/**
 * Valida la estructura de una rutina. Devuelve errores legibles en español.
 * Rechaza tipos no reconocidos, números negativos o fuera de rango,
 * textos demasiado largos e ids de día duplicados.
 */
export function validateRutina(rutina: unknown): ValidationResult {
  const errors: string[] = [];

  if (!rutina || typeof rutina !== 'object' || Array.isArray(rutina)) {
    return { valid: false, errors: ['La rutina debe ser un objeto.'] };
  }

  const r = rutina as Record<string, unknown>;

  // --- Campos raíz ---
  if (typeof r.usuario !== 'string' || r.usuario.trim().length === 0) {
    errors.push('El campo "usuario" debe ser una cadena no vacía.');
  }

  if (typeof r.edad !== 'number' || !Number.isInteger(r.edad) || r.edad < 1 || r.edad > MAX_EDAD) {
    errors.push(`El campo "edad" debe ser un entero entre 1 y ${MAX_EDAD}.`);
  }

  if (typeof r.objetivo !== 'string' || r.objetivo.trim().length === 0) {
    errors.push('El campo "objetivo" debe ser una cadena no vacía.');
  } else if (r.objetivo.length > MAX_LEN_OBJETIVO) {
    errors.push(`El campo "objetivo" no puede superar ${MAX_LEN_OBJETIVO} caracteres.`);
  }

  if (!Array.isArray(r.dias_entrenamiento)) {
    errors.push('El campo "dias_entrenamiento" debe ser un array.');
    return { valid: false, errors };
  }

  if (r.dias_entrenamiento.length === 0) {
    errors.push('La rutina debe tener al menos un día de entrenamiento.');
  }

  if (r.dias_entrenamiento.length > MAX_DIAS) {
    errors.push(`La rutina no puede tener más de ${MAX_DIAS} días de entrenamiento.`);
  }

  // --- Ids de día únicos ---
  const diaIds = new Set<string>();
  for (const [dIdx, dia] of (r.dias_entrenamiento as unknown[]).entries()) {
    validateDia(dia, dIdx, diaIds, errors);
  }

  return { valid: errors.length === 0, errors };
}

function validateDia(
  dia: unknown,
  dIdx: number,
  diaIds: Set<string>,
  errors: string[],
): void {
  const prefix = `Día ${dIdx + 1}`;

  if (!dia || typeof dia !== 'object' || Array.isArray(dia)) {
    errors.push(`${prefix}: debe ser un objeto.`);
    return;
  }

  const d = dia as Record<string, unknown>;

  if (typeof d.id !== 'string' || d.id.trim().length === 0) {
    errors.push(`${prefix}: el campo "id" debe ser una cadena no vacía.`);
  } else if (d.id.length > MAX_LEN_ID) {
    errors.push(`${prefix}: el "id" no puede superar ${MAX_LEN_ID} caracteres.`);
  } else if (diaIds.has(d.id as string)) {
    errors.push(`${prefix}: el id "${d.id}" está duplicado.`);
  } else {
    diaIds.add(d.id as string);
  }

  if (typeof d.nombre !== 'string' || d.nombre.trim().length === 0) {
    errors.push(`${prefix}: el campo "nombre" debe ser una cadena no vacía.`);
  } else if (d.nombre.length > MAX_LEN_NOMBRE) {
    errors.push(`${prefix}: "nombre" no puede superar ${MAX_LEN_NOMBRE} caracteres.`);
  }

  if (typeof d.ubicacion !== 'string') {
    errors.push(`${prefix}: el campo "ubicacion" debe ser una cadena.`);
  } else if (d.ubicacion.length > MAX_LEN_NOMBRE) {
    errors.push(`${prefix}: "ubicacion" no puede superar ${MAX_LEN_NOMBRE} caracteres.`);
  }

  if (typeof d.calentamiento !== 'string') {
    errors.push(`${prefix}: el campo "calentamiento" debe ser una cadena.`);
  } else if (d.calentamiento.length > MAX_LEN_TEXTO_LARGO) {
    errors.push(`${prefix}: "calentamiento" no puede superar ${MAX_LEN_TEXTO_LARGO} caracteres.`);
  }

  if (!Array.isArray(d.bloques)) {
    errors.push(`${prefix}: el campo "bloques" debe ser un array.`);
    return;
  }

  if (d.bloques.length === 0) {
    errors.push(`${prefix}: debe tener al menos un bloque.`);
  }

  if (d.bloques.length > MAX_BLOQUES_POR_DIA) {
    errors.push(`${prefix}: no puede tener más de ${MAX_BLOQUES_POR_DIA} bloques.`);
  }

  for (const [bIdx, bloque] of (d.bloques as unknown[]).entries()) {
    validateBloque(bloque, `${prefix} – Bloque ${bIdx + 1}`, errors);
  }
}

function validateBloque(bloque: unknown, prefix: string, errors: string[]): void {
  if (!bloque || typeof bloque !== 'object' || Array.isArray(bloque)) {
    errors.push(`${prefix}: debe ser un objeto.`);
    return;
  }

  const b = bloque as Record<string, unknown>;

  // tipo
  if (!TIPOS_VALIDOS.includes(b.tipo as TipoBloque)) {
    errors.push(
      `${prefix}: tipo "${b.tipo}" no reconocido. Tipos válidos: ${TIPOS_VALIDOS.join(', ')}.`,
    );
  }

  // nombre
  if (typeof b.nombre !== 'string' || b.nombre.trim().length === 0) {
    errors.push(`${prefix}: el campo "nombre" debe ser una cadena no vacía.`);
  } else if (b.nombre.length > MAX_LEN_NOMBRE) {
    errors.push(`${prefix}: "nombre" no puede superar ${MAX_LEN_NOMBRE} caracteres.`);
  }

  // id (opcional)
  if (b.id !== undefined) {
    if (typeof b.id !== 'string' || b.id.length === 0) {
      errors.push(`${prefix}: el campo "id" debe ser una cadena no vacía si está presente.`);
    } else if (b.id.length > MAX_LEN_ID) {
      errors.push(`${prefix}: "id" no puede superar ${MAX_LEN_ID} caracteres.`);
    }
  }

  // campos numéricos opcionales
  validateOptionalPositiveInt(b.duracion_minutos, `${prefix}: "duracion_minutos"`, 1, MAX_DURACION_MIN, errors);
  validateOptionalPositiveInt(b.cap_minutos, `${prefix}: "cap_minutos"`, 1, MAX_CAP_MIN, errors);
  validateOptionalPositiveInt(b.rondas, `${prefix}: "rondas"`, 1, MAX_RONDAS, errors);
  validateOptionalPositiveInt(b.descanso_seg, `${prefix}: "descanso_seg"`, 0, MAX_SEG, errors);
  validateOptionalPositiveInt(b.trabajo_seg, `${prefix}: "trabajo_seg"`, 1, MAX_SEG, errors);
  validateOptionalPositiveInt(b.descanso_tabata_seg, `${prefix}: "descanso_tabata_seg"`, 1, MAX_SEG, errors);

  // descanso_entre_rondas (string legacy)
  if (b.descanso_entre_rondas !== undefined && typeof b.descanso_entre_rondas !== 'string') {
    errors.push(`${prefix}: "descanso_entre_rondas" debe ser una cadena si está presente.`);
  }

  // estructura (string libre, Tabata)
  if (b.estructura !== undefined && typeof b.estructura !== 'string') {
    errors.push(`${prefix}: "estructura" debe ser una cadena si está presente.`);
  }

  // ejercicios
  if (!Array.isArray(b.ejercicios)) {
    errors.push(`${prefix}: el campo "ejercicios" debe ser un array.`);
    return;
  }

  if (b.ejercicios.length > MAX_EJERCICIOS_POR_BLOQUE) {
    errors.push(`${prefix}: no puede tener más de ${MAX_EJERCICIOS_POR_BLOQUE} ejercicios.`);
  }

  for (const [eIdx, ej] of (b.ejercicios as unknown[]).entries()) {
    validateEjercicio(ej, `${prefix} – Ejercicio ${eIdx + 1}`, errors);
  }
}

function validateEjercicio(ej: unknown, prefix: string, errors: string[]): void {
  if (!ej || typeof ej !== 'object' || Array.isArray(ej)) {
    errors.push(`${prefix}: debe ser un objeto.`);
    return;
  }

  const e = ej as Record<string, unknown>;

  if (typeof e.detalle !== 'string' || e.detalle.trim().length === 0) {
    errors.push(`${prefix}: el campo "detalle" debe ser una cadena no vacía.`);
  } else if (e.detalle.length > MAX_LEN_TEXTO_LARGO) {
    errors.push(`${prefix}: "detalle" no puede superar ${MAX_LEN_TEXTO_LARGO} caracteres.`);
  }

  if (e.segundos !== undefined) {
    validateOptionalPositiveInt(e.segundos, `${prefix}: "segundos"`, 1, MAX_SEG, errors);
  }

  if (e.minuto !== undefined) {
    validateOptionalPositiveInt(e.minuto, `${prefix}: "minuto"`, 1, 60, errors);
  }
}

function validateOptionalPositiveInt(
  value: unknown,
  label: string,
  min: number,
  max: number,
  errors: string[],
): void {
  if (value === undefined || value === null) return;
  if (!Number.isInteger(value) || (value as number) < min || (value as number) > max) {
    errors.push(`${label} debe ser un entero entre ${min} y ${max} (recibido: ${value}).`);
  }
}

// ---------------------------------------------------------------------------
// Fábrica de bloque nuevo
// ---------------------------------------------------------------------------

/**
 * Devuelve un bloque nuevo con defaults sensatos para cada tipo.
 * El id se genera automáticamente.
 */
export function newBloqueDefaults(tipo: TipoBloque): Bloque {
  const id = generateId();
  const base: Omit<BloqueBase, 'tipo'> = {
    id,
    nombre: '',
    ejercicios: [],
  };

  switch (tipo) {
    case 'EMOM':
      return { ...base, tipo: 'EMOM', duracion_minutos: 16, ejercicios: [] };
    case 'AMRAP':
      return { ...base, tipo: 'AMRAP', duracion_minutos: 12, ejercicios: [] };
    case 'TRISERIE':
      return { ...base, tipo: 'TRISERIE', rondas: 4, descanso_seg: 45, descanso_entre_rondas: '45 seg', ejercicios: [] };
    case 'DENSITY':
      return { ...base, tipo: 'DENSITY', rondas: 4, descanso_seg: 45, descanso_entre_rondas: '45 seg', ejercicios: [] };
    case 'FOR_TIME':
      return { ...base, tipo: 'FOR_TIME', cap_minutos: 15, ejercicios: [] };
    case 'TABATA':
      return { ...base, tipo: 'TABATA', rondas: 8, trabajo_seg: 20, descanso_tabata_seg: 10, estructura: '20 seg trabajo / 10 seg descanso x 8 rondas', ejercicios: [] };
    case 'FINISHER':
      return { ...base, tipo: 'FINISHER', rondas: 3, ejercicios: [] };
    case 'HIIT_INTERVALS':
      return { ...base, tipo: 'HIIT_INTERVALS', rondas: 4, duracion_minutos: 12, ejercicios: [] };
  }
}
