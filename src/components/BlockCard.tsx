import React, { useState } from 'react';
import { Bloque, EjercicioEMOM } from '../types/workout';
import { ChevronDown, ChevronUp, Play, Clock, CheckCircle2 } from 'lucide-react';

interface BlockCardProps {
  bloque: Bloque;
  index?: number;
  onStart: () => void;
  isCompleted?: boolean;
}

export const BlockCard: React.FC<BlockCardProps> = ({
  bloque,
  onStart,
  isCompleted = false,
}) => {
  const [isExpanded, setIsExpanded] = useState(true);

  const getBadgeStyle = (tipo: string) => {
    switch (tipo) {
      case 'EMOM':
        return 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30';
      case 'AMRAP':
        return 'bg-amber-500/15 text-amber-400 border-amber-500/30';
      case 'FOR_TIME':
        return 'bg-cyan-500/15 text-cyan-400 border-cyan-500/30';
      case 'TABATA':
        return 'bg-red-500/15 text-red-400 border-red-500/30';
      case 'TRISERIE':
        return 'bg-purple-500/15 text-purple-400 border-purple-500/30';
      case 'FINISHER':
        return 'bg-orange-500/15 text-orange-400 border-orange-500/30';
      default:
        return 'bg-zinc-800 text-zinc-300 border-zinc-700';
    }
  };

  const getBlockMeta = () => {
    if (bloque.tipo === 'EMOM') return `${bloque.duracion_minutos} min`;
    if (bloque.tipo === 'AMRAP') return `${bloque.duracion_minutos} min`;
    if (bloque.tipo === 'FOR_TIME') return `Cap ${bloque.cap_minutos} min`;
    if (bloque.tipo === 'TABATA') return bloque.estructura || '4 min';
    if (bloque.tipo === 'TRISERIE') return bloque.descanso_entre_rondas ? `Descanso: ${bloque.descanso_entre_rondas}` : '4 Rondas';
    if (bloque.tipo === 'FINISHER') return '3 Rondas';
    return '';
  };

  return (
    <div
      className={`rounded-2xl border transition-all duration-200 overflow-hidden mb-4 ${
        isCompleted
          ? 'border-emerald-500/40 bg-gradient-to-b from-surface-900 to-black'
          : 'border-zinc-800 bg-surface-900/90 shadow-md'
      }`}
    >
      {/* Header section (Click to toggle) */}
      <div
        onClick={() => setIsExpanded(!isExpanded)}
        className="p-4 flex items-start justify-between gap-3 cursor-pointer select-none active:bg-surface-800/50"
      >
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1.5 flex-wrap">
            <span
              className={`text-[10px] font-extrabold uppercase tracking-wider px-2 py-0.5 rounded-full border ${getBadgeStyle(
                bloque.tipo
              )}`}
            >
              {bloque.tipo}
            </span>

            {getBlockMeta() && (
              <span className="inline-flex items-center gap-1 text-[11px] font-medium text-zinc-400 bg-black/50 px-2 py-0.5 rounded-md border border-zinc-800">
                <Clock className="w-3 h-3 text-zinc-500" />
                {getBlockMeta()}
              </span>
            )}

            {isCompleted && (
              <span className="inline-flex items-center gap-1 text-[10px] font-bold text-emerald-400 bg-emerald-500/20 px-2 py-0.5 rounded-full border border-emerald-500/40">
                <CheckCircle2 className="w-3 h-3 text-emerald-400" />
                COMPLETADO
              </span>
            )}
          </div>

          <h3 className="text-base font-bold text-white leading-snug">
            {bloque.nombre}
          </h3>
        </div>

        <button
          type="button"
          aria-label={isExpanded ? "Colapsar bloque" : "Expandir bloque"}
          className="p-1 rounded-lg bg-surface-800 text-zinc-400 hover:text-white shrink-0 mt-1"
        >
          {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
        </button>
      </div>

      {/* Expanded Exercises Details */}
      {isExpanded && (
        <div className="px-4 pb-4 pt-1 border-t border-zinc-800/80">
          <div className="space-y-2 mb-4 mt-2">
            {bloque.ejercicios.map((ej, idx) => {
              const isEmom = 'minuto' in ej;
              const emomEj = ej as EjercicioEMOM;

              return (
                <div
                  key={idx}
                  className="flex items-center gap-3 bg-black/60 p-2.5 rounded-xl border border-zinc-800/60"
                >
                  <div className="w-6 h-6 rounded-lg bg-surface-800 border border-zinc-700/80 flex items-center justify-center shrink-0 text-[11px] font-mono font-bold text-zinc-300">
                    {isEmom ? `M${emomEj.minuto}` : idx + 1}
                  </div>
                  <span className="text-xs text-zinc-200 font-medium flex-1 leading-snug">
                    {ej.detalle}
                  </span>
                </div>
              );
            })}
          </div>

          {/* Big Action Button */}
          <button
            onClick={onStart}
            className="w-full py-3.5 px-4 rounded-xl bg-cardio-primary hover:bg-emerald-400 active:scale-[0.98] text-black font-extrabold text-sm flex items-center justify-center gap-2 shadow-lg shadow-emerald-500/20 transition-all"
          >
            <Play className="w-4 h-4 fill-black" />
            <span>{isCompleted ? 'Repetir Bloque' : 'Iniciar Temporizador de Bloque'}</span>
          </button>
        </div>
      )}
    </div>
  );
};
