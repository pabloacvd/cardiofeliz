import React, { useState, useEffect } from 'react';
import { BloqueTabata } from '../../types/workout';
import { Play, Pause, Zap, Coffee } from 'lucide-react';
import { formatSecondsOnly } from '../../utils/time';

interface TabataTimerProps {
  bloque: BloqueTabata;
  onComplete: (totalSeconds: number) => void;
  playCountdown: () => void;
  playGo: () => void;
  playRest: () => void;
  unlockAudio: () => void;
}

type TabataPhase = 'WORK' | 'REST';

export const TabataTimer: React.FC<TabataTimerProps> = ({
  bloque,
  onComplete,
  playCountdown,
  playGo,
  playRest,
  unlockAudio,
}) => {
  const totalRounds = 8;
  const workSeconds = 20;
  const restSeconds = 10;

  const [currentRound, setCurrentRound] = useState(1);
  const [phase, setPhase] = useState<TabataPhase>('WORK');
  const [secondsLeft, setSecondsLeft] = useState(workSeconds);
  const [isRunning, setIsRunning] = useState(false);
  const [hasStarted, setHasStarted] = useState(false);
  const [totalElapsed, setTotalElapsed] = useState(0);

  useEffect(() => {
    let interval: ReturnType<typeof setInterval>;

    if (isRunning) {
      interval = setInterval(() => {
        setTotalElapsed((prev) => prev + 1);

        setSecondsLeft((prevSec) => {
          // Warning beeps on last 3 seconds
          if (prevSec <= 4 && prevSec > 1) {
            playCountdown();
          }

          if (prevSec <= 1) {
            // Phase transition
            if (phase === 'WORK') {
              if (currentRound >= totalRounds) {
                // Final work round done
                setIsRunning(false);
                playGo();
                onComplete(totalElapsed + 1);
                return 0;
              } else {
                // Switch to Rest
                setPhase('REST');
                playRest();
                return restSeconds;
              }
            } else {
              // Switch from Rest to Work next round
              setPhase('WORK');
              setCurrentRound((r) => r + 1);
              playGo();
              return workSeconds;
            }
          }

          return prevSec - 1;
        });
      }, 1000);
    }

    return () => clearInterval(interval);
  }, [isRunning, phase, currentRound, totalRounds, totalElapsed, playCountdown, playGo, playRest, onComplete]);

  const handleToggle = () => {
    unlockAudio();
    if (!hasStarted) {
      setHasStarted(true);
      playGo();
    }
    setIsRunning(!isRunning);
  };

  const isWork = phase === 'WORK';

  return (
    <div className="flex flex-col justify-between min-h-[calc(100vh-140px)] select-none">
      {/* Top Status */}
      <div className="space-y-2">
        <div className="flex items-center justify-between text-xs font-bold uppercase tracking-wider text-zinc-400">
          <span className="flex items-center gap-1.5 text-red-400">
            <span className="w-2 h-2 rounded-full bg-red-400 animate-ping" />
            TABATA (4 Min)
          </span>
          <span className="bg-surface-800 text-white font-bold px-3 py-1 rounded-full border border-zinc-700">
            Intervalo {currentRound}/{totalRounds}
          </span>
        </div>

        {/* Global Progress Bar */}
        <div className="w-full bg-surface-900 rounded-full h-1.5 overflow-hidden">
          <div
            className="bg-red-500 h-full transition-all duration-300"
            style={{ width: `${(((currentRound - 1) * 30 + (isWork ? (20 - secondsLeft) : (20 + (10 - secondsLeft)))) / 240) * 100}%` }}
          />
        </div>
      </div>

      {/* Main Center Area with Dynamic Background */}
      <div className="my-auto py-2 space-y-4 text-center">
        {/* Phase Pill */}
        <div className="inline-flex items-center gap-2 px-5 py-2 rounded-full border text-sm font-extrabold uppercase tracking-widest shadow-lg transition-all duration-300">
          {isWork ? (
            <span className="flex items-center gap-2 text-emerald-400 bg-emerald-500/10 border-emerald-500/40 px-4 py-1.5 rounded-full">
              <Zap className="w-4 h-4 fill-emerald-400" />
              ¡TRABAJO ACTIVO!
            </span>
          ) : (
            <span className="flex items-center gap-2 text-amber-400 bg-amber-500/10 border-amber-500/40 px-4 py-1.5 rounded-full">
              <Coffee className="w-4 h-4" />
              DESCANSO
            </span>
          )}
        </div>

        {/* Giant Number Countdown */}
        <div>
          <div
            className={`text-[100px] sm:text-[130px] font-black font-timer tracking-tighter leading-none transition-colors duration-200 ${
              isWork ? 'text-cardio-primary drop-shadow-[0_0_25px_rgba(34,197,94,0.3)]' : 'text-amber-400 drop-shadow-[0_0_25px_rgba(245,158,11,0.3)]'
            }`}
          >
            {formatSecondsOnly(secondsLeft)}
          </div>
          <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest block mt-1">
            Segundos Restantes de {isWork ? 'Trabajo' : 'Descanso'}
          </span>
        </div>

        {/* Exercise Card */}
        <div className="bg-surface-900/90 border border-zinc-800 rounded-2xl p-4 text-left">
          <span className="text-[10px] text-zinc-500 uppercase font-bold block mb-1">
            Ejercicio Tabata
          </span>
          <p className="text-sm font-bold text-zinc-200 leading-snug">
            {bloque.ejercicios[0]?.detalle || 'Trabajo por intervalos'}
          </p>
        </div>
      </div>

      {/* Bottom Controls */}
      <div className="space-y-3 pt-2">
        <button
          onClick={handleToggle}
          className={`w-full py-4 rounded-2xl font-black text-lg flex items-center justify-center gap-2 shadow-xl active:scale-[0.98] transition-all ${
            isRunning
              ? 'bg-amber-500 text-black shadow-amber-500/20'
              : 'bg-cardio-primary text-black shadow-emerald-500/25'
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
              <span>{hasStarted ? 'CONTINUAR' : 'INICIAR TABATA'}</span>
            </>
          )}
        </button>

        <div className="flex items-center justify-between px-2 text-xs text-zinc-500">
          <span>Ronda: {currentRound} de {totalRounds}</span>
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
