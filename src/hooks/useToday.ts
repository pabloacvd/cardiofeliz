import { useEffect, useState } from 'react';
import { todayKey, type DateKey } from '../gamification/dates';

/** Fecha local de hoy, actualizada al volver a la app o al pasar la medianoche. */
export function useToday(): DateKey {
  const [today, setToday] = useState<DateKey>(() => todayKey());

  useEffect(() => {
    const refresh = () => setToday(todayKey());
    const timer = window.setInterval(refresh, 60_000);
    document.addEventListener('visibilitychange', refresh);
    window.addEventListener('focus', refresh);
    return () => {
      window.clearInterval(timer);
      document.removeEventListener('visibilitychange', refresh);
      window.removeEventListener('focus', refresh);
    };
  }, []);

  return today;
}
