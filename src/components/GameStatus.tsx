import React from 'react';
import {
  Flame,
  Snowflake,
  Palmtree,
  X,
} from 'lucide-react';
import type { GameSummary } from '../gamification';
import type { CoachMood } from '../gamification/coach';
import { Mascot } from './Mascot';

const MOOD_STYLE: Record<CoachMood, string> = {
  happy: 'border-cardio-primary/30 text-emerald-300',
  proud: 'border-amber-500/40 text-amber-300',
  worried: 'border-orange-500/40 text-orange-300',
  recover: 'border-cyan-500/40 text-cyan-300',
  rest: 'border-purple-500/40 text-purple-300',
  welcome: 'border-cardio-primary/30 text-emerald-300',
};

const plural = (n: number, one: string, many: string): string => `${n} ${n === 1 ? one : many}`;

interface CoachCardProps {
  coach: GameSummary['coach'];
  mascotStage?: number;
  mascotName?: string;
  onDismiss: () => void;
}

/** Mensaje del coach al abrir la app con la mascota animada. Se puede descartar y no vuelve hasta el día siguiente. */
export const CoachCard: React.FC<CoachCardProps> = ({ coach, mascotStage = 1, mascotName, onDismiss }) => {
  return (
    <div
      role="region"
      aria-label="Mensaje del coach"
      className={`rounded-2xl border bg-surface-900 p-3.5 flex items-start gap-3 shadow-lg ${MOOD_STYLE[coach.mood]}`}
    >
      <div className="shrink-0 p-1 rounded-xl bg-black/40 border border-zinc-800/80">
        <Mascot stage={mascotStage} mood={coach.mood} size={42} showName={Boolean(mascotName)} />
      </div>
      <div className="flex-1 min-w-0 pt-0.5">
        <p className="text-sm leading-snug text-zinc-100">{coach.text}</p>
      </div>
      <button
        type="button"
        onClick={onDismiss}
        aria-label="Descartar mensaje del coach"
        className="p-1.5 -mr-1 -mt-1 rounded-lg text-zinc-500 active:bg-surface-800"
      >
        <X className="w-3.5 h-3.5" aria-hidden="true" />
      </button>
    </div>
  );
};

interface Ring {
  label: string;
  value: number;
  goal: number;
  color: string;
}

const RingGauge: React.FC<Ring> = ({ label, value, goal, color }) => {
  const pct = goal > 0 ? Math.min(100, Math.round((value / goal) * 100)) : 0;
  return (
    <div className="flex flex-col items-center gap-1.5" role="img" aria-label={`${label}: ${value} de ${goal}`}>
      <div className="relative w-16 h-16">
        <svg viewBox="0 0 36 36" className="w-full h-full -rotate-90" aria-hidden="true">
          <circle cx="18" cy="18" r="15.9155" fill="none" stroke="#2c2c2e" strokeWidth="3.5" />
          <circle
            cx="18"
            cy="18"
            r="15.9155"
            fill="none"
            stroke={color}
            strokeWidth="3.5"
            strokeLinecap="round"
            strokeDasharray={`${pct} 100`}
          />
        </svg>
        <span className="absolute inset-0 flex items-center justify-center text-sm font-extrabold text-white">
          {value}/{goal}
        </span>
      </div>
      <span className="text-[11px] font-semibold text-zinc-400">{label}</span>
    </div>
  );
};

interface GameStatusProps {
  game: GameSummary;
  onOpenVacations?: () => void;
}

/** Racha (con congeladores), nivel/XP y anillos de la semana. */
export const GameStatus: React.FC<GameStatusProps> = ({ game, onOpenVacations }) => {
  const { streak, level, week, weekly, vacation } = game;
  const xpLeft = Math.max(0, level.xpForNextLevel - level.xpIntoLevel);

  return (
    <section aria-label="Tu progreso" className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-4">
      <div className="flex flex-wrap items-center gap-2">
        <span
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-orange-500/15 border border-orange-500/30 text-orange-300 text-xs font-extrabold"
          aria-label={`Racha de ${plural(streak.current, 'día', 'días')}`}
        >
          <Flame className="w-3.5 h-3.5" aria-hidden="true" />
          {plural(streak.current, 'día', 'días')}
        </span>

        <span
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-cyan-500/15 border border-cyan-500/30 text-cyan-300 text-xs font-extrabold"
          aria-label={`Congeladores disponibles: ${streak.freezes}`}
        >
          <Snowflake className="w-3.5 h-3.5" aria-hidden="true" />
          {streak.freezes}
        </span>

        {weekly.current > 0 && (
          <span className="px-3 py-1.5 rounded-full bg-zinc-800 border border-zinc-700 text-zinc-300 text-xs font-bold">
            {plural(weekly.current, 'semana', 'semanas')} perfecta{weekly.current === 1 ? '' : 's'}
          </span>
        )}

        {vacation.active ? (
          <button
            type="button"
            onClick={onOpenVacations}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-purple-500/20 border border-purple-500/40 text-purple-300 text-xs font-bold hover:bg-purple-500/30 active:scale-95 transition-all"
            aria-label="De vacaciones - click para gestionar"
          >
            <Palmtree className="w-3.5 h-3.5 text-purple-400" />
            De vacaciones
          </button>
        ) : onOpenVacations ? (
          <button
            type="button"
            onClick={onOpenVacations}
            className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-full bg-zinc-800/80 border border-zinc-700/60 text-zinc-400 hover:text-zinc-200 text-[11px] font-semibold transition-colors"
            title="Activar o gestionar vacaciones"
          >
            <Palmtree className="w-3 h-3 text-purple-400" />
            Vacaciones
          </button>
        ) : null}

        {streak.atRisk && (
          <span className="text-[11px] font-semibold text-orange-300">
            {streak.freezes > 0 ? 'Hoy usarías un congelador' : 'Sumá algo hoy para sostenerla'}
          </span>
        )}
      </div>

      <div>
        <div className="flex items-baseline justify-between mb-1.5">
          <span className="text-sm font-extrabold text-white">
            Nivel {level.level} · <span className="text-cardio-primary">{level.tierName}</span>
          </span>
          <span className="text-[11px] text-zinc-400">{level.totalXp} XP</span>
        </div>
        <div
          role="progressbar"
          aria-label="Progreso al siguiente nivel"
          aria-valuemin={0}
          aria-valuemax={level.xpForNextLevel}
          aria-valuenow={level.xpIntoLevel}
          className="h-2.5 rounded-full bg-surface-700 overflow-hidden"
        >
          <div
            className="h-full rounded-full bg-gradient-to-r from-cardio-primary to-cyan-400"
            style={{ width: `${Math.round(level.progress * 100)}%` }}
          />
        </div>
        <p className="mt-1 text-[11px] text-zinc-500">Te faltan {xpLeft} XP para el nivel {level.level + 1}.</p>
      </div>

      <div>
        <h3 className="text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-2">Meta de la semana</h3>
        <div className="flex justify-around">
          <RingGauge label="Entrenos" value={week.workoutsCapped} goal={week.workoutsGoal} color="#22c55e" />
          <RingGauge label="Corridas" value={week.runsCapped} goal={week.runsGoal} color="#06b6d4" />
        </div>
        {week.met && (
          <p className="mt-2 text-center text-xs font-bold text-emerald-300">¡Semana perfecta cumplida!</p>
        )}
      </div>
    </section>
  );
};
