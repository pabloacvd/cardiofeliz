import { useCallback, useState } from 'react';
import { userStorageKey } from '../utils/userStorage';
import type { DateKey } from '../gamification/dates';

/** El mensaje del coach se muestra y se puede descartar una vez por día. */
export function useCoachDismissal(userId: string, today: DateKey) {
  const key = userStorageKey(userId, 'coach_dismissed_on');
  const [dismissedOn, setDismissedOn] = useState<string | null>(() => {
    try {
      return localStorage.getItem(key);
    } catch {
      return null;
    }
  });

  const dismiss = useCallback(() => {
    setDismissedOn(today);
    try {
      localStorage.setItem(key, today);
    } catch {
      // storage no disponible
    }
  }, [key, today]);

  return { dismissed: dismissedOn === today, dismiss };
}
