import { useCallback, useEffect, useRef, useState } from 'react';
import type { Activity, VacationPeriod } from '../types/gamification';
import { computeActivityXp, estimateCalories } from '../gamification';
import { fetchAllActivities, pushActivity } from '../lib/activitiesApi';
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

        // 1. Subir pendientes en orden.
        for (const id of [...cacheRef.current.pending]) {
          const activity = cacheRef.current.activities.find((a) => a.id === id);
          if (activity) await pushActivity(activity, userId);
          commit((c) => ({ ...c, pending: c.pending.filter((p) => p !== id) }));
        }

        // 2. Hidratar desde el servidor (otro dispositivo, o primera vez en este).
        const remote = await fetchAllActivities();
        commit((c) => ({
          ...c,
          activities: mergeRemoteActivities(c.activities, remote, new Set(c.pending)),
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
  const hasPending = cache.pending.length > 0;
  useEffect(() => {
    if (!hasPending) return;
    const timer = window.setInterval(trySync, RETRY_INTERVAL_MS);
    return () => window.clearInterval(timer);
  }, [hasPending, trySync]);

  /** Guarda la actividad al instante (con XP y calorías calculados) y dispara la subida. */
  const addActivity = useCallback(
    (draft: ActivityDraft, options: AddActivityOptions = {}): Activity => {
      const base: Activity = { ...draft, id: newActivityId(), userId, xpEarned: 0, caloriesKcal: null };
      const activity: Activity = {
        ...base,
        xpEarned: computeActivityXp(
          {
            activities: cacheRef.current.activities,
            vacations: options.vacations ?? [],
            today: draft.occurredOn,
          },
          base,
        ),
        caloriesKcal: estimateCalories(base, options.weightKg),
        createdAt: new Date().toISOString(),
      };
      commit((c) => ({
        activities: sortActivities([...c.activities, activity]),
        pending: [...c.pending, activity.id],
      }));
      trySync();
      return activity;
    },
    [userId, commit, trySync],
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

  return { activities: cache.activities, addActivity, syncStatus };
}
