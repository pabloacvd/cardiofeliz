import React, { useState, useEffect } from 'react';
import { Play, Pause, RotateCcw, Activity } from 'lucide-react';
import { formatTime } from '../utils/time';
import { useAudioBeeps } from '../hooks/useAudioBeeps';

interface WarmupCardProps {
  calentamiento: string;
}

export const WarmupCard: React.FC<WarmupCardProps> = ({ calentamiento }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(300); // 5 minutes default
  const [isRunning, setIsRunning] = useState(false);
  const { playGo, playCountdown, unlockAudio } = useAudioBeeps();

  useEffect(() => {
    let interval: ReturnType<typeof setInterval>;
    if (isRunning && secondsLeft > 0) {
      interval = setInterval(() => {
        setSecondsLeft((prev) => {
          if (prev <= 4 && prev > 1) {
            playCountdown();
          } else if (prev === 1) {
            playGo();
            setIsRunning(false);
          }
          return prev - 1;
        });
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [isRunning, secondsLeft, playCountdown, playGo]);

  const handleToggleTimer = () => {
    unlockAudio();
    setIsRunning(!isRunning);
  };

  const handleResetTimer = () => {
    setIsRunning(false);
    setSecondsLeft(300);
  };

  return (
    <div className="rounded-2xl border border-amber-500/30 bg-gradient-to-b from-amber-950/20 to-surface-900 p-4 mb-4">
      <div className="flex items-start justify-between gap-2">
        <div className="flex items-center gap-2">
          <div className="p-1.5 rounded-lg bg-amber-500/20 text-amber-400">
            <Activity className="w-4 h-4" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-amber-300 uppercase tracking-wide">
              Calentamiento Sugerido
            </h3>
            <span className="text-[11px] text-zinc-400">Activación metabólica y articular</span>
          </div>
        </div>

        <button
          onClick={() => setIsOpen(!isOpen)}
          className="text-[11px] font-semibold text-amber-400 bg-amber-500/10 border border-amber-500/30 px-2.5 py-1 rounded-lg active:bg-amber-500/20"
        >
          {isOpen ? 'Ocultar Timer' : 'Abrir Timer (5 min)'}
        </button>
      </div>

      <p className="mt-2.5 text-xs text-zinc-200 leading-relaxed bg-black/40 p-2.5 rounded-xl border border-surface-800">
        {calentamiento}
      </p>

      {isOpen && (
        <div className="mt-3 pt-3 border-t border-amber-500/20 flex items-center justify-between bg-black/60 p-3 rounded-xl">
          <div>
            <span className="text-[10px] text-zinc-400 uppercase font-semibold block">Timer Calentamiento</span>
            <span className="text-2xl font-extrabold font-timer text-amber-300">
              {formatTime(secondsLeft)}
            </span>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={handleToggleTimer}
              className={`px-4 py-2 rounded-xl font-bold text-xs flex items-center gap-1.5 ${
                isRunning
                  ? 'bg-amber-500 text-black'
                  : 'bg-amber-400 text-black active:bg-amber-300'
              }`}
            >
              {isRunning ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5 fill-black" />}
              {isRunning ? 'Pausar' : 'Iniciar'}
            </button>
            <button
              onClick={handleResetTimer}
              className="p-2 rounded-xl bg-surface-800 text-zinc-400 border border-surface-700 active:text-white"
            >
              <RotateCcw className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
