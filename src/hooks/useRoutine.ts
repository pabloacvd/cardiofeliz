import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { createSerialRunner } from '../utils/serialRunner';
import type { RutinaData } from '../types/workout';
import { deleteRoutineRemote, fetchRoutine, pushRoutine } from '../lib/routineApi';
import {
  getEffectiveRoutine,
  loadRoutineCache,
  resolveRoutineConflict,
  saveRoutineCache,
  type RoutineCacheState,
} from '../utils/routineSync';
import { normalizeRutina, validateRutina } from '../utils/routine';

export type RoutineSyncStatus = 'synced' | 'pending' | 'syncing' | 'error';

export interface UseRoutineResult {
  rutina: RutinaData;
  isCustom: boolean;
  saveRoutine: (newRutina: RutinaData) => Promise<void>;
  resetRoutine: () => Promise<void>;
  isLoaded: boolean;
  syncStatus: RoutineSyncStatus;
}

export function useRoutine(userId: string, displayName: string): UseRoutineResult {
  const [cache, setCache] = useState<RoutineCacheState>(() => loadRoutineCache(userId));
  const [isLoaded, setIsLoaded] = useState(true);
  const [syncStatus, setSyncStatus] = useState<RoutineSyncStatus>(
    cache.pendingAction ? 'pending' : 'synced',
  );

  const cacheRef = useRef(cache);
  cacheRef.current = cache;

  const commit = useCallback(
    (next: RoutineCacheState) => {
      cacheRef.current = next;
      setCache(next);
      saveRoutineCache(userId, next);
    },
    [userId],
  );

  // Un solo sync a la vez. Si se pide otro mientras corre (por ejemplo, al guardar durante
  // una subida), se repite apenas termina, así ningún guardado queda sin subir.
  const sync = useMemo(
    () =>
      createSerialRunner(async () => {
        setSyncStatus('syncing');

        try {
          // 1. Procesar borrado pendiente
          if (cacheRef.current.pendingAction === 'delete') {
            try {
              await deleteRoutineRemote(userId);
              // Si mientras tanto se guardó otra rutina, ese guardado sigue pendiente.
              if (cacheRef.current.pendingAction === 'delete') {
                commit({ ...cacheRef.current, pendingAction: null });
              }
            } catch {
              // Si falla (offline / tabla no existe), queda pendiente
              setSyncStatus('pending');
              return;
            }
          }

          // 2. Procesar guardado pendiente
          if (cacheRef.current.pendingAction === 'save' && cacheRef.current.customRoutine) {
            const pushed = cacheRef.current.customRoutine;
            try {
              const { updatedAt } = await pushRoutine(userId, pushed);
              // Solo se da por subido si no hubo otro guardado (u otro borrado) durante la subida.
              if (cacheRef.current.pendingAction === 'save' && cacheRef.current.customRoutine === pushed) {
                commit({ ...cacheRef.current, updatedAt, pendingAction: null });
              }
            } catch {
              // Si falla (offline / tabla no existe), queda pendiente
              setSyncStatus('pending');
              return;
            }
          }

          // 3. Descargar y resolver remoto si no hay acciones pendientes
          if (cacheRef.current.pendingAction === null) {
            const remote = await fetchRoutine(userId);
            // Se evalúa contra la caché actual: si apareció un cambio local, local manda.
            commit(resolveRoutineConflict(cacheRef.current, remote));
          }

          setSyncStatus(cacheRef.current.pendingAction ? 'pending' : 'synced');
        } catch {
          // Sin conexión o fallo en fetch: mantener funcionamiento local sin romper
          setSyncStatus(cacheRef.current.pendingAction ? 'pending' : 'error');
        } finally {
          setIsLoaded(true);
        }
      }),
    [userId, commit],
  );

  // Carga inicial y reintento al volver a estar online
  useEffect(() => {
    void sync();
    const onOnline = () => void sync();
    window.addEventListener('online', onOnline);
    return () => window.removeEventListener('online', onOnline);
  }, [sync]);

  // Si cambia el userId, recargar la caché local correspondiente
  useEffect(() => {
    const loaded = loadRoutineCache(userId);
    setCache(loaded);
    cacheRef.current = loaded;
    setSyncStatus(loaded.pendingAction ? 'pending' : 'synced');
  }, [userId]);

  const saveRoutine = useCallback(
    async (newRutina: RutinaData) => {
      const validation = validateRutina(newRutina);
      if (!validation.valid) {
        throw new Error('La rutina no es válida y no pudo guardarse.');
      }

      const normalized = normalizeRutina(newRutina);
      const nowIso = new Date().toISOString();
      const next: RoutineCacheState = {
        customRoutine: normalized,
        updatedAt: nowIso,
        pendingAction: 'save',
      };
      commit(next);
      setSyncStatus('pending');
      await sync();
    },
    [commit, sync],
  );

  const resetRoutine = useCallback(async () => {
    const nowIso = new Date().toISOString();
    const next: RoutineCacheState = {
      customRoutine: null,
      updatedAt: nowIso,
      pendingAction: 'delete',
    };
    commit(next);
    setSyncStatus('pending');
    await sync();
  }, [commit, sync]);

  const { rutina, isCustom } = useMemo(
    () => getEffectiveRoutine(cache, displayName),
    [cache, displayName],
  );

  return {
    rutina,
    isCustom,
    saveRoutine,
    resetRoutine,
    isLoaded,
    syncStatus,
  };
}
