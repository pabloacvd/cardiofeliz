/**
 * src/utils/routineImport.ts
 *
 * Utilidades puras para importación, exportación y comparación con la rutina por defecto:
 * - parseImportedRoutine: valida tamaño, parsea JSON de forma segura, valida con allowlists,
 *   normaliza ids y fuerza el usuario actual.
 * - serializeRoutine: exporta una rutina a formato JSON legible.
 * - isDefaultRoutine: determina si una rutina coincide con la rutina default original (ignorando usuario).
 */

import type { RutinaData } from '../types/workout';
import { normalizeRutina, validateRutina } from './routine';
import { getDefaultRoutine } from './routineSync';

export const MAX_IMPORT_SIZE_BYTES = 500 * 1024; // 500 KB

export type RoutineImportResult =
  | { ok: true; rutina: RutinaData }
  | { ok: false; errors: string[] };

/**
 * Parsea y valida el texto de una rutina importada.
 * - Verifica el tamaño antes de parsear (máx 500 KB).
 * - Parsea JSON en try/catch devolviendo error genérico si falla.
 * - Descarta cualquier `usuario` presente en el JSON y fuerza el `usuario` provisto (de la sesión).
 * - Valida la estructura mediante `validateRutina`.
 * - Normaliza la rutina completando ids de bloque si faltasen.
 */
export function parseImportedRoutine(text: unknown, usuario: string): RoutineImportResult {
  if (typeof text !== 'string') {
    return { ok: false, errors: ['El contenido debe ser una cadena de texto.'] };
  }

  if (text.trim().length === 0) {
    return { ok: false, errors: ['El archivo o texto está vacío.'] };
  }

  if (text.length > MAX_IMPORT_SIZE_BYTES) {
    return {
      ok: false,
      errors: ['El archivo o texto supera el tamaño máximo permitido (500 KB).'],
    };
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return {
      ok: false,
      errors: ['El archivo no es un JSON válido.'],
    };
  }

  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return {
      ok: false,
      errors: ['La rutina debe ser un objeto JSON válido.'],
    };
  }

  const effectiveUser = (usuario && usuario.trim()) || 'Usuario';
  const dataWithUser = {
    ...(parsed as Record<string, unknown>),
    usuario: effectiveUser,
  };

  const validation = validateRutina(dataWithUser);
  if (!validation.valid) {
    return {
      ok: false,
      errors: validation.errors,
    };
  }

  const normalized = normalizeRutina(dataWithUser as unknown as RutinaData);
  return {
    ok: true,
    rutina: normalized,
  };
}

/**
 * Serializa una rutina a JSON con formato legible (indentado 2 espacios).
 */
export function serializeRoutine(rutina: RutinaData): string {
  return JSON.stringify(rutina, null, 2);
}

/**
 * Compara una rutina contra la rutina por defecto (src/data/rutina.json).
 * La comparación ignora el campo `usuario`.
 */
export function isDefaultRoutine(rutina: RutinaData): boolean {
  if (!rutina || typeof rutina !== 'object') return false;
  const normalized = normalizeRutina(rutina);
  const defaultRoutine = getDefaultRoutine(normalized.usuario);
  const a = { ...normalized, usuario: '' };
  const b = { ...defaultRoutine, usuario: '' };
  return JSON.stringify(a) === JSON.stringify(b);
}
