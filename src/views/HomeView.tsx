import React from 'react';
import { RutinaData, DiaEntrenamiento } from '../types/workout';
import { DayCard } from '../components/DayCard';
import { QuickLogCard } from '../components/QuickLogCard';
import { CoachCard, GameStatus } from '../components/GameStatus';
import { DailyMissionsCard } from '../components/DailyMissionsCard';
import { WeeklyChallengeCard } from '../components/WeeklyChallengeCard';
import type { GameSummary } from '../gamification';
import { Target, HeartHandshake } from 'lucide-react';

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

      {/* Objective Hero Card */}
      <div className="rounded-2xl border border-zinc-800 bg-gradient-to-b from-surface-900 via-surface-900 to-black p-4 shadow-lg">
        <div className="flex items-center gap-2 mb-2">
          <div className="p-1.5 rounded-lg bg-cardio-primary/20 text-cardio-primary">
            <Target className="w-4 h-4" />
          </div>
          <span className="text-[11px] font-bold text-cardio-primary uppercase tracking-wider">
            Plan Personalizado
          </span>
        </div>

        <h2 className="text-lg font-extrabold text-white leading-tight">
          ¡Hola {rutina.usuario}! Lista para entrenar
        </h2>
        <p className="text-xs text-zinc-400 mt-1 leading-relaxed">
          {rutina.objetivo}
        </p>

        <div className="grid grid-cols-3 gap-2 mt-4 pt-3 border-t border-zinc-800/80 text-center">
          <div className="p-2 rounded-xl bg-black/50 border border-zinc-800">
            <span className="text-[10px] text-zinc-500 uppercase block font-semibold">Enfoque</span>
            <span className="text-xs font-bold text-emerald-400">Cardio + HIIT</span>
          </div>
          <div className="p-2 rounded-xl bg-black/50 border border-zinc-800">
            <span className="text-[10px] text-zinc-500 uppercase block font-semibold">Articulación</span>
            <span className="text-xs font-bold text-cyan-400">Bajo Impacto</span>
          </div>
          <div className="p-2 rounded-xl bg-black/50 border border-zinc-800">
            <span className="text-[10px] text-zinc-500 uppercase block font-semibold">Efecto</span>
            <span className="text-xs font-bold text-purple-400">0 Hipertrofia</span>
          </div>
        </div>
      </div>

      {/* Main 3 Day Buttons */}
      <div className="space-y-3">
        <div className="flex items-center justify-between px-1">
          <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-400">
            Selecciona tu entrenamiento de hoy:
          </h3>
          <span className="text-[11px] text-zinc-500">3 días disponibles</span>
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

      {/* Quick Tips Footer */}
      <div className="rounded-xl border border-zinc-800/80 bg-black p-3 flex items-center gap-3">
        <div className="p-2 rounded-lg bg-surface-800 text-zinc-400 shrink-0">
          <HeartHandshake className="w-4 h-4 text-emerald-400" />
        </div>
        <p className="text-[11px] text-zinc-400 leading-snug">
          Tip: La pantalla de tu iPhone se mantendrá encendida durante todo el temporizador automáticamente.
        </p>
      </div>
    </div>
  );
};
