import React, { useState } from 'react';
import { Award, CheckCircle2, Lock } from 'lucide-react';
import type { AchievementStatus } from '../../gamification/achievements';

interface AchievementsGalleryProps {
  achievements: AchievementStatus[];
  unlockedAtMap?: Record<string, string>;
}

export const AchievementsGallery: React.FC<AchievementsGalleryProps> = ({
  achievements,
  unlockedAtMap = {},
}) => {
  const [filter, setFilter] = useState<'all' | 'unlocked' | 'locked'>('all');

  const unlockedCount = achievements.filter((a) => a.unlocked).length;
  const totalCount = achievements.length;

  const filtered = achievements.filter((a) => {
    if (filter === 'unlocked') return a.unlocked;
    if (filter === 'locked') return !a.unlocked;
    return true;
  });

  return (
    <div
      role="region"
      aria-label="Galería de Logros"
      className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-4 shadow-lg"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="p-1.5 rounded-lg bg-amber-500/20 text-amber-400">
            <Award className="w-4 h-4" />
          </div>
          <div>
            <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
              Logros e Insignias
            </h3>
            <span className="text-[11px] text-zinc-500">
              {unlockedCount} de {totalCount} desbloqueados
            </span>
          </div>
        </div>

        {/* Filter buttons */}
        <div className="flex p-0.5 rounded-xl bg-black/60 border border-zinc-800 text-[11px] font-semibold">
          <button
            type="button"
            onClick={() => setFilter('all')}
            className={`px-2 py-1 rounded-lg transition-colors ${
              filter === 'all' ? 'bg-surface-700 text-white' : 'text-zinc-400'
            }`}
          >
            Todos
          </button>
          <button
            type="button"
            onClick={() => setFilter('unlocked')}
            className={`px-2 py-1 rounded-lg transition-colors ${
              filter === 'unlocked' ? 'bg-surface-700 text-white' : 'text-zinc-400'
            }`}
          >
            Listos
          </button>
          <button
            type="button"
            onClick={() => setFilter('locked')}
            className={`px-2 py-1 rounded-lg transition-colors ${
              filter === 'locked' ? 'bg-surface-700 text-white' : 'text-zinc-400'
            }`}
          >
            Pendientes
          </button>
        </div>
      </div>

      <div className="space-y-2 max-h-96 overflow-y-auto pr-1">
        {filtered.map((a) => {
          const unlockIso = unlockedAtMap[a.id];
          const unlockDateFormatted = unlockIso
            ? new Date(unlockIso).toLocaleDateString(undefined, { day: '2-digit', month: '2-digit', year: '2-digit' })
            : null;

          const pct = Math.min(100, Math.round((a.current / a.target) * 100));

          return (
            <div
              key={a.id}
              className={`p-3 rounded-xl border transition-all ${
                a.unlocked
                  ? 'bg-amber-950/15 border-amber-500/30 text-white'
                  : 'bg-black/40 border-zinc-800/80 text-zinc-400'
              }`}
            >
              <div className="flex items-start justify-between gap-2">
                <div className="flex items-start gap-2.5 min-w-0">
                  <div
                    className={`p-2 rounded-xl shrink-0 ${
                      a.unlocked
                        ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30'
                        : 'bg-zinc-800 text-zinc-600'
                    }`}
                  >
                    {a.unlocked ? <CheckCircle2 className="w-4 h-4" /> : <Lock className="w-4 h-4" />}
                  </div>
                  <div>
                    <h4 className={`text-xs font-bold leading-tight ${a.unlocked ? 'text-amber-300' : 'text-zinc-300'}`}>
                      {a.title}
                    </h4>
                    <p className="text-[11px] text-zinc-400 mt-0.5 leading-snug">{a.description}</p>
                    {unlockDateFormatted && (
                      <span className="text-[10px] text-amber-400/80 font-medium block mt-1">
                        Desbloqueado el {unlockDateFormatted}
                      </span>
                    )}
                  </div>
                </div>

                {!a.unlocked && (
                  <span className="text-[10px] font-bold text-zinc-500 shrink-0">
                    {a.current} / {a.target}
                  </span>
                )}
              </div>

              {!a.unlocked && (
                <div className="mt-2.5">
                  <div
                    role="progressbar"
                    aria-label={`Progreso de ${a.title}`}
                    aria-valuemin={0}
                    aria-valuemax={a.target}
                    aria-valuenow={a.current}
                    className="h-1.5 rounded-full bg-zinc-800 overflow-hidden"
                  >
                    <div
                      className="h-full rounded-full bg-zinc-500 transition-all"
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};
