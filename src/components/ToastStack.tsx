import React, { useEffect } from 'react';
import { Award, ArrowUp, Snowflake, X, type LucideIcon } from 'lucide-react';
import type { ToastItem, ToastKind } from '../utils/celebrations';

const TOAST_VISIBLE_MS = 6000;

const KIND_ICON: Record<ToastKind, LucideIcon> = {
  achievement: Award,
  level: ArrowUp,
  freeze: Snowflake,
};

const KIND_STYLE: Record<ToastKind, string> = {
  achievement: 'border-amber-500/50 text-amber-300',
  level: 'border-purple-500/50 text-purple-300',
  freeze: 'border-cyan-500/50 text-cyan-300',
};

const ToastView: React.FC<{ toast: ToastItem; onDismiss: (id: string) => void }> = ({ toast, onDismiss }) => {
  useEffect(() => {
    const timer = window.setTimeout(() => onDismiss(toast.id), TOAST_VISIBLE_MS);
    return () => window.clearTimeout(timer);
  }, [toast.id, onDismiss]);

  const Icon = KIND_ICON[toast.kind];
  return (
    <div
      className={`pointer-events-auto flex items-start gap-3 rounded-2xl border bg-surface-900/95 backdrop-blur-md p-3 shadow-2xl ${KIND_STYLE[toast.kind]}`}
    >
      <div className="p-2 rounded-xl bg-black/50 shrink-0">
        <Icon className="w-4 h-4" aria-hidden="true" />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-extrabold leading-tight">{toast.title}</p>
        <p className="text-xs text-zinc-300 mt-0.5 leading-snug">{toast.detail}</p>
      </div>
      <button
        type="button"
        onClick={() => onDismiss(toast.id)}
        aria-label="Cerrar aviso"
        className="p-1.5 -mr-1 -mt-1 rounded-lg text-zinc-500 active:bg-surface-800"
      >
        <X className="w-3.5 h-3.5" aria-hidden="true" />
      </button>
    </div>
  );
};

interface ToastStackProps {
  toasts: readonly ToastItem[];
  onDismiss: (id: string) => void;
}

/** Avisos de logro, subida de nivel y congelador. Se anuncian a lectores de pantalla y se cierran solos. */
export const ToastStack: React.FC<ToastStackProps> = ({ toasts, onDismiss }) => (
  <div
    role="status"
    aria-live="polite"
    className="pointer-events-none fixed inset-x-0 top-0 z-[60] px-4 pt-safe"
  >
    <div className="max-w-md mx-auto mt-14 space-y-2">
      {toasts.map((t) => (
        <ToastView key={t.id} toast={t} onDismiss={onDismiss} />
      ))}
    </div>
  </div>
);
