import React from 'react';
import { Target, User, Calendar } from 'lucide-react';

interface RoutineMetaEditorProps {
  usuario: string;
  edad: number;
  objetivo: string;
  onUpdateEdad: (edad: number) => void;
  onUpdateObjetivo: (objetivo: string) => void;
}

export const RoutineMetaEditor: React.FC<RoutineMetaEditorProps> = ({
  usuario,
  edad,
  objetivo,
  onUpdateEdad,
  onUpdateObjetivo,
}) => {
  return (
    <div className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-4">
      <div className="flex items-center gap-2">
        <div className="p-1.5 rounded-lg bg-cardio-primary/20 text-cardio-primary">
          <Target className="w-4 h-4" />
        </div>
        <span className="text-[11px] font-bold text-cardio-primary uppercase tracking-wider">
          Configuración General
        </span>
      </div>

      {/* Usuario (Lectura) */}
      <div>
        <label className="block text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-1.5 flex items-center gap-1.5">
          <User className="w-3.5 h-3.5 text-zinc-500" />
          Usuario (Cuenta)
        </label>
        <div className="w-full rounded-xl bg-black/60 border border-zinc-800/80 px-3.5 py-2.5 text-base text-zinc-400 select-none">
          {usuario}
        </div>
        <span className="text-[10px] text-zinc-500 mt-1 block">
          El nombre se obtiene de tu sesión y no es editable.
        </span>
      </div>

      {/* Edad */}
      <div>
        <label
          htmlFor="meta-edad"
          className="block text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-1.5 flex items-center gap-1.5"
        >
          <Calendar className="w-3.5 h-3.5 text-zinc-500" />
          Edad (Años)
        </label>
        <input
          id="meta-edad"
          type="number"
          inputMode="numeric"
          min={1}
          max={120}
          value={isNaN(edad) ? '' : edad}
          onChange={(e) => {
            const val = parseInt(e.target.value, 10);
            onUpdateEdad(isNaN(val) ? 0 : val);
          }}
          className="w-full rounded-xl bg-black border border-zinc-700 px-3.5 py-2.5 text-base text-white focus:outline-none focus:border-cardio-primary"
        />
      </div>

      {/* Objetivo */}
      <div>
        <label
          htmlFor="meta-objetivo"
          className="block text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-1.5"
        >
          Objetivo de Entrenamiento
        </label>
        <textarea
          id="meta-objetivo"
          maxLength={300}
          rows={3}
          value={objetivo}
          onChange={(e) => onUpdateObjetivo(e.target.value)}
          placeholder="Ej: Quema de grasa, definición y acondicionamiento general..."
          className="w-full rounded-xl bg-black border border-zinc-700 px-3.5 py-2.5 text-base text-white focus:outline-none focus:border-cardio-primary resize-none"
        />
        <div className="flex justify-end">
          <span className="text-[10px] text-zinc-500">{objetivo.length}/300</span>
        </div>
      </div>
    </div>
  );
};
