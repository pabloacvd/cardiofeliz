import { useCallback, useEffect, useRef, useState } from 'react';
import type { Activity, VacationPeriod } from '../types/gamification';
import { computeActivityXp, estimateCalories } from '../gamification';
import { deleteActivityRemote, fetchAllActivities, pushActivity } from '../lib/activitiesApi';
import { loadActivityCache, saveActivityCache, type ActivityCache } from '../utils/activityCache';
import { mergeRemoteActivities, newActivityId, sortActivities } from '../utils/activitySync';
import type { ActivityDraft } from '../utils/workoutDay';

export type SyncStatus = 'synced' | 'syncing' | 'pending' | 'offline';

const RETRY_INTERVAL_MS = 60_000;

export interface AddActivityOptions {
  weightKg?: number | null;
  vacations?: readonly VacationPeriod[];
}

/**
 * Actividades local-first: cada actividad se guarda al instante en localStorage y se sube
 * a Supabase en segundo plano. Si no hay conexión queda en cola y se reintenta al abrir,
 * al volver `online`, al volver a la pestaña y cada minuto mientras haya pendientes.
 * El id lo genera el cliente, así que reintentar nunca duplica.
 */
export function useActivities(userId: string) {
  const [cache, setCache] = useState<ActivityCache>(() => loadActivityCache(userId));
  const cacheRef = useRef(cache);
  const [isSyncing, setIsSyncing] = useState(false);
  const [hasSyncError, setHasSyncError] = useState(false);
  const syncingRef = useRef(false);
  const rerunRef = useRef(false);

  const commit = useCallback(
    (updater: (current: ActivityCache) => ActivityCache) => {
      const next = updater(cacheRef.current);
      cacheRef.current = next;
      setCache(next);
      saveActivityCache(userId, next);
    },
    [userId],
  );

  const sync = useCallback(async () => {
    if (syncingRef.current) {
      rerunRef.current = true;
      return;
    }
    syncingRef.current = true;
    setIsSyncing(true);
    try {
      do {
        rerunRef.current = false;

        // 1. Aplicar borrados pendientes.
        for (const id of [...cacheRef.current.deleted]) {
          await deleteActivityRemote(id);
          commit((c) => ({ ...c, deleted: c.deleted.filter((d) => d !== id) }));
        }

        // 2. Subir pendientes en orden (altas y ediciones).
        for (const id of [...cacheRef.current.pending]) {
          const activity = cacheRef.current.activities.find((a) => a.id === id);
          if (activity) await pushActivity(activity, userId);
          // Si se editó mientras subía, sigue pendiente con su versión nueva.
          commit((c) =>
            c.activities.find((a) => a.id === id) === activity
              ? { ...c, pending: c.pending.filter((p) => p !== id) }
              : c,
          );
        }

        // 3. Hidratar desde el servidor (otro dispositivo, o primera vez en este).
        const remote = await fetchAllActivities();
        commit((c) => ({
          ...c,
          activities: mergeRemoteActivities(c.activities, remote, new Set(c.pending), new Set(c.deleted)),
        }));
      } while (rerunRef.current);
      setHasSyncError(false);
    } catch {
      setHasSyncError(true);
    } finally {
      syncingRef.current = false;
      setIsSyncing(false);
    }
  }, [userId, commit]);

  const trySync = useCallback(() => {
    if (typeof navigator !== 'undefined' && navigator.onLine === false) {
      setHasSyncError(true);
      return;
    }
    void sync();
  }, [sync]);

  // Al abrir, al volver la conexión y al volver a la pestaña.
  useEffect(() => {
    trySync();
    const onVisible = () => {
      if (document.visibilityState === 'visible') trySync();
    };
    window.addEventListener('online', trySync);
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      window.removeEventListener('online', trySync);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, [trySync]);

  // Reintento periódico solo mientras queden pendientes.
  const hasPending = cache.pending.length > 0 || cache.deleted.length > 0;
  useEffect(() => {
    if (!hasPending) return;
    const timer = window.setInterval(trySync, RETRY_INTERVAL_MS);
    return () => window.clearInterval(timer);
  }, [hasPending, trySync]);

  /** Guarda la actividad al instante (con XP y calorías calculados) y dispara la subida. */
  const addActivity = useCallback(
    (draft: ActivityDraft, options: AddActivityOptions = {}): Activity => {
      const base: Activity = { ...draft, id: newActivityId(), userId, xpEarned: 0, caloriesKcal: null };
      const activity = withDerivedValues(base, options, cacheRef.current.activities);
      activity.createdAt = new Date().toISOString();
      commit((c) => ({
        ...c,
        activities: sortActivities([...c.activities, activity]),
        pending: [...c.pending, activity.id],
      }));
      trySync();
      return activity;
    },
    [userId, commit, trySync],
  );

  /** Corrige una actividad ya guardada (recalcula XP y calorías) y la vuelve a subir. */
  const updateActivity = useCallback(
    (id: string, patch: Partial<ActivityDraft>, options: AddActivityOptions = {}): Activity | null => {
      const current = cacheRef.current.activities.find((a) => a.id === id);
      if (!current) return null;
      const others = cacheRef.current.activities.filter((a) => a.id !== id);
      const updated = withDerivedValues({ ...current, ...patch }, options, others);
      commit((c) => ({
        ...c,
        activities: sortActivities(c.activities.map((a) => (a.id === id ? updated : a))),
        pending: c.pending.includes(id) ? c.pending : [...c.pending, id],
      }));
      trySync();
      return updated;
    },
    [commit, trySync],
  );

  /** Borra una actividad (por ejemplo, un registro duplicado por error). */
  const removeActivity = useCallback(
    (id: string) => {
      commit((c) => ({
        activities: c.activities.filter((a) => a.id !== id),
        pending: c.pending.filter((p) => p !== id),
        deleted: c.deleted.includes(id) ? c.deleted : [...c.deleted, id],
      }));
      trySync();
    },
    [commit, trySync],
  );

  /** Completa las calorías de actividades guardadas sin peso, una vez que el peso se conoce. */
  const fillMissingCalories = useCallback(
    (weightKg: number) => {
      const filled = new Map<string, Activity>();
      for (const a of cacheRef.current.activities) {
        if (a.caloriesKcal != null) continue;
        const kcal = estimateCalories(a, weightKg);
        if (kcal !== null) filled.set(a.id, { ...a, caloriesKcal: kcal });
      }
      if (filled.size === 0) return;
      commit((c) => ({
        ...c,
        activities: c.activities.map((a) => filled.get(a.id) ?? a),
        pending: [...new Set([...c.pending, ...filled.keys()])],
      }));
      trySync();
    },
    [commit, trySync],
  );

  const syncStatus: SyncStatus = hasPending
    ? isSyncing
      ? 'syncing'
      : 'pending'
    : hasSyncError
      ? 'offline'
      : isSyncing
        ? 'syncing'
        : 'synced';

  return {
    activities: cache.activities,
    addActivity,
    updateActivity,
    removeActivity,
    fillMissingCalories,
    syncStatus,
  };
}

/** Calcula XP (con bono de regreso) y calorías estimadas de una actividad. */
function withDerivedValues(
  activity: Activity,
  options: AddActivityOptions,
  otherActivities: readonly Activity[],
): Activity {
  return {
    ...activity,
    xpEarned: computeActivityXp(
      { activities: otherActivities, vacations: options.vacations ?? [], today: activity.occurredOn },
      activity,
    ),
    caloriesKcal: estimateCalories(activity, options.weightKg),
  };
}
