import React, { useState, useEffect } from 'react';
import { BloqueTriserie } from '../../types/workout';
import { ChevronRight, Check, Coffee } from 'lucide-react';
import { formatSecondsOnly, formatTime } from '../../utils/time';

interface TriserieTimerProps {
  bloque: BloqueTriserie;
  onComplete: (totalSeconds: number) => void;
  playCountdown: () => void;
  playGo: () => void;
  playRest: () => void;
  unlockAudio: () => void;
}

export const TriserieTimer: React.FC<TriserieTimerProps> = ({
  bloque,
  onComplete,
  playCountdown,
  playGo,
  playRest,
  unlockAudio,
}) => {
  const totalRounds = 4;
  const restDuration = 45; // 45 seconds default

  const [currentRound, setCurrentRound] = useState(1);
  const [currentExerciseIdx, setCurrentExerciseIdx] = useState(0);
  const [isResting, setIsResting] = useState(false);
  const [restSecondsLeft, setRestSecondsLeft] = useState(restDuration);
  const [totalElapsed, setTotalElapsed] = useState(0);
  const [hasStarted, setHasStarted] = useState(false);

  // Global elapsed timer
  useEffect(() => {
    let interval: ReturnType<typeof setInterval>;
    if (hasStarted) {
      interval = setInterval(() => {
        setTotalElapsed((prev) => prev + 1);
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [hasStarted]);

  // Rest countdown timer
  useEffect(() => {
    let interval: ReturnType<typeof setInterval>;

    if (isResting && restSecondsLeft > 0) {
      interval = setInterval(() => {
        setRestSecondsLeft((prev) => {
          if (prev <= 4 && prev > 1) {
            playCountdown();
          }

          if (prev <= 1) {
            setIsResting(false);
            playGo();
            if (currentRound < totalRounds) {
              setCurrentRound((r) => r + 1);
              setCurrentExerciseIdx(0);
            } else {
              onComplete(totalElapsed);
            }
            return restDuration;
          }
          return prev - 1;
        });
      }, 1000);
    }

    return () => clearInterval(interval);
  }, [isResting, restSecondsLeft, currentRound, totalRounds, totalElapsed, restDuration, playCountdown, playGo, onComplete]);

  const handleNextExercise = () => {
    unlockAudio();
    if (!hasStarted) {
      setHasStarted(true);
    }

    if (currentExerciseIdx < bloque.ejercicios.length - 1) {
      // Advance to next exercise in current round
      playGo();
      setCurrentExerciseIdx((prev) => prev + 1);
    } else {
      // Completed all exercises in this round
      if (currentRound < totalRounds) {
        // Trigger Rest
        setIsResting(true);
        setRestSecondsLeft(restDuration);
        playRest();
      } else {
        // Workout complete!
        playGo();
        onComplete(totalElapsed);
      }
    }
  };

  const handleSkipRest = () => {
    setIsResting(false);
    playGo();
    if (currentRound < totalRounds) {
      setCurrentRound((r) => r + 1);
      setCurrentExerciseIdx(0);
    } else {
      onComplete(totalElapsed);
    }
  };

  return (
    <div className="flex flex-col justify-between min-h-[calc(100vh-140px)] select-none">
      {/* Top Status */}
      <div className="space-y-2">
        <div className="flex items-center justify-between text-xs font-bold uppercase tracking-wider text-zinc-400">
          <span className="flex items-center gap-1.5 text-purple-400">
            <span className="w-2 h-2 rounded-full bg-purple-400 animate-pulse" />
            TRISERIE METABÓLICA
          </span>
          <span className="bg-surface-800 text-purple-300 font-bold px-3 py-1 rounded-full border border-purple-500/30">
            Ronda {currentRound} de {totalRounds}
          </span>
        </div>

        {/* Round Progress Bar */}
        <div className="w-full bg-surface-900 rounded-full h-1.5 overflow-hidden">
          <div
            className="bg-purple-500 h-full transition-all duration-300"
            style={{ width: `${(((currentRound - 1) * bloque.ejercicios.length + currentExerciseIdx) / (totalRounds * bloque.ejercicios.length)) * 100}%` }}
          />
        </div>
      </div>

      {/* Main Content Area */}
      <div className="my-auto py-2 space-y-4">
        {isResting ? (
          /* Rest Mode Screen */
          <div className="text-center py-6 space-y-4 bg-gradient-to-b from-amber-950/20 to-black p-6 rounded-3xl border border-amber-500/40">
            <div className="inline-flex items-center gap-2 bg-amber-500/20 border border-amber-500/40 text-amber-300 px-4 py-1 rounded-full text-xs font-bold uppercase tracking-widest">
              <Coffee className="w-4 h-4" />
              Descanso entre Rondas
            </div>

            <div className="text-[100px] font-black font-timer text-amber-400 leading-none">
              {formatSecondsOnly(restSecondsLeft)}
            </div>

            <p className="text-xs text-zinc-400">
              Prepárate para la Ronda {currentRound + 1} de {totalRounds}
            </p>

            <button
              onClick={handleSkipRest}
              className="mt-2 px-5 py-2.5 rounded-xl bg-surface-800 border border-zinc-700 text-zinc-300 text-xs font-bold active:bg-surface-700"
            >
              Saltar Descanso
            </button>
          </div>
        ) : (
          /* Active Exercise Flow */
          <div className="space-y-3">
            <div className="text-center mb-1">
              <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest">
                Ejercicio {currentExerciseIdx + 1} de {bloque.ejercicios.length}
              </span>
            </div>

            {/* Exercise Cards List */}
            {bloque.ejercicios.map((ej, idx) => {
              const isCurrent = idx === currentExerciseIdx;
              const isPast = idx < currentExerciseIdx;

              return (
                <div
                  key={idx}
                  className={`p-4 rounded-2xl border transition-all ${
                    isCurrent
                      ? 'bg-gradient-to-b from-surface-900 to-black border-purple-500 shadow-lg shadow-purple-500/20 ring-1 ring-purple-500/50'
                      : isPast
                      ? 'bg-black/40 border-zinc-800/80 opacity-50'
                      : 'bg-black/60 border-zinc-800/60 opacity-70'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div
                      className={`w-8 h-8 rounded-xl flex items-center justify-center shrink-0 font-bold text-sm ${
                        isCurrent
                          ? 'bg-purple-500 text-white'
                          : isPast
                          ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/40'
                          : 'bg-surface-800 text-zinc-500'
                      }`}
                    >
                      {isPast ? <Check className="w-4 h-4 stroke-[3]" /> : idx + 1}
                    </div>

                    <div className="flex-1">
                      <span className={`text-base font-extrabold leading-snug block ${isCurrent ? 'text-white' : 'text-zinc-300'}`}>
                        {ej.detalle}
                      </span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Bottom Controls */}
      <div className="space-y-3 pt-2">
        {!isResting && (
          <button
            onClick={handleNextExercise}
            className="w-full py-4 rounded-2xl font-black text-lg flex items-center justify-center gap-2 bg-gradient-to-r from-purple-500 to-indigo-500 text-white shadow-xl shadow-purple-500/25 active:scale-[0.98] transition-all"
          >
            <span>
              {currentExerciseIdx === bloque.ejercicios.length - 1
                ? currentRound === totalRounds
                  ? '¡FINALIZAR TRISERIE!'
                  : 'DESCANSO ENTRE RONDAS (45s)'
                : 'SIGUIENTE EJERCICIO'}
            </span>
            <ChevronRight className="w-5 h-5" />
          </button>
        )}

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
