import React, { useState } from 'react';
import type { HeatmapDay } from '../../gamification/analytics';
import { Palmtree, Flame } from 'lucide-react';

interface HeatmapCalendarProps {
  days: HeatmapDay[];
  monthName: string;
}

const INTENSITY_COLORS: Record<number, string> = {
  0: 'bg-zinc-900 border-zinc-800 text-zinc-600',
  1: 'bg-emerald-950/60 border-emerald-800/40 text-emerald-400',
  2: 'bg-emerald-800/80 border-emerald-600/50 text-emerald-200',
  3: 'bg-emerald-600 border-emerald-500 text-emerald-100 font-bold',
  4: 'bg-cardio-primary border-emerald-300 text-black font-extrabold',
};

const WEEKDAY_HEADERS = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

export const HeatmapCalendar: React.FC<HeatmapCalendarProps> = ({ days, monthName }) => {
  const [selectedDay, setSelectedDay] = useState<HeatmapDay | null>(null);

  return (
    <div
      role="region"
      aria-label={`Calendario de constancia de ${monthName}`}
      className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-3 shadow-lg"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="p-1.5 rounded-lg bg-orange-500/20 text-orange-400">
            <Flame className="w-4 h-4" />
          </div>
          <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
            Constancia ({monthName})
          </h3>
        </div>
        <div className="flex items-center gap-1.5 text-[10px] text-zinc-500">
          <span>Menos</span>
          <div className="flex gap-0.5">
            <div className="w-2.5 h-2.5 rounded-sm bg-zinc-900 border border-zinc-800" />
            <div className="w-2.5 h-2.5 rounded-sm bg-emerald-950/80 border border-emerald-800/50" />
            <div className="w-2.5 h-2.5 rounded-sm bg-emerald-700 border border-emerald-600" />
            <div className="w-2.5 h-2.5 rounded-sm bg-cardio-primary border border-emerald-300" />
          </div>
          <span>Más</span>
        </div>
      </div>

      <div className="grid grid-cols-7 gap-1 text-center">
        {WEEKDAY_HEADERS.map((h, i) => (
          <div key={i} className="text-[10px] font-bold text-zinc-500 py-0.5">
            {h}
          </div>
        ))}

        {days.map((d) => {
          const colorClass = d.isVacation
            ? 'bg-purple-950/50 border-purple-500/40 text-purple-300'
            : INTENSITY_COLORS[d.intensity];

          const isSelected = selectedDay?.date === d.date;

          return (
            <button
              key={d.date}
              type="button"
              onClick={() => setSelectedDay(isSelected ? null : d)}
              aria-label={`${d.date}: ${d.minutes} minutos${d.isVacation ? ', de vacaciones' : ''}`}
              className={`aspect-square rounded-lg border text-[11px] flex flex-col items-center justify-center relative transition-all ${colorClass} ${
                d.isCurrentMonth ? 'opacity-100' : 'opacity-25'
              } ${d.isToday ? 'ring-2 ring-cyan-400 ring-offset-1 ring-offset-black' : ''} ${
                isSelected ? 'scale-105 z-10 ring-2 ring-white' : 'active:scale-95'
              }`}
            >
              <span>{d.dayOfMonth}</span>
              {d.isVacation && (
                <Palmtree className="w-2.5 h-2.5 text-purple-400 absolute bottom-0.5 right-0.5" />
              )}
            </button>
          );
        })}
      </div>

      {selectedDay && (
        <div
          role="status"
          className="p-2.5 rounded-xl bg-black/60 border border-zinc-800 text-xs text-zinc-300 flex items-center justify-between animate-fadeIn"
        >
          <div>
            <span className="font-bold text-white block">{selectedDay.date}</span>
            <span className="text-zinc-400">
              {selectedDay.isVacation
                ? 'Modo vacaciones activo'
                : selectedDay.minutes > 0
                ? `${selectedDay.minutes} min activos (${selectedDay.activitiesCount} ${
                    selectedDay.activitiesCount === 1 ? 'actividad' : 'actividades'
                  })`
                : 'Sin actividades'}
            </span>
          </div>
          <button
            type="button"
            onClick={() => setSelectedDay(null)}
            className="text-[11px] text-zinc-500 hover:text-zinc-300 px-2 py-1"
          >
            Cerrar
          </button>
        </div>
      )}
    </div>
  );
};
