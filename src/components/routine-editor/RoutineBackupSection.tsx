import React from 'react';
import { Download, Upload, RotateCcw } from 'lucide-react';

export const RoutineBackupSection: React.FC = () => {
  return (
    <div className="rounded-2xl border border-zinc-800/80 bg-surface-900/60 p-4 space-y-3">
      <div className="flex items-center justify-between">
        <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-400">
          Copia de seguridad y restauración
        </h3>
        <span className="text-[10px] font-semibold text-zinc-500 bg-surface-800 px-2 py-0.5 rounded-full border border-zinc-700/50">
          Próximamente
        </span>
      </div>

      <p className="text-xs text-zinc-400 leading-relaxed">
        Podrás exportar tu rutina a un archivo JSON para tener un respaldo, importar rutinas compartidas o restaurar la rutina por defecto original.
      </p>

      <div className="grid grid-cols-3 gap-2 pt-1">
        <button
          type="button"
          disabled
          aria-label="Exportar rutina (Próximamente)"
          className="p-2.5 rounded-xl bg-surface-800/50 border border-zinc-800 text-zinc-500 font-semibold text-xs flex flex-col items-center justify-center gap-1 opacity-60 cursor-not-allowed"
        >
          <Download className="w-4 h-4" />
          <span>Exportar</span>
        </button>

        <button
          type="button"
          disabled
          aria-label="Importar rutina (Próximamente)"
          className="p-2.5 rounded-xl bg-surface-800/50 border border-zinc-800 text-zinc-500 font-semibold text-xs flex flex-col items-center justify-center gap-1 opacity-60 cursor-not-allowed"
        >
          <Upload className="w-4 h-4" />
          <span>Importar</span>
        </button>

        <button
          type="button"
          disabled
          aria-label="Restaurar rutina original (Próximamente)"
          className="p-2.5 rounded-xl bg-surface-800/50 border border-zinc-800 text-zinc-500 font-semibold text-xs flex flex-col items-center justify-center gap-1 opacity-60 cursor-not-allowed"
        >
          <RotateCcw className="w-4 h-4" />
          <span>Restaurar</span>
        </button>
      </div>
    </div>
  );
};
