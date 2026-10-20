import React from 'react';
import { RutinaData, DiaEntrenamiento } from '../types/workout';
import { DayCard } from '../components/DayCard';
import { QuickLogCard } from '../components/QuickLogCard';
import { CoachCard, GameStatus } from '../components/GameStatus';
import { DailyMissionsCard } from '../components/DailyMissionsCard';
import { WeeklyChallengeCard } from '../components/WeeklyChallengeCard';
import type { GameSummary } from '../gamification';
import { Dumbbell } from 'lucide-react';

interface HomeViewProps {
  rutina: RutinaData;
  onSelectDay: (dia: DiaEntrenamiento) => void;
  completedDays?: Record<string, 'today' | 'week'>;
  onDirectStart?: (dia: DiaEntrenamiento) => void;
  quickLog: React.ComponentProps<typeof QuickLogCard>;
  game: GameSummary;
  showCoach: boolean;
  onDismissCoach: () => void;
  onOpenVacations?: () => void;
  onOpenRoutineSettings?: () => void;
}

export const HomeView: React.FC<HomeViewProps> = ({
  rutina,
  onSelectDay,
  completedDays = {},
  quickLog,
  game,
  showCoach,
  onDismissCoach,
  onOpenVacations,
  onOpenRoutineSettings,
}) => {
  return (
    <div className="space-y-5 animate-fadeIn">
      {showCoach && (
        <CoachCard
          coach={game.coach}
          mascotStage={game.mascot.stage}
          mascotName={game.mascot.name}
          onDismiss={onDismissCoach}
        />
      )}

      <GameStatus game={game} onOpenVacations={onOpenVacations} />

      {/* Misiones diarias & Desafío semanal */}
      <DailyMissionsCard missions={game.missions} />
      <WeeklyChallengeCard challenge={game.challenge} />

      {/* Main 3 Day Buttons */}
      <div className="space-y-3">
        <div className="flex items-center justify-between px-1">
          <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-400">
            Selecciona tu entrenamiento de hoy:
          </h3>
          <span className="text-[11px] text-zinc-500">
            {rutina.dias_entrenamiento.length}{' '}
            {rutina.dias_entrenamiento.length === 1 ? 'día disponible' : 'días disponibles'}
          </span>
        </div>

        <div className="space-y-3.5">
          {rutina.dias_entrenamiento.map((dia, idx) => (
            <DayCard
              key={dia.id}
              dia={dia}
              index={idx}
              onClick={() => onSelectDay(dia)}
              completion={completedDays[dia.id]}
            />
          ))}
        </div>
      </div>

      {/* Registro rápido de corrida / descanso activo */}
      <QuickLogCard {...quickLog} />

      {/* Botón Mi rutina */}
      {onOpenRoutineSettings && (
        <div className="pt-1">
          <button
            type="button"
            onClick={onOpenRoutineSettings}
            className="w-full py-3.5 px-4 rounded-2xl bg-surface-900 border border-zinc-800 hover:border-zinc-700 active:scale-[0.98] text-zinc-200 font-bold text-sm flex items-center justify-center gap-2.5 transition-all shadow-md"
          >
            <Dumbbell className="w-4 h-4 text-cardio-primary" />
            <span>Mi rutina (Personalizar)</span>
          </button>
        </div>
      )}
    </div>
  );
};
