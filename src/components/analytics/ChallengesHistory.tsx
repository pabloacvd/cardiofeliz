import React from 'react';
import { Trophy, CheckCircle2, PauseCircle, Clock } from 'lucide-react';
import type { WeeklyChallenge } from '../../gamification/challenges';

interface ChallengesHistoryProps {
  currentChallenge: WeeklyChallenge;
  history: WeeklyChallenge[];
}

export const ChallengesHistory: React.FC<ChallengesHistoryProps> = ({
  currentChallenge,
  history,
}) => {
  const completedCount = history.filter((h) => h.done).length;

  return (
    <div
      role="region"
      aria-label="Desafíos semanales"
      className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-4 shadow-lg"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="p-1.5 rounded-lg bg-cyan-500/20 text-cyan-400">
            <Trophy className="w-4 h-4" />
          </div>
          <div>
            <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
              Desafíos Semanales
            </h3>
            <span className="text-[11px] text-zinc-500">
              {completedCount} completado{completedCount === 1 ? '' : 's'} en total
            </span>
          </div>
        </div>
      </div>

      {/* Historial */}
      <div className="space-y-2 max-h-64 overflow-y-auto pr-1">
        {history.length === 0 ? (
          <p className="text-xs text-zinc-500 text-center py-3">No hay historial de desafíos aún.</p>
        ) : (
          history
            .slice()
            .reverse()
            .map((c) => {
              const isCurrent = c.weekStart === currentChallenge.weekStart;

              return (
                <div
                  key={c.weekStart}
                  className={`p-3 rounded-xl border transition-all ${
                    c.done
                      ? 'bg-emerald-950/20 border-emerald-500/30 text-white'
                      : c.paused
                      ? 'bg-purple-950/20 border-purple-500/30 text-zinc-400'
                      : isCurrent
                      ? 'bg-cyan-950/20 border-cyan-500/30 text-zinc-200'
                      : 'bg-black/40 border-zinc-800/80 text-zinc-400'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2 min-w-0 pr-2">
                      {c.done ? (
                        <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
                      ) : c.paused ? (
                        <PauseCircle className="w-4 h-4 text-purple-400 shrink-0" />
                      ) : (
                        <Clock className="w-4 h-4 text-cyan-400 shrink-0" />
                      )}
                      <div className="min-w-0">
                        <span className="text-xs font-bold block truncate">{c.title}</span>
                        <span className="text-[10px] text-zinc-500">
                          Semana {c.weekStart} {isCurrent ? '(Actual)' : ''}
                        </span>
                      </div>
                    </div>

                    <span
                      className={`text-xs font-extrabold px-2 py-0.5 rounded-md shrink-0 ${
                        c.done
                          ? 'bg-emerald-500/20 text-emerald-300'
                          : c.paused
                          ? 'bg-purple-500/20 text-purple-300'
                          : 'bg-zinc-800 text-zinc-300'
                      }`}
                    >
                      {c.progress} / {c.target} {c.unit}
                    </span>
                  </div>
                </div>
              );
            })
        )}
      </div>
    </div>
  );
};
