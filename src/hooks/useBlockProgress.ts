import { useCallback, useRef, useState } from 'react';
import type { Bloque } from '../types/workout';
import { userStorageKey } from '../utils/userStorage';
import { todayKey } from '../gamification/dates';
import { blockKey, pruneBlockProgress, type BlockProgress } from '../utils/workoutDay';

function storageKey(userId: string): string {
  return userStorageKey(userId, 'block_progress');
}

function load(userId: string): BlockProgress {
  try {
    const raw = localStorage.getItem(storageKey(userId));
    const parsed: unknown = raw ? JSON.parse(raw) : {};
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return {};
    return pruneBlockProgress(parsed as BlockProgress, todayKey());
  } catch {
    return {};
  }
}

/**
 * Bloques completados HOY. Cada día de entrenamiento empieza de cero: lo que se completó
 * en fechas anteriores se descarta (el historial vive en las actividades, no acá).
 * Las claves viejas `completed_blocks` / `completed_days` / `workout_logs` se ignoran.
 */
export function useBlockProgress(userId: string) {
  const [progress, setProgress] = useState<BlockProgress>(() => load(userId));
  const progressRef = useRef(progress);

  /** Registra el bloque y devuelve el progreso actualizado (síncrono, para decidir si terminó el día). */
  const recordBlock = useCallback(
    (diaId: string, blockIndex: number, bloque: Bloque, durationSeconds: number, rounds?: number): BlockProgress => {
      const today = todayKey();
      const next: BlockProgress = {
        ...pruneBlockProgress(progressRef.current, today),
        [blockKey(diaId, blockIndex)]: {
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
      try {
        localStorage.setItem(storageKey(userId), JSON.stringify(next));
      } catch {
        // storage no disponible: el progreso queda solo en memoria
      }
      return next;
    },
    [userId],
  );

  return { progress, recordBlock };
}
