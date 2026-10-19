import { useCallback, useState } from 'react';
import type { ToastItem } from '../utils/celebrations';

/** Cola de avisos. Un aviso con el mismo id que otro visible no se repite. */
export function useToasts() {
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  const push = useCallback((items: readonly ToastItem[]) => {
    if (items.length === 0) return;
    setToasts((current) => {
      const visible = new Set(current.map((t) => t.id));
      return [...current, ...items.filter((i) => !visible.has(i.id))];
    });
  }, []);

  const dismiss = useCallback((id: string) => {
    setToasts((current) => current.filter((t) => t.id !== id));
  }, []);

  return { toasts, push, dismiss };
}
