import React from 'react';
import { DiaEntrenamiento } from '../types/workout';
import { ChevronRight, Flame, Dumbbell, Sparkles, MapPin } from 'lucide-react';

interface DayCardProps {
  dia: DiaEntrenamiento;
  index: number;
  onClick: () => void;
  /** 'today' = terminado hoy; 'week' = terminado antes en la semana actual. */
  completion?: 'today' | 'week';
}

const DAY_ICONS = [
  <Flame className="w-5 h-5 text-cardio-primary" key="1" />,
  <Dumbbell className="w-5 h-5 text-cyan-400" key="2" />,
  <Sparkles className="w-5 h-5 text-purple-400" key="3" />,
];

const DAY_COLORS = [
  {
    border: 'border-cardio-primary/30 active:border-cardio-primary',
    bg: 'bg-gradient-to-br from-surface-900 to-black',
    glow: 'from-cardio-primary/10 via-transparent to-transparent',
    accent: 'text-cardio-primary',
    tag: 'bg-cardio-primary/15 text-cardio-primary border-cardio-primary/30',
  },
  {
    border: 'border-cyan-500/30 active:border-cyan-400',
    bg: 'bg-gradient-to-br from-surface-900 to-black',
    glow: 'from-cyan-500/10 via-transparent to-transparent',
    accent: 'text-cyan-400',
    tag: 'bg-cyan-500/15 text-cyan-400 border-cyan-500/30',
  },
  {
    border: 'border-purple-500/30 active:border-purple-400',
    bg: 'bg-gradient-to-br from-surface-900 to-black',
    glow: 'from-purple-500/10 via-transparent to-transparent',
    accent: 'text-purple-400',
    tag: 'bg-purple-500/15 text-purple-400 border-purple-500/30',
  },
];

export const DayCard: React.FC<DayCardProps> = ({ dia, index, onClick, completion }) => {
  const theme = DAY_COLORS[index % DAY_COLORS.length];
  const icon = DAY_ICONS[index % DAY_ICONS.length];

  return (
    <button
      onClick={onClick}
      className={`w-full text-left relative overflow-hidden rounded-2xl border ${theme.border} ${theme.bg} p-5 transition-all duration-150 active:scale-[0.98] shadow-lg`}
    >
      <div className={`absolute inset-0 bg-gradient-to-r ${theme.glow} pointer-events-none`} />

      <div className="relative z-10 flex items-start justify-between gap-3">
        <div className="flex-1">
          {/* Top meta tags */}
          <div className="flex items-center gap-2 mb-2 flex-wrap">
            <span className={`inline-flex items-center gap-1 text-[11px] font-bold uppercase tracking-wider px-2.5 py-0.5 rounded-full border ${theme.tag}`}>
              {icon}
              {dia.id.replace('_', ' ').toUpperCase()}
            </span>
            <span className="inline-flex items-center gap-1 text-[11px] font-medium text-zinc-400 bg-surface-800/80 px-2 py-0.5 rounded-full">
              <MapPin className="w-3 h-3 text-zinc-500" />
              {dia.ubicacion}
            </span>
            {completion && (
              <span className="text-[10px] font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/40 px-2 py-0.5 rounded-full">
                {completion === 'today' ? 'COMPLETADO HOY' : 'COMPLETADO ESTA SEMANA'}
              </span>
            )}
          </div>

          {/* Title */}
          <h2 className="text-xl font-extrabold text-white tracking-tight mb-2 leading-tight">
            {dia.nombre}
          </h2>

          {/* Blocks summary pills */}
          <div className="flex items-center gap-1.5 flex-wrap mt-3">
            {dia.bloques.map((b, bIdx) => (
              <span
                key={bIdx}
                className="text-[11px] font-medium bg-surface-800 text-zinc-300 border border-zinc-700/60 px-2 py-0.5 rounded-md"
              >
                {b.tipo}
              </span>
            ))}
            <span className="text-[11px] text-zinc-500 font-medium">
              • {dia.bloques.length} bloques
            </span>
          </div>
        </div>

        {/* Right Arrow Action */}
        <div className={`mt-2 p-2 rounded-xl bg-surface-800/90 border border-surface-700 text-zinc-300 flex items-center justify-center shrink-0`}>
          <ChevronRight className="w-5 h-5 text-white" />
        </div>
      </div>
    </button>
  );
};
