import React, { useEffect, useId, useRef } from 'react';
import { X } from 'lucide-react';

interface BottomSheetProps {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
}

/** Hoja inferior modal: se cierra con Escape, tocando el fondo o con el botón de cierre. */
export const BottomSheet: React.FC<BottomSheetProps> = ({ title, onClose, children }) => {
  const titleId = useId();
  const panelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const previouslyFocused = document.activeElement as HTMLElement | null;
    panelRef.current?.focus();
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('keydown', onKeyDown);
      previouslyFocused?.focus?.();
    };
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/80 backdrop-blur-sm animate-fadeIn">
      <button type="button" aria-label="Cerrar" className="absolute inset-0 cursor-default" onClick={onClose} tabIndex={-1} />
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        tabIndex={-1}
        className="relative w-full max-w-md max-h-[90vh] overflow-y-auto rounded-t-3xl border border-b-0 border-zinc-800 bg-surface-900 p-5 pb-safe shadow-2xl outline-none"
      >
        <div className="flex items-center justify-between mb-4">
          <h2 id={titleId} className="text-base font-extrabold text-white">
            {title}
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Cerrar"
            className="p-2 -mr-2 rounded-xl text-zinc-400 active:bg-surface-800"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
};
