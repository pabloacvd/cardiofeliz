import React, { useState, useEffect } from 'react';
import { BloqueFinisher } from '../../types/workout';
import { Play, Pause, Coffee, Sparkles } from 'lucide-react';
import { formatSecondsOnly, formatTime } from '../../utils/time';

interface FinisherTimerProps {
  bloque: BloqueFinisher;
  onComplete: (totalSeconds: number) => void;
  playCountdown: () => void;
  playGo: () => void;
  playRest: () => void;
  unlockAudio: () => void;
}

export const FinisherTimer: React.FC<FinisherTimerProps> = ({
  bloque,
  onComplete,
  playCountdown,
  playGo,
  playRest,
  unlockAudio,
}) => {
  const totalRounds = 3;
  const exercisesPerRound = bloque.ejercicios.length; // usually 3 (30s ex1, 30s ex2, 30s rest)
  const intervalDuration = 30; // 30s each

  const [currentRound, setCurrentRound] = useState(1);
  const [exerciseIndex, setExerciseIndex] = useState(0);
  const [secondsLeft, setSecondsLeft] = useState(intervalDuration);
  const [isRunning, setIsRunning] = useState(false);
  const [hasStarted, setHasStarted] = useState(false);
  const [totalElapsed, setTotalElapsed] = useState(0);

  const currentExercise = bloque.ejercicios[exerciseIndex];
  const isRest = currentExercise?.detalle.toLowerCase().includes('descanso');

  useEffect(() => {
    let interval: ReturnType<typeof setInterval>;

    if (isRunning) {
      interval = setInterval(() => {
        setTotalElapsed((prev) => prev + 1);

        setSecondsLeft((prevSec) => {
          if (prevSec <= 4 && prevSec > 1) {
            playCountdown();
          }

          if (prevSec <= 1) {
            // Next interval
            if (exerciseIndex < exercisesPerRound - 1) {
              const nextIdx = exerciseIndex + 1;
              setExerciseIndex(nextIdx);
              const nextIsRest = bloque.ejercicios[nextIdx]?.detalle.toLowerCase().includes('descanso');
              if (nextIsRest) playRest();
              else playGo();
              return intervalDuration;
            } else {
              // End of round
              if (currentRound < totalRounds) {
                setCurrentRound((r) => r + 1);
                setExerciseIndex(0);
                playGo();
                return intervalDuration;
              } else {
                // Completed all rounds
                setIsRunning(false);
                playGo();
                onComplete(totalElapsed + 1);
                return 0;
              }
            }
          }

          return prevSec - 1;
        });
      }, 1000);
    }

    return () => clearInterval(interval);
  }, [isRunning, exerciseIndex, exercisesPerRound, currentRound, totalRounds, totalElapsed, intervalDuration, bloque.ejercicios, playCountdown, playGo, playRest, onComplete]);

  const handleToggle = () => {
    unlockAudio();
    if (!hasStarted) {
      setHasStarted(true);
      if (isRest) playRest();
      else playGo();
    }
    setIsRunning(!isRunning);
  };

  const totalIntervals = totalRounds * exercisesPerRound;
  const currentIntervalNum = (currentRound - 1) * exercisesPerRound + exerciseIndex + 1;

  return (
    <div className="flex flex-col justify-between min-h-[calc(100vh-140px)] select-none">
      {/* Top Status */}
      <div className="space-y-2">
        <div className="flex items-center justify-between text-xs font-bold uppercase tracking-wider text-zinc-400">
          <span className="flex items-center gap-1.5 text-orange-400">
            <span className="w-2 h-2 rounded-full bg-orange-400 animate-pulse" />
            FINISHER CORE (3 Rondas)
          </span>
          <span className="bg-surface-800 text-orange-300 font-bold px-3 py-1 rounded-full border border-orange-500/30">
            Ronda {currentRound}/{totalRounds} • {currentIntervalNum}/{totalIntervals}
          </span>
        </div>

        {/* Global Progress Bar */}
        <div className="w-full bg-surface-900 rounded-full h-1.5 overflow-hidden">
          <div
            className="bg-orange-500 h-full transition-all duration-300"
            style={{ width: `${(((currentIntervalNum - 1) * intervalDuration + (intervalDuration - secondsLeft)) / (totalIntervals * intervalDuration)) * 100}%` }}
          />
        </div>
      </div>

      {/* Main Countdown & Exercise */}
      <div className="my-auto py-2 space-y-4 text-center">
        {/* Phase Pill */}
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full border text-xs font-extrabold uppercase tracking-widest">
          {isRest ? (
            <span className="flex items-center gap-1.5 text-amber-400 bg-amber-500/10 border-amber-500/30 px-3 py-1 rounded-full">
              <Coffee className="w-3.5 h-3.5" />
              Descanso
            </span>
          ) : (
            <span className="flex items-center gap-1.5 text-orange-400 bg-orange-500/10 border-orange-500/30 px-3 py-1 rounded-full">
              <Sparkles className="w-3.5 h-3.5" />
              Intervalo Activo 30s
            </span>
          )}
        </div>

        {/* Giant Number */}
        <div>
          <div
            className={`text-[96px] sm:text-[120px] font-black font-timer tracking-tighter leading-none ${
              isRest ? 'text-amber-400 drop-shadow-[0_0_20px_rgba(245,158,11,0.25)]' : 'text-orange-400 drop-shadow-[0_0_20px_rgba(249,115,22,0.25)]'
            }`}
          >
            00:{formatSecondsOnly(secondsLeft)}
          </div>
          <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest block mt-1">
            Segundos Restantes
          </span>
        </div>

        {/* Exercise Card */}
        <div
          className={`p-4 rounded-2xl border text-left ${
            isRest
              ? 'bg-amber-950/20 border-amber-500/40 text-amber-200'
              : 'bg-surface-900 border-orange-500/40 text-white'
          }`}
        >
          <span className="text-[10px] uppercase font-bold text-zinc-400 block mb-1">
            Ejercicio {exerciseIndex + 1} de {exercisesPerRound}
          </span>
          <h2 className="text-lg font-extrabold leading-tight">
            {currentExercise?.detalle}
          </h2>
        </div>
      </div>

      {/* Bottom Controls */}
      <div className="space-y-3 pt-2">
        <button
          onClick={handleToggle}
          className={`w-full py-4 rounded-2xl font-black text-lg flex items-center justify-center gap-2 shadow-xl active:scale-[0.98] transition-all ${
            isRunning
              ? 'bg-amber-500 text-black shadow-amber-500/20'
              : 'bg-gradient-to-r from-orange-500 to-amber-500 text-black shadow-orange-500/25'
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
              <span>{hasStarted ? 'CONTINUAR' : 'INICIAR FINISHER'}</span>
            </>
          )}
        </button>

        <div className="flex items-center justify-between px-2 text-xs text-zinc-500">
          <span>Tiempo: {formatTime(totalElapsed)}</span>
          <button
            onClick={() => onComplete(totalElapsed)}
            className="text-zinc-400 hover:text-white font-semibold underline underline-offset-4"
          >
            Terminar Bloque
          </button>
        </div>
      </div>
    </div>
  );
};
