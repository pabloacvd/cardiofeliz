import { useCallback, useEffect, useRef, useState } from 'react';
import type { VacationPeriod } from '../types/gamification';
import { deleteVacationRemote, fetchVacations, pushVacation } from '../lib/vacationsApi';
import { userStorageKey } from '../utils/userStorage';
import { newActivityId } from '../utils/activitySync';
import { addDays, type DateKey } from '../gamification';

interface VacationCache {
  vacations: VacationPeriod[];
  pending: VacationPeriod[];
  deletedIds: string[];
}

function load(userId: string): VacationCache {
  try {
    const raw = localStorage.getItem(userStorageKey(userId, 'vacations'));
    const parsed: unknown = raw ? JSON.parse(raw) : null;
    if (typeof parsed === 'object' && parsed !== null) {
      const p = parsed as Record<string, unknown>;
      const vacations = Array.isArray(p.vacations) ? (p.vacations as VacationPeriod[]) : [];
      const pending = Array.isArray(p.pending) ? (p.pending as VacationPeriod[]) : [];
      const deletedIds = Array.isArray(p.deletedIds)
        ? (p.deletedIds.filter((id): id is string => typeof id === 'string'))
        : [];
      return { vacations, pending, deletedIds };
    }
  } catch {
    // ignorar datos corruptos
  }
  return { vacations: [], pending: [], deletedIds: [] };
}

export function useVacations(userId: string) {
  const [cache, setCache] = useState<VacationCache>(() => load(userId));
  const cacheRef = useRef(cache);
  const syncingRef = useRef(false);

  const commit = useCallback(
    (next: VacationCache) => {
      cacheRef.current = next;
      setCache(next);
      try {
        localStorage.setItem(userStorageKey(userId, 'vacations'), JSON.stringify(next));
      } catch {
        // storage no disponible
      }
    },
    [userId],
  );

  const sync = useCallback(async () => {
    if (syncingRef.current) return;
    syncingRef.current = true;
    try {
      // 1. Procesar borrados pendientes
      const deleted = [...cacheRef.current.deletedIds];
      for (const id of deleted) {
        await deleteVacationRemote(id);
      }
      if (deleted.length > 0) {
        const deletedSet = new Set(deleted);
        commit({
          ...cacheRef.current,
          deletedIds: cacheRef.current.deletedIds.filter((id) => !deletedSet.has(id)),
        });
      }

      // 2. Subir pendientes
      const pending = [...cacheRef.current.pending];
      for (const v of pending) {
        await pushVacation(v, userId);
      }
      if (pending.length > 0) {
        const pendingSet = new Set(pending.map((p) => p.id));
        commit({
          ...cacheRef.current,
          pending: cacheRef.current.pending.filter((p) => !pendingSet.has(p.id)),
        });
      }

      // 3. Descargar remotos
      const remote = await fetchVacations();
      const pendingMap = new Map(cacheRef.current.pending.map((p) => [p.id, p]));
      const deletedSet = new Set(cacheRef.current.deletedIds);

      const byId = new Map<string, VacationPeriod>();
      for (const r of remote) {
        if (!deletedSet.has(r.id)) byId.set(r.id, r);
      }
      for (const [id, p] of pendingMap) {
        byId.set(id, p);
      }

      const merged = [...byId.values()].sort((a, b) => (a.startOn < b.startOn ? 1 : -1));
      commit({ ...cacheRef.current, vacations: merged });
    } catch {
      // sin conexión: reintentar al volver online
    } finally {
      syncingRef.current = false;
    }
  }, [userId, commit]);

  useEffect(() => {
    void sync();
    const onOnline = () => void sync();
    window.addEventListener('online', onOnline);
    return () => window.removeEventListener('online', onOnline);
  }, [sync]);

  /** Inicia un período de vacaciones activo (endOn = null). */
  const startVacation = useCallback(
    (startOn: DateKey) => {
      const newVacation: VacationPeriod = {
        id: newActivityId(),
        userId,
        startOn,
        endOn: null,
      };
      const vacations = [newVacation, ...cacheRef.current.vacations];
      const pending = [newVacation, ...cacheRef.current.pending];
      commit({ ...cacheRef.current, vacations, pending });
      void sync();
      return newVacation;
    },
    [userId, commit, sync],
  );

  /**
   * Finaliza las vacaciones activas.
   * Si startOn es hoy o en el futuro, se elimina el período.
   * Si startOn < today, se asigna endOn = ayer para que hoy ya sea día 1 de recuperación.
   */
  const endActiveVacation = useCallback(
    (today: DateKey) => {
      const active = cacheRef.current.vacations.find((v) => v.endOn == null);
      if (!active) return;

      const yesterday = addDays(today, -1);
      if (active.startOn > yesterday) {
        // El período empezó hoy o después: se descarta
        const vacations = cacheRef.current.vacations.filter((v) => v.id !== active.id);
        const pending = cacheRef.current.pending.filter((v) => v.id !== active.id);
        const deletedIds = [...cacheRef.current.deletedIds, active.id];
        commit({ vacations, pending, deletedIds });
      } else {
        const updated: VacationPeriod = { ...active, endOn: yesterday };
        const vacations = cacheRef.current.vacations.map((v) => (v.id === active.id ? updated : v));
        const pending = [...cacheRef.current.pending.filter((p) => p.id !== active.id), updated];
        commit({ ...cacheRef.current, vacations, pending });
      }
      void sync();
    },
    [commit, sync],
  );

  const updateVacation = useCallback(
    (id: string, patch: Partial<VacationPeriod>) => {
      const target = cacheRef.current.vacations.find((v) => v.id === id);
      if (!target) return;
      const updated = { ...target, ...patch };
      const vacations = cacheRef.current.vacations.map((v) => (v.id === id ? updated : v));
      const pending = [...cacheRef.current.pending.filter((p) => p.id !== id), updated];
      commit({ ...cacheRef.current, vacations, pending });
      void sync();
    },
    [commit, sync],
  );

  const deleteVacation = useCallback(
    (id: string) => {
      const vacations = cacheRef.current.vacations.filter((v) => v.id !== id);
      const pending = cacheRef.current.pending.filter((p) => p.id !== id);
      const deletedIds = [...cacheRef.current.deletedIds, id];
      commit({ vacations, pending, deletedIds });
      void sync();
    },
    [commit, sync],
  );

  return {
    vacations: cache.vacations,
    startVacation,
    endActiveVacation,
    updateVacation,
    deleteVacation,
    syncVacations: sync,
  };
}
