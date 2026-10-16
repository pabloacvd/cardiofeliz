import React, { useState, useEffect } from 'react';
import { BloqueEMOM, EjercicioEMOM } from '../../types/workout';
import { Play, Pause, SkipForward, ChevronRight } from 'lucide-react';
import { formatSecondsOnly, formatTime } from '../../utils/time';

interface EmomTimerProps {
  bloque: BloqueEMOM;
  onComplete: (totalSeconds: number) => void;
  playCountdown: () => void;
  playGo: () => void;
  unlockAudio: () => void;
}

export const EmomTimer: React.FC<EmomTimerProps> = ({
  bloque,
  onComplete,
  playCountdown,
  playGo,
  unlockAudio,
}) => {
  const totalMinutes = bloque.duracion_minutos;
  const [currentMinute, setCurrentMinute] = useState(1); // 1 to totalMinutes
  const [secondsInMinute, setSecondsInMinute] = useState(60); // 60 down to 0
  const [isRunning, setIsRunning] = useState(false);
  const [hasStarted, setHasStarted] = useState(false);
  const [totalElapsed, setTotalElapsed] = useState(0);

  const numExercises = bloque.ejercicios.length;

  // Exercise for the current minute
  const currentExerciseIndex = (currentMinute - 1) % numExercises;
  const currentExercise: EjercicioEMOM = bloque.ejercicios[currentExerciseIndex] || {
    minuto: currentMinute,
    detalle: 'Ejercicio activo',
  };

  // Next exercise preview
  const nextMinute = currentMinute < totalMinutes ? currentMinute + 1 : null;
  const nextExerciseIndex = nextMinute ? (nextMinute - 1) % numExercises : null;
  const nextExercise: EjercicioEMOM | null =
    nextExerciseIndex !== null ? bloque.ejercicios[nextExerciseIndex] : null;

  const currentRound = Math.floor((currentMinute - 1) / numExercises) + 1;
  const totalRounds = Math.ceil(totalMinutes / numExercises);

  useEffect(() => {
    let interval: ReturnType<typeof setInterval>;

    if (isRunning) {
      interval = setInterval(() => {
        setTotalElapsed((prev) => prev + 1);

        setSecondsInMinute((prevSec) => {
          if (prevSec <= 4 && prevSec > 1) {
            playCountdown();
          }

          if (prevSec <= 1) {
            // Minute completed
            if (currentMinute >= totalMinutes) {
              // Workout finished
              setIsRunning(false);
              playGo();
              onComplete(totalMinutes * 60);
              return 0;
            } else {
              // Advance to next minute
              playGo();
              setCurrentMinute((m) => m + 1);
              return 60;
            }
          }
          return prevSec - 1;
        });
      }, 1000);
    }

    return () => clearInterval(interval);
  }, [isRunning, currentMinute, totalMinutes, playCountdown, playGo, onComplete]);

  const handleToggle = () => {
    unlockAudio();
    if (!hasStarted) {
      setHasStarted(true);
      playGo();
    }
    setIsRunning(!isRunning);
  };

  const handleNextMinute = () => {
    unlockAudio();
    if (currentMinute < totalMinutes) {
      playGo();
      setCurrentMinute((m) => m + 1);
      setSecondsInMinute(60);
    } else {
      onComplete(totalElapsed);
    }
  };

  const handleFinishEarly = () => {
    onComplete(totalElapsed);
  };

  const isRest = currentExercise.detalle.toLowerCase().includes('descanso');

  return (
    <div className="flex flex-col justify-between min-h-[calc(100vh-140px)] select-none">
      {/* Top Status Bar */}
      <div className="space-y-2">
        <div className="flex items-center justify-between text-xs font-bold uppercase tracking-wider text-zinc-400">
          <span className="flex items-center gap-1.5 text-cardio-primary">
            <span className="w-2 h-2 rounded-full bg-cardio-primary animate-ping" />
            EMOM ({totalMinutes} Min)
          </span>
          <span className="bg-surface-800 text-zinc-300 px-2.5 py-1 rounded-full border border-zinc-700">
            Ronda {currentRound}/{totalRounds} • Min {currentMinute}/{totalMinutes}
          </span>
        </div>

        {/* Global Progress Bar */}
        <div className="w-full bg-surface-900 rounded-full h-1.5 overflow-hidden">
          <div
            className="bg-cardio-primary h-full transition-all duration-300"
            style={{ width: `${((currentMinute - 1 + (60 - secondsInMinute) / 60) / totalMinutes) * 100}%` }}
          />
        </div>
      </div>

      {/* Center Giant Timer Display */}
      <div className="my-auto text-center py-4">
        {/* Giant Countdown Clock */}
        <div className="relative inline-flex flex-col items-center justify-center">
          <div className="text-[88px] sm:text-[110px] font-extrabold font-timer tracking-tighter leading-none text-white drop-shadow-2xl">
            00:{formatSecondsOnly(secondsInMinute === 60 ? 60 : secondsInMinute)}
          </div>
          <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest mt-1">
            Segundos Restantes del Minuto
          </span>
        </div>

        {/* Current Active Exercise Card */}
        <div
          className={`mt-6 p-5 rounded-2xl border text-left transition-all ${
            isRest
              ? 'bg-amber-950/20 border-amber-500/40 text-amber-300'
              : 'bg-gradient-to-b from-surface-900 to-black border-cardio-primary/40 text-white shadow-xl shadow-emerald-500/10'
          }`}
        >
          <div className="flex items-center justify-between gap-2 mb-1.5">
            <span
              className={`text-[11px] font-extrabold uppercase tracking-wider px-2 py-0.5 rounded-full ${
                isRest ? 'bg-amber-500/20 text-amber-400' : 'bg-cardio-primary/20 text-cardio-primary'
              }`}
            >
              {isRest ? 'Descanso Activo' : `Minuto ${currentMinute} - En Curso`}
            </span>
            <span className="text-xs font-mono font-semibold text-zinc-400">
              M{(currentMinute - 1) % numExercises + 1} de {numExercises}
            </span>
          </div>

          <h2 className="text-xl sm:text-2xl font-black leading-tight text-white mt-1">
            {currentExercise.detalle}
          </h2>
        </div>

        {/* Next Minute Preview */}
        {nextExercise && (
          <div className="mt-3 p-3 rounded-xl bg-black border border-zinc-800/80 text-left flex items-center justify-between text-xs text-zinc-400">
            <div className="flex items-center gap-2 overflow-hidden">
              <span className="text-[10px] uppercase font-bold text-zinc-500 bg-surface-800 px-1.5 py-0.5 rounded">
                Siguiente
              </span>
              <span className="truncate text-zinc-300 font-medium">
                {nextExercise.detalle}
              </span>
            </div>
            <ChevronRight className="w-4 h-4 text-zinc-600 shrink-0 ml-1" />
          </div>
        )}
      </div>

      {/* Bottom Controls */}
      <div className="space-y-3 pt-2">
        <div className="grid grid-cols-4 gap-2">
          {/* Play/Pause Button (Spans 3 cols) */}
          <button
            onClick={handleToggle}
            className={`col-span-3 py-4 rounded-2xl font-black text-lg flex items-center justify-center gap-2 shadow-xl active:scale-[0.98] transition-all ${
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
                <span>{hasStarted ? 'CONTINUAR' : 'COMENZAR EMOM'}</span>
              </>
            )}
          </button>

          {/* Skip Minute Button */}
          <button
            onClick={handleNextMinute}
            aria-label="Saltar al siguiente minuto"
            className="py-4 rounded-2xl bg-surface-800 border border-zinc-700 text-zinc-200 active:bg-surface-700 flex flex-col items-center justify-center gap-0.5"
          >
            <SkipForward className="w-5 h-5 text-white" />
            <span className="text-[9px] font-bold text-zinc-400 uppercase">+1 Min</span>
          </button>
        </div>

        {/* Finish early */}
        <div className="flex items-center justify-between px-2 text-xs text-zinc-500">
          <span>Tiempo total: {formatTime(totalElapsed)}</span>
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
