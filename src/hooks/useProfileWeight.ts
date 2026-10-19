import { useCallback, useEffect, useRef, useState } from 'react';
import { sanitizeWeight } from '../gamification';
import { fetchWeightKg, pushWeightKg } from '../lib/profileApi';
import { userStorageKey } from '../utils/userStorage';

interface WeightCache {
  weightKg: number | null;
  /** El peso local todavía no se subió a Supabase. */
  pending: boolean;
}

function load(userId: string): WeightCache {
  try {
    const raw = localStorage.getItem(userStorageKey(userId, 'weight'));
    const parsed: unknown = raw ? JSON.parse(raw) : null;
    if (typeof parsed === 'object' && parsed !== null) {
      const p = parsed as Record<string, unknown>;
      return {
        weightKg: typeof p.weightKg === 'number' ? sanitizeWeight(p.weightKg) : null,
        pending: p.pending === true,
      };
    }
  } catch {
    // datos corruptos: se ignoran
  }
  return { weightKg: null, pending: false };
}

function save(userId: string, cache: WeightCache): void {
  try {
    localStorage.setItem(userStorageKey(userId, 'weight'), JSON.stringify(cache));
  } catch {
    // storage no disponible
  }
}

/**
 * Peso del usuario (para estimar calorías), local-first. Se pide una sola vez y se puede editar.
 * `isLoaded` indica que ya se consultó el servidor (o falló): hasta entonces no hay que pedir el peso
 * si en otro dispositivo ya estaba cargado.
 */
export function useProfileWeight(userId: string) {
  const [cache, setCache] = useState<WeightCache>(() => load(userId));
  const cacheRef = useRef(cache);
  const [isLoaded, setIsLoaded] = useState(cache.weightKg !== null);

  const commit = useCallback(
    (next: WeightCache) => {
      cacheRef.current = next;
      setCache(next);
      save(userId, next);
    },
    [userId],
  );

  const syncWeight = useCallback(async () => {
    try {
      if (cacheRef.current.pending && cacheRef.current.weightKg !== null) {
        const sent = cacheRef.current.weightKg;
        await pushWeightKg(userId, sent);
        if (cacheRef.current.weightKg === sent) commit({ weightKg: sent, pending: false });
        return;
      }
      const remote = sanitizeWeight(await fetchWeightKg(userId));
      if (remote !== null && !cacheRef.current.pending) commit({ weightKg: remote, pending: false });
    } catch {
      // sin conexión: se reintenta al volver a abrir o al guardar
    } finally {
      setIsLoaded(true);
    }
  }, [userId, commit]);

  useEffect(() => {
    void syncWeight();
    const onOnline = () => void syncWeight();
    window.addEventListener('online', onOnline);
    return () => window.removeEventListener('online', onOnline);
  }, [syncWeight]);

  const dismissKey = userStorageKey(userId, 'weight_prompt_dismissed');
  const [promptDismissed, setPromptDismissed] = useState(() => {
    try {
      return localStorage.getItem(dismissKey) === 'true';
    } catch {
      return false;
    }
  });

  /** El usuario eligió "Ahora no": no se vuelve a pedir el peso automáticamente (sí desde "Editar peso"). */
  const dismissPrompt = useCallback(() => {
    setPromptDismissed(true);
    try {
      localStorage.setItem(dismissKey, 'true');
    } catch {
      // storage no disponible
    }
  }, [dismissKey]);

  /** Guarda el peso al instante. Devuelve false si está fuera del rango válido. */
  const setWeightKg = useCallback(
    (value: number): boolean => {
      const weight = sanitizeWeight(value);
      if (weight === null) return false;
      commit({ weightKg: weight, pending: true });
      void syncWeight();
      return true;
    },
    [commit, syncWeight],
  );

  return { weightKg: cache.weightKg, isLoaded, promptDismissed, dismissPrompt, setWeightKg };
}
