import React, { useState, useEffect } from 'react';
import { BloqueAMRAP } from '../../types/workout';
import { Play, Pause, Plus, Minus, Check, Trophy } from 'lucide-react';
import { formatTime } from '../../utils/time';

interface AmrapTimerProps {
  bloque: BloqueAMRAP;
  onComplete: (totalSeconds: number, rounds: number) => void;
  playCountdown: () => void;
  playGo: () => void;
  unlockAudio: () => void;
}

export const AmrapTimer: React.FC<AmrapTimerProps> = ({
  bloque,
  onComplete,
  playCountdown,
  playGo,
  unlockAudio,
}) => {
  const totalDurationSeconds = (bloque.duracion_minutos || 15) * 60;
  const [secondsRemaining, setSecondsRemaining] = useState(totalDurationSeconds);
  const [isRunning, setIsRunning] = useState(false);
  const [hasStarted, setHasStarted] = useState(false);
  const [roundsCompleted, setRoundsCompleted] = useState(0);
  const [checkedExercises, setCheckedExercises] = useState<Record<number, boolean>>({});

  useEffect(() => {
    let interval: ReturnType<typeof setInterval>;

    if (isRunning && secondsRemaining > 0) {
      interval = setInterval(() => {
        setSecondsRemaining((prev) => {
          if (prev <= 4 && prev > 1) {
            playCountdown();
          }

          if (prev <= 1) {
            setIsRunning(false);
            playGo();
            onComplete(totalDurationSeconds, roundsCompleted);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    }

    return () => clearInterval(interval);
  }, [isRunning, secondsRemaining, totalDurationSeconds, roundsCompleted, playCountdown, playGo, onComplete]);

  const handleToggle = () => {
    unlockAudio();
    if (!hasStarted) {
      setHasStarted(true);
      playGo();
    }
    setIsRunning(!isRunning);
  };

  const handleToggleExercise = (index: number) => {
    setCheckedExercises((prev) => {
      const next = { ...prev, [index]: !prev[index] };
      // Check if all exercises are checked
      const allChecked = bloque.ejercicios.every((_, idx) => (idx === index ? next[idx] : next[idx]));
      if (allChecked) {
        // Auto increment round and reset checkboxes
        setRoundsCompleted((r) => r + 1);
        playGo();
        return {};
      }
      return next;
    });
  };

  const handleAddRound = () => {
    unlockAudio();
    playGo();
    setRoundsCompleted((r) => r + 1);
    setCheckedExercises({});
  };

  const handleSubRound = () => {
    if (roundsCompleted > 0) {
      setRoundsCompleted((r) => r - 1);
    }
  };

  const handleFinishEarly = () => {
    const elapsed = totalDurationSeconds - secondsRemaining;
    onComplete(elapsed, roundsCompleted);
  };

  const isLowTime = secondsRemaining <= 60 && secondsRemaining > 0;

  return (
    <div className="flex flex-col justify-between min-h-[calc(100vh-140px)] select-none">
      {/* Top Status */}
      <div className="space-y-2">
        <div className="flex items-center justify-between text-xs font-bold uppercase tracking-wider text-zinc-400">
          <span className="flex items-center gap-1.5 text-amber-400">
            <span className="w-2 h-2 rounded-full bg-amber-400 animate-pulse" />
            AMRAP ({bloque.duracion_minutos} Min)
          </span>
          <span className="bg-surface-800 text-amber-300 font-bold px-3 py-1 rounded-full border border-amber-500/30">
            {roundsCompleted} Rondas Listas
          </span>
        </div>

        {/* Progress Bar */}
        <div className="w-full bg-surface-900 rounded-full h-1.5 overflow-hidden">
          <div
            className={`h-full transition-all duration-300 ${isLowTime ? 'bg-red-500' : 'bg-amber-400'}`}
            style={{ width: `${((totalDurationSeconds - secondsRemaining) / totalDurationSeconds) * 100}%` }}
          />
        </div>
      </div>

      {/* Main Timer Display & Round Counter */}
      <div className="my-auto py-2 space-y-4 text-center">
        {/* Giant Timer */}
        <div>
          <div
            className={`text-[82px] sm:text-[100px] font-extrabold font-timer tracking-tighter leading-none ${
              isLowTime ? 'text-red-400 animate-pulse' : 'text-white'
            }`}
          >
            {formatTime(secondsRemaining)}
          </div>
          <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest block mt-1">
            Tiempo Restante
          </span>
        </div>

        {/* Round Counter Bar */}
        <div className="bg-surface-900/90 border border-zinc-800 rounded-2xl p-3 flex items-center justify-between">
          <button
            onClick={handleSubRound}
            disabled={roundsCompleted === 0}
            aria-label="Restar ronda"
            className="p-3 rounded-xl bg-surface-800 text-zinc-400 disabled:opacity-40 active:bg-surface-700"
          >
            <Minus className="w-5 h-5" />
          </button>

          <div className="flex items-center gap-2">
            <Trophy className="w-5 h-5 text-amber-400" />
            <div>
              <span className="text-[10px] text-zinc-400 uppercase font-bold block">Conteo de Rondas</span>
              <span className="text-2xl font-black text-amber-300 font-timer leading-none">
                {roundsCompleted} <span className="text-sm font-sans font-semibold text-zinc-400">Completadas</span>
              </span>
            </div>
          </div>

          <button
            onClick={handleAddRound}
            className="px-4 py-3 rounded-xl bg-amber-500 text-black font-extrabold text-xs flex items-center gap-1 active:scale-95 shadow-md shadow-amber-500/20"
          >
            <Plus className="w-4 h-4 stroke-[3]" />
            <span>+1 Ronda</span>
          </button>
        </div>

        {/* Exercises Checklist */}
        <div className="text-left space-y-2 max-h-48 overflow-y-auto pr-1">
          <span className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider block px-1">
            Circuito AMRAP (Toca para marcar):
          </span>
          {bloque.ejercicios.map((ej, idx) => {
            const isChecked = !!checkedExercises[idx];
            return (
              <button
                key={idx}
                onClick={() => handleToggleExercise(idx)}
                className={`w-full p-3 rounded-xl border text-left flex items-center gap-3 transition-all ${
                  isChecked
                    ? 'bg-emerald-950/30 border-emerald-500/40 text-emerald-200'
                    : 'bg-black/60 border-zinc-800 text-zinc-200 active:bg-surface-800'
                }`}
              >
                <div
                  className={`w-6 h-6 rounded-lg flex items-center justify-center shrink-0 border ${
                    isChecked
                      ? 'bg-emerald-500 text-black border-emerald-400'
                      : 'border-zinc-700 text-zinc-500'
                  }`}
                >
                  {isChecked ? <Check className="w-4 h-4 stroke-[3]" /> : idx + 1}
                </div>
                <span className={`text-xs font-semibold leading-snug flex-1 ${isChecked ? 'line-through text-zinc-400' : ''}`}>
                  {ej.detalle}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Bottom Controls */}
      <div className="space-y-3 pt-2">
        <button
          onClick={handleToggle}
          className={`w-full py-4 rounded-2xl font-black text-lg flex items-center justify-center gap-2 shadow-xl active:scale-[0.98] transition-all ${
            isRunning
              ? 'bg-amber-500 hover:bg-amber-400 text-black shadow-amber-500/20'
              : 'bg-cardio-primary hover:bg-emerald-400 text-black shadow-emerald-500/25'
          }`}
        >
          {isRunning ? (
            <>
              <Pause className="w-6 h-6 fill-black" />
              <span>PAUSAR</span>
            </>
          ) : (
            <>
              <Play className="w-6 h-6 fill-black" />
              <span>{hasStarted ? 'CONTINUAR' : 'INICIAR AMRAP'}</span>
            </>
          )}
        </button>

        <div className="flex items-center justify-between px-2 text-xs text-zinc-500">
          <span>Tiempo transcurrido: {formatTime(totalDurationSeconds - secondsRemaining)}</span>
          <button
            onClick={handleFinishEarly}
            className="text-zinc-400 hover:text-white font-semibold underline underline-offset-4"
          >
            Terminar Bloque
          </button>
        </div>
      </div>
    </div>
  );
};
