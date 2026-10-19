import React, { useEffect } from 'react';
import confetti from 'canvas-confetti';
import { Trophy, Flame, Clock, ArrowRight, CheckCircle2, Zap, Award, ArrowUp } from 'lucide-react';
import { formatDurationSummary } from '../utils/time';
import { Bloque } from '../types/workout';
import type { LogOutcome } from '../gamification';
import { Mascot } from './Mascot';

interface WorkoutCompleteModalProps {
  bloque: Bloque;
  totalSeconds: number;
  rounds?: number;
  hasNextBlock: boolean;
  onNextBlock: () => void;
  onBackToDay: () => void;
  /** Presente solo cuando este bloque cerró el día de entrenamiento. */
  dayResult?: LogOutcome | null;
  mascotStage?: number;
}

export const WorkoutCompleteModal: React.FC<WorkoutCompleteModalProps> = ({
  bloque,
  totalSeconds,
  rounds,
  hasNextBlock,
  onNextBlock,
  onBackToDay,
  dayResult,
  mascotStage = 1,
}) => {
  useEffect(() => {
    if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return;
    // Launch celebratory confetti burst (más grande si se cerró el día)
    try {
      confetti({
        particleCount: dayResult ? 140 : 80,
        spread: dayResult ? 100 : 70,
        origin: { y: 0.6 },
        colors: ['#22c55e', '#06b6d4', '#f59e0b', '#ec4899'],
      });
    } catch {
      // Ignored if confetti fails
    }
  }, [dayResult]);

  return (
    <div className="fixed inset-0 z-50 bg-black/90 backdrop-blur-md flex items-center justify-center p-4 animate-fadeIn">
      <div className="bg-surface-900 border border-cardio-primary/40 rounded-3xl p-6 max-w-sm w-full text-center shadow-2xl space-y-5 relative overflow-hidden">
        {/* Glow backdrop */}
        <div className="absolute -top-16 left-1/2 -translate-x-1/2 w-48 h-48 bg-cardio-primary/20 blur-3xl pointer-events-none" />

        <div className="relative z-10">
          {dayResult ? (
            <div className="mx-auto mb-2 flex justify-center">
              <Mascot stage={mascotStage} mood="proud" size={56} />
            </div>
          ) : (
            <div className="w-16 h-16 rounded-2xl bg-cardio-primary/20 border border-cardio-primary/40 text-cardio-primary mx-auto flex items-center justify-center mb-3 shadow-lg shadow-emerald-500/20">
              <Trophy className="w-8 h-8" />
            </div>
          )}

          <span className="text-[11px] font-extrabold uppercase tracking-widest text-cardio-primary block mb-1">
            {dayResult ? '¡Día de Entrenamiento Completado!' : '¡Bloque Finalizado con Éxito!'}
          </span>
          <h2 className="text-xl font-black text-white leading-tight">
            {bloque.nombre}
          </h2>
        </div>

        {/* Stats Summary */}
        <div className="grid grid-cols-2 gap-2 text-left relative z-10">
          <div className="p-3 rounded-2xl bg-black/60 border border-zinc-800">
            <div className="flex items-center gap-1.5 text-zinc-400 text-[10px] font-bold uppercase mb-1">
              <Clock className="w-3.5 h-3.5 text-cardio-primary" />
              <span>Tiempo Total</span>
            </div>
            <span className="text-base font-extrabold text-white font-timer">
              {formatDurationSummary(totalSeconds)}
            </span>
          </div>

          <div className="p-3 rounded-2xl bg-black/60 border border-zinc-800">
            <div className="flex items-center gap-1.5 text-zinc-400 text-[10px] font-bold uppercase mb-1">
              <Flame className="w-3.5 h-3.5 text-amber-400" />
              <span>Tipo / Logro</span>
            </div>
            <span className="text-base font-extrabold text-amber-300 font-timer">
              {rounds !== undefined && rounds > 0 ? `${rounds} Rondas` : 'Completado'}
            </span>
          </div>
        </div>

        {/* Resumen del día (solo al terminar todos los bloques) */}
        {dayResult && (
          <div
            role="status"
            aria-label="Resumen del día"
            className="relative z-10 rounded-2xl border border-amber-500/30 bg-amber-950/20 p-3 space-y-2 text-left"
          >
            <p className="text-[11px] font-extrabold uppercase tracking-widest text-amber-300">¡Día completado!</p>
            <div className="flex flex-wrap gap-2 text-xs font-bold">
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-amber-500/15 text-amber-300 border border-amber-500/30">
                <Zap className="w-3 h-3" aria-hidden="true" />+{dayResult.xpGained} XP
              </span>
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-orange-500/15 text-orange-300 border border-orange-500/30">
                <Flame className="w-3 h-3" aria-hidden="true" />
                Racha: {dayResult.streakAfter} {dayResult.streakAfter === 1 ? 'día' : 'días'}
              </span>
            </div>
            <p className="text-xs text-zinc-300">
              Entrenos de la semana: {dayResult.weekWorkouts}/{dayResult.workoutsGoal}
              {dayResult.weekWorkouts >= dayResult.workoutsGoal ? ' · ¡meta cumplida!' : ''}
            </p>
            {dayResult.earnedFreeze && (
              <p className="text-xs text-cyan-300 font-semibold">Ganaste un congelador para proteger tu racha.</p>
            )}
            {dayResult.leveledUp && (
              <p className="text-xs text-purple-300 font-semibold flex items-center gap-1">
                <ArrowUp className="w-3 h-3" aria-hidden="true" />
                ¡Subiste al nivel {dayResult.levelAfter}: {dayResult.tierName}!
              </p>
            )}
            {dayResult.newAchievements.map((a) => (
              <p key={a.id} className="text-xs text-amber-300 font-semibold flex items-center gap-1">
                <Award className="w-3 h-3" aria-hidden="true" />
                Logro desbloqueado: {a.title}
              </p>
            ))}
          </div>
        )}

        {/* Actions */}
        <div className="space-y-2 pt-2 relative z-10">
          {hasNextBlock ? (
            <button
              onClick={onNextBlock}
              className="w-full py-4 rounded-2xl bg-gradient-to-r from-cardio-primary to-emerald-400 text-black font-extrabold text-sm flex items-center justify-center gap-2 shadow-xl shadow-emerald-500/25 active:scale-[0.98] transition-all"
            >
              <span>Continuar al Siguiente Bloque</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          ) : (
            <div className="p-3 bg-emerald-950/40 border border-emerald-500/40 rounded-xl text-xs text-emerald-300 font-bold flex items-center justify-center gap-2">
              <CheckCircle2 className="w-4 h-4" />
              <span>¡Has completado todos los bloques de hoy!</span>
            </div>
          )}

          <button
            onClick={onBackToDay}
            className="w-full py-3 rounded-2xl bg-surface-800 border border-zinc-700 text-zinc-300 font-bold text-xs active:bg-surface-700"
          >
            Volver a la Rutina del Día
          </button>
        </div>
      </div>
    </div>
  );
};
