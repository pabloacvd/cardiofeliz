/**
 * src/utils/routineSync.ts
 *
 * Lógica pura para sincronización, caché y resolución de conflictos de rutinas:
 * - getDefaultRoutine: rutina por defecto normalizada con el nombre del usuario.
 * - parseAndValidateRoutineCache: lee y valida la caché de localStorage.
 * - resolveRoutineConflict: resuelve conflictos entre versión local y remota (última escritura gana por updated_at).
 * - getEffectiveRoutine: devuelve la rutina activa y si es personalizada.
 */

import defaultRutinaJson from '../data/rutina.json';
import type { RutinaData } from '../types/workout';
import { normalizeRutina, validateRutina } from './routine';
import { userStorageKey } from './userStorage';

export interface RoutineCacheState {
  customRoutine: RutinaData | null;
  updatedAt: string | null;
  pendingAction: 'save' | 'delete' | null;
}

export const INITIAL_ROUTINE_CACHE: RoutineCacheState = {
  customRoutine: null,
  updatedAt: null,
  pendingAction: null,
};

/**
 * Devuelve la rutina por defecto (src/data/rutina.json) normalizada,
 * asignando el displayName como usuario.
 */
export function getDefaultRoutine(displayName?: string): RutinaData {
  const normalized = normalizeRutina(defaultRutinaJson as RutinaData);
  return {
    ...normalized,
    usuario: displayName?.trim() || normalized.usuario,
  };
}

/**
 * Parsea y valida el contenido de la caché local de rutina.
 * Si los datos están corruptos o son inválidos, descarta la rutina inválida
 * de forma segura y devuelve el estado saneado.
 */
export function parseAndValidateRoutineCache(raw: string | null): RoutineCacheState {
  if (!raw) return { ...INITIAL_ROUTINE_CACHE };

  try {
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return { ...INITIAL_ROUTINE_CACHE };
    }

    const obj = parsed as Record<string, unknown>;

    let customRoutine: RutinaData | null = null;
    if (obj.customRoutine && typeof obj.customRoutine === 'object') {
      const validation = validateRutina(obj.customRoutine);
      if (validation.valid) {
        customRoutine = normalizeRutina(obj.customRoutine as RutinaData);
      }
    }

    const updatedAt = typeof obj.updatedAt === 'string' ? obj.updatedAt : null;
    const pendingAction =
      obj.pendingAction === 'save' || obj.pendingAction === 'delete'
        ? obj.pendingAction
        : null;

    return {
      customRoutine,
      updatedAt,
      pendingAction,
    };
  } catch {
    return { ...INITIAL_ROUTINE_CACHE };
  }
}

/**
 * Carga el estado de caché de la rutina para un usuario desde localStorage.
 */
export function loadRoutineCache(userId: string): RoutineCacheState {
  try {
    const raw = localStorage.getItem(userStorageKey(userId, 'routine'));
    return parseAndValidateRoutineCache(raw);
  } catch {
    return { ...INITIAL_ROUTINE_CACHE };
  }
}

/**
 * Guarda el estado de caché de la rutina para un usuario en localStorage.
 */
export function saveRoutineCache(userId: string, state: RoutineCacheState): void {
  try {
    localStorage.setItem(userStorageKey(userId, 'routine'), JSON.stringify(state));
  } catch {
    // Storage no disponible: se opera en memoria
  }
}

/**
 * Resuelve conflictos entre el estado local y los datos remotos de Supabase.
 * Regla: Última escritura gana según `updated_at`.
 *
 * - Si local tiene `pendingAction` activa, local tiene cambios pendientes de subir y se conserva.
 * - Si remote es `null` y local no tiene cambios pendientes, significa que remoto no tiene rutina (o fue borrada):
 *   se limpia la rutina personalizada.
 * - Si remote tiene datos:
 *   - Se valida la estructura con `validateRutina`. Si es inválida, se ignora.
 *   - Si es válida y `remote.updatedAt >= local.updatedAt` (o local no tiene updatedAt), remoto gana.
 *   - Si `local.updatedAt > remote.updatedAt`, local gana.
 */
export function resolveRoutineConflict(
  local: RoutineCacheState,
  remote: { data: unknown; updatedAt: string } | null,
): RoutineCacheState {
  // Si hay acciones locales pendientes no sincronizadas, local manda
  if (local.pendingAction !== null) {
    return local;
  }

  // Remoto no tiene rutina guardada (o fue borrada en otro dispositivo)
  if (remote === null) {
    return {
      customRoutine: null,
      updatedAt: null,
      pendingAction: null,
    };
  }

  // Validar datos remotos
  const validation = validateRutina(remote.data);
  if (!validation.valid) {
    // Datos remotos corruptos: conservar local saneado
    return local;
  }

  const normalizedRemote = normalizeRutina(remote.data as RutinaData);

  // Comparar timestamps
  if (!local.updatedAt) {
    // Local no tenía timestamp registrado: remoto gana
    return {
      customRoutine: normalizedRemote,
      updatedAt: remote.updatedAt,
      pendingAction: null,
    };
  }

  const localTime = new Date(local.updatedAt).getTime();
  const remoteTime = new Date(remote.updatedAt).getTime();

  if (isNaN(localTime) || isNaN(remoteTime) || remoteTime >= localTime) {
    // Remoto es más reciente o igual: remoto gana
    return {
      customRoutine: normalizedRemote,
      updatedAt: remote.updatedAt,
      pendingAction: null,
    };
  }

  // Local es más reciente
  return local;
}

/**
 * Devuelve la rutina efectiva a utilizar y un booleano indicando si es personalizada.
 * Garantiza que `usuario` siempre sea el `displayName` actual.
 */
export function getEffectiveRoutine(
  cache: RoutineCacheState,
  displayName: string,
): { rutina: RutinaData; isCustom: boolean } {
  if (cache.customRoutine) {
    return {
      rutina: {
        ...cache.customRoutine,
        usuario: displayName || cache.customRoutine.usuario,
      },
      isCustom: true,
    };
  }

  return {
    rutina: getDefaultRoutine(displayName),
    isCustom: false,
  };
}
