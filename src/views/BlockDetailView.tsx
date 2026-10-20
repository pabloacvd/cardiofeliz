import React from 'react';
import { Bloque, EjercicioEMOM, TipoBloque } from '../types/workout';
import { ArrowLeft, Clock, Play } from 'lucide-react';
import {
  buildFinisherPhases,
  finisherTotalSeconds,
  getFinisherRounds,
  getTabataConfig,
  getTriserieConfig,
} from '../utils/timerConfig';

interface BlockDetailViewProps {
  bloque: Bloque;
  diaNombre: string;
  onBack: () => void;
  onStart: () => void;
  isCompleted?: boolean;
}

const getBadgeStyle = (tipo: TipoBloque) => {
  switch (tipo) {
    case 'EMOM': return 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30';
    case 'AMRAP': return 'bg-amber-500/15 text-amber-400 border-amber-500/30';
    case 'FOR_TIME': return 'bg-cyan-500/15 text-cyan-400 border-cyan-500/30';
    case 'TABATA': return 'bg-red-500/15 text-red-400 border-red-500/30';
    case 'TRISERIE': return 'bg-purple-500/15 text-purple-400 border-purple-500/30';
    case 'DENSITY': return 'bg-indigo-500/15 text-indigo-400 border-indigo-500/30';
    case 'FINISHER': return 'bg-orange-500/15 text-orange-400 border-orange-500/30';
    case 'HIIT_INTERVALS': return 'bg-rose-500/15 text-rose-400 border-rose-500/30';
    default: return 'bg-zinc-800 text-zinc-300 border-zinc-700';
  }
};

const getBlockMeta = (bloque: Bloque): string => {
  if (bloque.tipo === 'EMOM') return `${bloque.duracion_minutos} min`;
  if (bloque.tipo === 'AMRAP') return `${bloque.duracion_minutos} min`;
  if (bloque.tipo === 'FOR_TIME') return `Cap ${bloque.cap_minutos} min`;
  if (bloque.tipo === 'TABATA') {
    if (bloque.estructura) return bloque.estructura;
    const { rounds, workSeconds, restSeconds } = getTabataConfig(bloque);
    return `${workSeconds}s / ${restSeconds}s × ${rounds}`;
  }
  if (bloque.tipo === 'TRISERIE' || bloque.tipo === 'DENSITY') {
    const { rounds, restSeconds } = getTriserieConfig(bloque);
    return restSeconds > 0 ? `${rounds} Rondas · Descanso ${restSeconds}s` : `${rounds} Rondas`;
  }
  if (bloque.tipo === 'FINISHER') {
    const rounds = getFinisherRounds(bloque);
    return `${rounds} ${rounds === 1 ? 'Ronda' : 'Rondas'}`;
  }
  if (bloque.tipo === 'HIIT_INTERVALS') {
    const rounds = getFinisherRounds(bloque);
    const total = finisherTotalSeconds(buildFinisherPhases(bloque));
    const roundsLabel = `${rounds} ${rounds === 1 ? 'Ronda' : 'Rondas'}`;
    return total !== null ? `${Math.round((total / 60) * 10) / 10} min · ${roundsLabel}` : roundsLabel;
  }
  return '';
};

const getStartLabel = (tipo: TipoBloque, isCompleted: boolean): string => {
  if (isCompleted) return 'Repetir Bloque';
  switch (tipo) {
    case 'EMOM': return 'Iniciar EMOM';
    case 'AMRAP': return 'Iniciar AMRAP';
    case 'FOR_TIME': return 'Iniciar For Time';
    case 'TABATA': return 'Iniciar Tabata';
    case 'TRISERIE': return 'Iniciar Triserie';
    case 'DENSITY': return 'Iniciar Density';
    case 'FINISHER': return 'Iniciar Finisher';
    case 'HIIT_INTERVALS': return 'Iniciar HIIT';
    default: return 'Iniciar Bloque';
  }
};

export const BlockDetailView: React.FC<BlockDetailViewProps> = ({
  bloque,
  diaNombre,
  onBack,
  onStart,
  isCompleted = false,
}) => {
  const meta = getBlockMeta(bloque);

  return (
    <div className="flex flex-col min-h-screen bg-black text-white px-4 pt-safe pb-safe animate-fadeIn">
      {/* Top Bar */}
      <div className="flex items-center justify-between pb-3 border-b border-surface-800">
        <button
          onClick={onBack}
          className="flex items-center gap-1 text-xs font-bold text-zinc-400 hover:text-white bg-surface-900 border border-zinc-800 px-3 py-1.5 rounded-xl active:bg-surface-800"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Volver</span>
        </button>

        <div className="text-center flex-1 px-2 overflow-hidden">
          <span className="text-[10px] uppercase font-bold text-zinc-500 block truncate">
            {diaNombre}
          </span>
          <h1 className="text-xs sm:text-sm font-extrabold text-zinc-200 truncate">
            {bloque.nombre}
          </h1>
        </div>

        <div className="w-16" />
      </div>

      {/* Body */}
      <div className="flex-1 py-5 flex flex-col gap-4">
        {/* Block metadata */}
        <div className="flex items-center gap-2 flex-wrap">
          <span
            className={`text-[10px] font-extrabold uppercase tracking-wider px-2.5 py-0.5 rounded-full border ${getBadgeStyle(bloque.tipo)}`}
          >
            {bloque.tipo}
          </span>
          {meta && (
            <span className="inline-flex items-center gap-1 text-[11px] font-medium text-zinc-400 bg-black/50 px-2 py-0.5 rounded-md border border-zinc-800">
              <Clock className="w-3 h-3 text-zinc-500" />
              {meta}
            </span>
          )}
          {isCompleted && (
            <span className="inline-flex items-center gap-1 text-[10px] font-bold text-emerald-400 bg-emerald-500/20 px-2 py-0.5 rounded-full border border-emerald-500/40">
              COMPLETADO
            </span>
          )}
        </div>

        {/* Exercises list */}
        <div>
          <p className="text-[11px] font-bold uppercase tracking-wider text-zinc-500 mb-2">
            Ejercicios
          </p>
          <div className="space-y-2">
            {bloque.ejercicios.map((ej, idx) => {
              const isEmom = 'minuto' in ej;
              const emomEj = ej as EjercicioEMOM;

              return (
                <div
                  key={idx}
                  className="flex items-center gap-3 bg-surface-900 p-3 rounded-xl border border-zinc-800/80"
                >
                  <div className="w-7 h-7 rounded-lg bg-surface-800 border border-zinc-700/80 flex items-center justify-center shrink-0 text-[11px] font-mono font-bold text-zinc-300">
                    {isEmom ? `M${emomEj.minuto}` : idx + 1}
                  </div>
                  <span className="text-sm text-zinc-200 font-medium flex-1 leading-snug">
                    {ej.detalle}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* CTA */}
      <div className="pb-6">
        <button
          onClick={onStart}
          className="w-full py-4 px-5 rounded-2xl bg-gradient-to-r from-cardio-primary to-emerald-400 text-black font-extrabold text-base flex items-center justify-center gap-2.5 shadow-xl shadow-emerald-500/25 active:scale-[0.98] transition-transform"
        >
          <Play className="w-5 h-5 fill-black" />
          <span>{getStartLabel(bloque.tipo, isCompleted)}</span>
        </button>
      </div>
    </div>
  );
};
