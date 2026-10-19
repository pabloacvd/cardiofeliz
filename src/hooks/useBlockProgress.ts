import { useCallback, useEffect, useRef, useState } from 'react';
import type { Bloque, RutinaData } from '../types/workout';
import { userStorageKey } from '../utils/userStorage';
import { todayKey } from '../gamification/dates';
import { blockKey, migrateBlockProgress, pruneBlockProgress, type BlockProgress } from '../utils/workoutDay';

function storageKey(userId: string): string {
  return userStorageKey(userId, 'block_progress');
}

function save(userId: string, progress: BlockProgress): void {
  try {
    localStorage.setItem(storageKey(userId), JSON.stringify(progress));
  } catch {
    // storage no disponible: el progreso queda solo en memoria
  }
}

/**
 * Lee el progreso de hoy y convierte las claves viejas por índice (`dia_X_bloque_N`) a claves por id
 * con la rutina vigente. Si algo cambió, guarda el resultado: la conversión corre una sola vez.
 */
function load(userId: string, rutina: RutinaData): BlockProgress {
  try {
    const raw = localStorage.getItem(storageKey(userId));
    const parsed: unknown = raw ? JSON.parse(raw) : {};
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return {};
    const pruned = pruneBlockProgress(parsed as BlockProgress, todayKey());
    const migrated = migrateBlockProgress(pruned, rutina);
    const changed =
      Object.keys(migrated).length !== Object.keys(parsed as BlockProgress).length ||
      Object.keys(migrated).some((key) => !(key in (parsed as BlockProgress)));
    if (changed) save(userId, migrated);
    return migrated;
  } catch {
    return {};
  }
}

/**
 * Bloques completados HOY, indexados por `{diaId, bloque.id}`. Cada día de entrenamiento empieza
 * de cero: lo que se completó en fechas anteriores se descarta (el historial vive en las actividades).
 * Las claves viejas `completed_blocks` / `completed_days` / `workout_logs` se ignoran.
 * Al cargar una rutina nueva (remota o editada), re-migra claves que hubieran quedado sin resolver.
 */
export function useBlockProgress(userId: string, rutina: RutinaData) {
  const [progress, setProgress] = useState<BlockProgress>(() => load(userId, rutina));
  const progressRef = useRef(progress);
  progressRef.current = progress;

  // Si la rutina o el usuario cambian, re-migramos claves viejas que pudieran haber quedado sin resolver
  useEffect(() => {
    const pruned = pruneBlockProgress(progressRef.current, todayKey());
    const migrated = migrateBlockProgress(pruned, rutina);
    const changed =
      Object.keys(migrated).length !== Object.keys(progressRef.current).length ||
      Object.keys(migrated).some((key) => !(key in progressRef.current));
    if (changed) {
      progressRef.current = migrated;
      setProgress(migrated);
      save(userId, migrated);
    }
  }, [rutina, userId]);

  /** Registra el bloque y devuelve el progreso actualizado (síncrono, para decidir si terminó el día). */
  const recordBlock = useCallback(
    (diaId: string, bloque: Bloque, durationSeconds: number, rounds?: number): BlockProgress => {
      if (!bloque.id) return progressRef.current;
      const today = todayKey();
      const next: BlockProgress = {
        ...pruneBlockProgress(progressRef.current, today),
        [blockKey(diaId, bloque.id)]: {
          date: today,
          completedAt: new Date().toISOString(),
          durationSeconds,
          rounds,
          tipoBloque: bloque.tipo,
          bloqueNombre: bloque.nombre,
        },
      };
      progressRef.current = next;
      setProgress(next);
      save(userId, next);
      return next;
    },
    [userId],
  );

  return { progress, recordBlock };
}
