import React from 'react';
import { CheckCircle2, Circle, Sparkles, Zap } from 'lucide-react';
import type { DailyMissions } from '../gamification/missions';

interface DailyMissionsCardProps {
  missions: DailyMissions;
}

export const DailyMissionsCard: React.FC<DailyMissionsCardProps> = ({ missions }) => {
  if (missions.hidden || missions.missions.length === 0) return null;

  return (
    <div
      role="region"
      aria-label="Misiones diarias"
      className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-3 shadow-lg"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="p-1.5 rounded-lg bg-amber-500/20 text-amber-400">
            <Sparkles className="w-4 h-4" />
          </div>
          <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
            Misiones de hoy
          </h3>
        </div>
        {missions.xpEarned > 0 && (
          <span className="inline-flex items-center gap-1 text-[11px] font-extrabold text-amber-400 px-2 py-0.5 rounded-full bg-amber-500/10 border border-amber-500/20">
            <Zap className="w-3 h-3" />
            +{missions.xpEarned} XP sumados
          </span>
        )}
      </div>

      <div className="space-y-2">
        {missions.missions.map((m) => (
          <div
            key={m.id}
            className={`flex items-center justify-between p-2.5 rounded-xl border transition-all ${
              m.done
                ? 'bg-emerald-950/20 border-emerald-500/30 text-zinc-100'
                : 'bg-black/40 border-zinc-800/80 text-zinc-300'
            }`}
          >
            <div className="flex items-center gap-2.5 min-w-0 pr-2">
              {m.done ? (
                <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" aria-hidden="true" />
              ) : (
                <Circle className="w-4 h-4 text-zinc-600 shrink-0" aria-hidden="true" />
              )}
              <span className={`text-xs font-semibold leading-snug ${m.done ? 'line-through text-zinc-400' : ''}`}>
                {m.title}
              </span>
            </div>
            <span
              className={`shrink-0 text-[11px] font-bold px-2 py-0.5 rounded-md ${
                m.done
                  ? 'bg-emerald-500/20 text-emerald-300'
                  : 'bg-zinc-800 text-zinc-400'
              }`}
            >
              +{m.xp} XP
            </span>
          </div>
        ))}
      </div>

      {missions.allDone && (
        <div className="p-2.5 rounded-xl bg-gradient-to-r from-amber-500/15 to-emerald-500/15 border border-amber-500/30 text-center">
          <p className="text-xs font-extrabold text-amber-300 flex items-center justify-center gap-1.5">
            <Sparkles className="w-3.5 h-3.5 text-amber-400" />
            ¡Todas las misiones completadas! (+20 XP bonus)
          </p>
        </div>
      )}
    </div>
  );
};
