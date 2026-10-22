import { useState, useEffect, useCallback } from 'react';

let globalSentinel: WakeLockSentinel | null = null;
let globalIsRequested = false;
let globalIsLocked = false;
const listeners = new Set<(isLocked: boolean) => void>();

function notify(locked: boolean) {
  globalIsLocked = locked;
  listeners.forEach((listener) => listener(locked));
}

async function acquireLock(): Promise<boolean> {
  if (typeof navigator === 'undefined' || !('wakeLock' in navigator)) {
    return false;
  }

  // Already active and valid
  if (globalSentinel && !globalSentinel.released) {
    notify(true);
    return true;
  }

  try {
    const sentinel = await navigator.wakeLock.request('screen');
    globalSentinel = sentinel;

    sentinel.addEventListener('release', () => {
      globalSentinel = null;
      notify(false);
      // Re-acquire automatically if wake lock is still desired and document is visible
      if (globalIsRequested && typeof document !== 'undefined' && document.visibilityState === 'visible') {
        acquireLock().catch(() => {});
      }
    });

    notify(true);
    return true;
  } catch (err) {
    console.warn('Wake Lock request failed:', err);
    notify(false);
    return false;
  }
}

async function releaseLock(): Promise<void> {
  globalIsRequested = false;
  if (globalSentinel) {
    try {
      await globalSentinel.release();
    } catch (err) {
      console.warn('Wake Lock release failed:', err);
    } finally {
      globalSentinel = null;
      notify(false);
    }
  } else {
    notify(false);
  }
}

if (typeof document !== 'undefined') {
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && globalIsRequested) {
      acquireLock().catch(() => {});
    }
  });
}

if (typeof window !== 'undefined') {
  window.addEventListener('focus', () => {
    if (globalIsRequested) {
      acquireLock().catch(() => {});
    }
  });

  window.addEventListener('pageshow', () => {
    if (globalIsRequested) {
      acquireLock().catch(() => {});
    }
  });

  // User interactions help re-acquire if lost (especially iOS Safari requirements)
  const handleUserInteraction = () => {
    if (globalIsRequested && (!globalSentinel || globalSentinel.released)) {
      acquireLock().catch(() => {});
    }
  };
  window.addEventListener('click', handleUserInteraction, { passive: true });
  window.addEventListener('touchstart', handleUserInteraction, { passive: true });

  // Heartbeat watchdog: checks every 3 seconds to keep screen awake during workouts
  setInterval(() => {
    if (globalIsRequested && document.visibilityState === 'visible' && (!globalSentinel || globalSentinel.released)) {
      acquireLock().catch(() => {});
    }
  }, 3000);
}

export function useWakeLock() {
  const [isLocked, setIsLocked] = useState(globalIsLocked);
  const [isSupported, setIsSupported] = useState(false);

  useEffect(() => {
    setIsSupported(typeof navigator !== 'undefined' && 'wakeLock' in navigator);
    listeners.add(setIsLocked);
    setIsLocked(globalIsLocked);

    return () => {
      listeners.delete(setIsLocked);
    };
  }, []);

  const requestWakeLock = useCallback(async () => {
    globalIsRequested = true;
    return acquireLock();
  }, []);

  const releaseWakeLock = useCallback(async () => {
    return releaseLock();
  }, []);

  return {
    isSupported,
    isLocked,
    requestWakeLock,
    releaseWakeLock,
  };
}
