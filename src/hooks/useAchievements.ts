import { useCallback, useEffect, useRef, useState } from 'react';
import { fetchAchievements, pushAchievements } from '../lib/achievementsApi';
import { userStorageKey } from '../utils/userStorage';

interface AchievementCache {
  /** id del logro → fecha de desbloqueo (ISO). */
  unlocked: Record<string, string>;
  /** Ids registrados localmente que todavía no se subieron a Supabase. */
  pending: string[];
}

function load(userId: string): AchievementCache {
  try {
    const raw = localStorage.getItem(userStorageKey(userId, 'achievements'));
    const parsed: unknown = raw ? JSON.parse(raw) : null;
    if (typeof parsed === 'object' && parsed !== null) {
      const p = parsed as Record<string, unknown>;
      const unlocked: Record<string, string> = {};
      if (typeof p.unlocked === 'object' && p.unlocked !== null) {
        for (const [id, at] of Object.entries(p.unlocked)) {
          if (typeof at === 'string') unlocked[id] = at;
        }
      }
      const pending = Array.isArray(p.pending)
        ? p.pending.filter((id): id is string => typeof id === 'string' && id in unlocked)
        : [];
      return { unlocked, pending };
    }
  } catch {
    // datos corruptos: se ignoran
  }
  return { unlocked: {}, pending: [] };
}

/**
 * Logros desbloqueados (cf_achievements), local-first. Sirven para celebrar cada logro una sola vez:
 * `claimNew(ids)` devuelve solo los que todavía no estaban registrados y los registra.
 * El estado de cada logro (progreso, bloqueado o no) se sigue derivando del historial.
 */
export function useAchievements(userId: string) {
  const [cache, setCache] = useState<AchievementCache>(() => load(userId));
  const cacheRef = useRef(cache);
  const syncingRef = useRef(false);

  const commit = useCallback(
    (next: AchievementCache) => {
      cacheRef.current = next;
      setCache(next);
      try {
        localStorage.setItem(userStorageKey(userId, 'achievements'), JSON.stringify(next));
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
      const toPush = cacheRef.current.pending.map((id) => ({
        achievementId: id,
        unlockedAt: cacheRef.current.unlocked[id],
      }));
      if (toPush.length > 0) {
        await pushAchievements(toPush, userId);
        const sent = new Set(toPush.map((p) => p.achievementId));
        commit({ ...cacheRef.current, pending: cacheRef.current.pending.filter((id) => !sent.has(id)) });
      }
      const remote = await fetchAchievements();
      const unlocked = { ...cacheRef.current.unlocked };
      for (const r of remote) {
        // Gana la fecha más antigua: es la del primer desbloqueo.
        if (!unlocked[r.achievementId] || r.unlockedAt < unlocked[r.achievementId]) {
          unlocked[r.achievementId] = r.unlockedAt;
        }
      }
      commit({ ...cacheRef.current, unlocked });
    } catch {
      // sin conexión: queda pendiente y se reintenta al abrir o al volver `online`
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

  /** Registra los logros nuevos y devuelve solo los que no estaban registrados. */
  const claimNew = useCallback(
    (ids: readonly string[]): string[] => {
      const fresh = [...new Set(ids)].filter((id) => !(id in cacheRef.current.unlocked));
      if (fresh.length === 0) return [];
      const now = new Date().toISOString();
      const unlocked = { ...cacheRef.current.unlocked };
      for (const id of fresh) unlocked[id] = now;
      commit({ unlocked, pending: [...cacheRef.current.pending, ...fresh] });
      void sync();
      return fresh;
    },
    [commit, sync],
  );

  return { unlockedAt: cache.unlocked, claimNew };
}
