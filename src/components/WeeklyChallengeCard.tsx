import React from 'react';
import { CheckCircle2, PauseCircle, Trophy, Zap } from 'lucide-react';
import type { WeeklyChallenge } from '../gamification/challenges';

interface WeeklyChallengeCardProps {
  challenge: WeeklyChallenge;
}

export const WeeklyChallengeCard: React.FC<WeeklyChallengeCardProps> = ({ challenge }) => {
  if (challenge.hidden) return null;

  return (
    <div
      role="region"
      aria-label="Desafío de la semana"
      className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-3 shadow-lg"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="p-1.5 rounded-lg bg-cyan-500/20 text-cyan-400">
            <Trophy className="w-4 h-4" />
          </div>
          <span className="text-[11px] font-bold text-cyan-400 uppercase tracking-wider">
            Desafío de la semana
          </span>
        </div>
        <span className="inline-flex items-center gap-1 text-[11px] font-extrabold text-cyan-400 px-2 py-0.5 rounded-full bg-cyan-500/10 border border-cyan-500/20">
          <Zap className="w-3 h-3" />
          +{challenge.xp} XP
        </span>
      </div>

      <div>
        <h4 className="text-sm font-extrabold text-white leading-tight">{challenge.title}</h4>
        <p className="text-xs text-zinc-400 mt-0.5 leading-relaxed">{challenge.description}</p>
      </div>

      {challenge.paused ? (
        <div className="flex items-center gap-2 p-2.5 rounded-xl bg-purple-950/20 border border-purple-500/30 text-purple-300 text-xs">
          <PauseCircle className="w-4 h-4 shrink-0" />
          <span>Pausado por modo vacaciones (no cuenta en contra).</span>
        </div>
      ) : challenge.done ? (
        <div className="flex items-center justify-between p-2.5 rounded-xl bg-emerald-950/30 border border-emerald-500/30 text-emerald-300 text-xs font-bold">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
            <span>¡Desafío completado!</span>
          </div>
          <span>
            {challenge.progress}/{challenge.target} {challenge.unit}
          </span>
        </div>
      ) : (
        <div className="space-y-1.5">
          <div className="flex justify-between text-xs font-semibold">
            <span className="text-zinc-400">Progreso</span>
            <span className="text-white">
              {challenge.progress} / {challenge.target} {challenge.unit}
            </span>
          </div>
          <div
            role="progressbar"
            aria-label="Progreso del desafío"
            aria-valuemin={0}
            aria-valuemax={challenge.target}
            aria-valuenow={challenge.progress}
            className="h-2 rounded-full bg-surface-700 overflow-hidden"
          >
            <div
              className="h-full rounded-full bg-gradient-to-r from-cyan-400 to-emerald-400 transition-all"
              style={{ width: `${Math.round(challenge.ratio * 100)}%` }}
            />
          </div>
        </div>
      )}
    </div>
  );
};
