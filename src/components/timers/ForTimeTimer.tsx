import React, { useState, useEffect } from 'react';
import { BloqueForTime } from '../../types/workout';
import { Play, Pause, Check, Trophy } from 'lucide-react';
import { formatTime } from '../../utils/time';

interface ForTimeTimerProps {
  bloque: BloqueForTime;
  onComplete: (totalSeconds: number) => void;
  playCountdown: () => void;
  playGo: () => void;
  unlockAudio: () => void;
}

export const ForTimeTimer: React.FC<ForTimeTimerProps> = ({
  bloque,
  onComplete,
  playCountdown,
  playGo,
  unlockAudio,
}) => {
  const capSeconds = (bloque.cap_minutos || 15) * 60;
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [isRunning, setIsRunning] = useState(false);
  const [hasStarted, setHasStarted] = useState(false);
  const [checkedItems, setCheckedItems] = useState<Record<number, boolean>>({});

  useEffect(() => {
    let interval: ReturnType<typeof setInterval>;

    if (isRunning) {
      interval = setInterval(() => {
        setElapsedSeconds((prev) => {
          const next = prev + 1;
          // Check time cap warning
          if (next === capSeconds - 3 || next === capSeconds - 2 || next === capSeconds - 1) {
            playCountdown();
          }
          if (next >= capSeconds) {
            setIsRunning(false);
            playGo();
            onComplete(capSeconds);
            return capSeconds;
          }
          return next;
        });
      }, 1000);
    }

    return () => clearInterval(interval);
  }, [isRunning, capSeconds, playCountdown, playGo, onComplete]);

  const handleToggle = () => {
    unlockAudio();
    if (!hasStarted) {
      setHasStarted(true);
      playGo();
    }
    setIsRunning(!isRunning);
  };

  const handleToggleCheck = (index: number) => {
    setCheckedItems((prev) => ({
      ...prev,
      [index]: !prev[index],
    }));
  };

  const handleFinish = () => {
    setIsRunning(false);
    playGo();
    onComplete(elapsedSeconds);
  };

  const completedCount = Object.values(checkedItems).filter(Boolean).length;
  const totalCount = bloque.ejercicios.length;

  return (
    <div className="flex flex-col justify-between min-h-[calc(100vh-140px)] select-none">
      {/* Top Status */}
      <div className="space-y-2">
        <div className="flex items-center justify-between text-xs font-bold uppercase tracking-wider text-zinc-400">
          <span className="flex items-center gap-1.5 text-cyan-400">
            <span className="w-2 h-2 rounded-full bg-cyan-400 animate-pulse" />
            FOR TIME (Cap {bloque.cap_minutos} Min)
          </span>
          <span className="bg-surface-800 text-cyan-300 font-bold px-3 py-1 rounded-full border border-cyan-500/30">
            {completedCount}/{totalCount} Ejercicios
          </span>
        </div>

        {/* Progress Bar towards Cap */}
        <div className="w-full bg-surface-900 rounded-full h-1.5 overflow-hidden">
          <div
            className="bg-cyan-400 h-full transition-all duration-300"
            style={{ width: `${Math.min(100, (elapsedSeconds / capSeconds) * 100)}%` }}
          />
        </div>
      </div>

      {/* Main Stopwatch */}
      <div className="my-auto py-2 space-y-4 text-center">
        <div>
          <div className="text-[82px] sm:text-[100px] font-extrabold font-timer tracking-tighter leading-none text-white">
            {formatTime(elapsedSeconds)}
          </div>
          <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest block mt-1">
            Tiempo Transcurrido (Cap {formatTime(capSeconds)})
          </span>
        </div>

        {/* Exercises Checklist */}
        <div className="text-left space-y-2 max-h-56 overflow-y-auto pr-1">
          <span className="text-[11px] font-bold text-zinc-400 uppercase tracking-wider block px-1">
            Toca el ejercicio cuando lo completes:
          </span>
          {bloque.ejercicios.map((ej, idx) => {
            const isChecked = !!checkedItems[idx];
            return (
              <button
                key={idx}
                onClick={() => handleToggleCheck(idx)}
                className={`w-full p-3 rounded-xl border text-left flex items-center gap-3 transition-all ${
                  isChecked
                    ? 'bg-cyan-950/30 border-cyan-500/40 text-cyan-200'
                    : 'bg-black/60 border-zinc-800 text-zinc-200 active:bg-surface-800'
                }`}
              >
                <div
                  className={`w-6 h-6 rounded-lg flex items-center justify-center shrink-0 border ${
                    isChecked
                      ? 'bg-cyan-400 text-black border-cyan-300 font-bold'
                      : 'border-zinc-700 text-zinc-400'
                  }`}
                >
                  {isChecked ? <Check className="w-4 h-4 stroke-[3]" /> : idx + 1}
                </div>
                <span className={`text-xs font-semibold leading-snug flex-1 ${isChecked ? 'line-through text-zinc-500' : ''}`}>
                  {ej.detalle}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Bottom Controls */}
      <div className="space-y-3 pt-2">
        <div className="grid grid-cols-2 gap-2">
          <button
            onClick={handleToggle}
            className={`py-4 rounded-2xl font-black text-base flex items-center justify-center gap-2 shadow-xl active:scale-[0.98] transition-all ${
              isRunning
                ? 'bg-amber-500 text-black shadow-amber-500/20'
                : 'bg-surface-800 border border-zinc-700 text-white'
            }`}
          >
            {isRunning ? <Pause className="w-5 h-5 fill-black" /> : <Play className="w-5 h-5 fill-white" />}
            <span>{isRunning ? 'PAUSAR' : hasStarted ? 'REANUDAR' : 'INICIAR'}</span>
          </button>

          {/* Finish Button */}
          <button
            onClick={handleFinish}
            disabled={!hasStarted}
            className="py-4 rounded-2xl font-black text-base flex items-center justify-center gap-2 bg-gradient-to-r from-cardio-primary to-emerald-400 text-black shadow-lg shadow-emerald-500/25 active:scale-[0.98] disabled:opacity-40 transition-all"
          >
            <Trophy className="w-5 h-5" />
            <span>¡TERMINÉ!</span>
          </button>
        </div>
      </div>
    </div>
  );
};
