import React from 'react';
import { Trophy, Flame, Footprints, Gauge, Repeat, CalendarCheck } from 'lucide-react';
import type { PersonalRecords } from '../../gamification/analytics';

interface PersonalRecordsCardProps {
  records: PersonalRecords;
}

export const PersonalRecordsCard: React.FC<PersonalRecordsCardProps> = ({ records }) => {
  return (
    <div
      role="region"
      aria-label="Récords personales"
      className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-3 shadow-lg"
    >
      <div className="flex items-center gap-2">
        <div className="p-1.5 rounded-lg bg-amber-500/20 text-amber-400">
          <Trophy className="w-4 h-4" />
        </div>
        <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
          Récords Personales
        </h3>
      </div>

      <div className="grid grid-cols-2 gap-2 text-left">
        {/* Mejor Racha */}
        <div className="p-3 rounded-xl bg-black/50 border border-zinc-800/80">
          <div className="flex items-center gap-1.5 text-zinc-500 text-[10px] font-bold uppercase mb-1">
            <Flame className="w-3.5 h-3.5 text-orange-400" />
            <span>Mejor Racha</span>
          </div>
          <span className="text-base font-extrabold text-white">
            {records.bestStreakDays} {records.bestStreakDays === 1 ? 'día' : 'días'}
          </span>
        </div>

        {/* Corrida más larga */}
        <div className="p-3 rounded-xl bg-black/50 border border-zinc-800/80">
          <div className="flex items-center gap-1.5 text-zinc-500 text-[10px] font-bold uppercase mb-1">
            <Footprints className="w-3.5 h-3.5 text-cyan-400" />
            <span>Corrida más larga</span>
          </div>
          <span className="text-base font-extrabold text-white">
            {records.longestRunMinutes > 0 ? `${records.longestRunMinutes} min` : '—'}
            {records.longestRunKm > 0 ? ` (${records.longestRunKm} km)` : ''}
          </span>
        </div>

        {/* Mejor Ritmo */}
        <div className="p-3 rounded-xl bg-black/50 border border-zinc-800/80">
          <div className="flex items-center gap-1.5 text-zinc-500 text-[10px] font-bold uppercase mb-1">
            <Gauge className="w-3.5 h-3.5 text-blue-400" />
            <span>Mejor Ritmo</span>
          </div>
          <span className="text-base font-extrabold text-white">
            {records.bestPaceFormatted ?? '—'}
          </span>
        </div>

        {/* Récord AMRAP */}
        <div className="p-3 rounded-xl bg-black/50 border border-zinc-800/80">
          <div className="flex items-center gap-1.5 text-zinc-500 text-[10px] font-bold uppercase mb-1">
            <Repeat className="w-3.5 h-3.5 text-emerald-400" />
            <span>Récord AMRAP</span>
          </div>
          <span className="text-base font-extrabold text-white">
            {records.maxRoundsAmrap > 0 ? `${records.maxRoundsAmrap} rondas` : '—'}
          </span>
        </div>

        {/* Semana más activa */}
        <div className="col-span-2 p-3 rounded-xl bg-black/50 border border-zinc-800/80">
          <div className="flex items-center gap-1.5 text-zinc-500 text-[10px] font-bold uppercase mb-1">
            <CalendarCheck className="w-3.5 h-3.5 text-purple-400" />
            <span>Semana más activa</span>
          </div>
          <div className="flex items-baseline justify-between">
            <span className="text-base font-extrabold text-white">
              {records.mostActiveWeekMinutes > 0 ? `${records.mostActiveWeekMinutes} min activos` : '—'}
            </span>
            {records.mostActiveWeekLabel && (
              <span className="text-xs text-zinc-400 font-semibold">Semana {records.mostActiveWeekLabel}</span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
