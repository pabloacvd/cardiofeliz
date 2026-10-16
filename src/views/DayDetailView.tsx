import React from 'react';
import { DiaEntrenamiento, Bloque } from '../types/workout';
import { WarmupCard } from '../components/WarmupCard';
import { BlockCard } from '../components/BlockCard';
import { ArrowLeft, MapPin, Play } from 'lucide-react';

interface DayDetailViewProps {
  dia: DiaEntrenamiento;
  onBack: () => void;
  onStartBlock: (bloque: Bloque, blockIndex: number) => void;
  completedBlocks?: Record<string, boolean>;
}

export const DayDetailView: React.FC<DayDetailViewProps> = ({
  dia,
  onBack,
  onStartBlock,
  completedBlocks = {},
}) => {
  return (
    <div className="space-y-4 animate-fadeIn pb-6">
      {/* Top Navigation */}
      <button
        onClick={onBack}
        className="inline-flex items-center gap-1.5 text-xs font-bold text-zinc-400 hover:text-white active:scale-95 transition-all p-1 -ml-1"
      >
        <ArrowLeft className="w-4 h-4" />
        <span>Volver a Días</span>
      </button>

      {/* Day Header */}
      <div className="rounded-2xl border border-zinc-800 bg-surface-900 p-4">
        <div className="flex items-center gap-2 mb-2 flex-wrap">
          <span className="text-[11px] font-extrabold uppercase tracking-wider px-2.5 py-0.5 rounded-full bg-cardio-primary/15 text-cardio-primary border border-cardio-primary/30">
            {dia.id.replace('_', ' ').toUpperCase()}
          </span>
          <span className="inline-flex items-center gap-1 text-[11px] font-medium text-zinc-400 bg-black/60 px-2 py-0.5 rounded-full border border-zinc-800">
            <MapPin className="w-3 h-3 text-zinc-400" />
            {dia.ubicacion}
          </span>
        </div>

        <h2 className="text-xl font-extrabold text-white leading-tight">
          {dia.nombre}
        </h2>
      </div>

      {/* Warmup Section */}
      <WarmupCard calentamiento={dia.calentamiento} />

      {/* Blocks Section */}
      <div className="space-y-1">
        <div className="flex items-center justify-between px-1 mb-2">
          <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-400">
            Bloques del Entrenamiento ({dia.bloques.length})
          </h3>
          <span className="text-[11px] text-zinc-500">Toca para expandir</span>
        </div>

        {dia.bloques.map((bloque, idx) => {
          const blockKey = `${dia.id}_bloque_${idx}`;
          return (
            <BlockCard
              key={idx}
              bloque={bloque}
              index={idx}
              isCompleted={!!completedBlocks[blockKey]}
              onStart={() => onStartBlock(bloque, idx)}
            />
          );
        })}
      </div>

      {/* Start full routine shortcut */}
      {dia.bloques.length > 0 && (
        <div className="pt-2">
          <button
            onClick={() => onStartBlock(dia.bloques[0], 0)}
            className="w-full py-4 px-5 rounded-2xl bg-gradient-to-r from-cardio-primary to-emerald-400 text-black font-extrabold text-base flex items-center justify-center gap-2.5 shadow-xl shadow-emerald-500/25 active:scale-[0.98] transition-transform"
          >
            <Play className="w-5 h-5 fill-black" />
            <span>Iniciar Rutina (Bloque A)</span>
          </button>
        </div>
      )}
    </div>
  );
};
