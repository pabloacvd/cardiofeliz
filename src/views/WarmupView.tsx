import React, { useEffect, useState } from 'react';
import { DiaEntrenamiento } from '../types/workout';
import { ArrowLeft, Play, Pause, RotateCcw, Activity, ChevronRight } from 'lucide-react';
import { formatTime } from '../utils/time';
import { useWakeLock } from '../hooks/useWakeLock';
import { useAudioBeeps } from '../hooks/useAudioBeeps';

interface WarmupViewProps {
  dia: DiaEntrenamiento;
  onBack: () => void;
  onStartFirstBlock: () => void;
}

export const WarmupView: React.FC<WarmupViewProps> = ({ dia, onBack, onStartFirstBlock }) => {
  const hasTimer = (dia.calentamiento_minutos ?? 0) > 0;
  const initialSeconds = (dia.calentamiento_minutos ?? 0) * 60;

  const [secondsLeft, setSecondsLeft] = useState(initialSeconds);
  const [isRunning, setIsRunning] = useState(false);
  const timerDone = hasTimer && secondsLeft === 0;

  const { requestWakeLock, isLocked } = useWakeLock();
  const { playGo, playCountdown, unlockAudio } = useAudioBeeps();

  useEffect(() => {
    requestWakeLock();
  }, [requestWakeLock]);

  useEffect(() => {
    if (!isRunning) return;
    if (secondsLeft <= 0) {
      setIsRunning(false);
      return;
    }
    const interval = setInterval(() => {
      setSecondsLeft((prev) => {
        if (prev <= 4 && prev > 1) playCountdown();
        else if (prev === 1) playGo();
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, [isRunning, secondsLeft, playCountdown, playGo]);

  const handleToggle = () => {
    unlockAudio();
    setIsRunning((r) => !r);
  };

  const handleReset = () => {
    setIsRunning(false);
    setSecondsLeft(initialSeconds);
  };

  return (
    <div className="flex flex-col min-h-screen bg-black text-white px-4 pt-safe pb-safe animate-fadeIn">
      {/* Top Bar */}
      <div className="flex items-center justify-between pb-3 border-b border-surface-800">
        <button
          onClick={onBack}
          className="flex items-center gap-1 text-xs font-bold text-zinc-400 hover:text-white bg-surface-900 border border-zinc-800 px-3 py-1.5 rounded-xl active:bg-surface-800"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Volver</span>
        </button>

        <div className="text-center flex-1 px-2 overflow-hidden">
          <span className="text-[10px] uppercase font-bold text-zinc-500 block truncate">
            {dia.nombre}
          </span>
          <h1 className="text-xs sm:text-sm font-extrabold text-amber-300 truncate">
            Calentamiento
          </h1>
        </div>

        <div className="w-16 flex justify-end">
          <span
            className={`w-2.5 h-2.5 rounded-full ${
              isLocked ? 'bg-emerald-400 shadow-[0_0_8px_#22c55e]' : 'bg-zinc-700'
            }`}
            title={isLocked ? 'Pantalla protegida contra bloqueo' : 'Wake lock inactivo'}
          />
        </div>
      </div>

      {/* Body */}
      <div className="flex-1 py-6 flex flex-col gap-5">
        {/* Warmup description */}
        <div className="rounded-2xl border border-amber-500/30 bg-gradient-to-b from-amber-950/20 to-surface-900 p-4">
          <div className="flex items-center gap-2 mb-3">
            <div className="p-1.5 rounded-lg bg-amber-500/20 text-amber-400">
              <Activity className="w-4 h-4" />
            </div>
            <h3 className="text-sm font-bold text-amber-300 uppercase tracking-wide">
              Calentamiento
            </h3>
          </div>
          <p className="text-xs text-zinc-200 leading-relaxed bg-black/40 p-2.5 rounded-xl border border-surface-800">
            {dia.calentamiento}
          </p>
        </div>

        {/* Timer */}
        {hasTimer && (
          <div className="rounded-2xl border border-amber-500/20 bg-black/60 p-5 flex flex-col items-center gap-4">
            <span className="text-[10px] text-zinc-400 uppercase font-semibold tracking-wider">
              Timer de Calentamiento
            </span>
            <span
              className={`text-6xl font-extrabold font-timer tabular-nums transition-colors ${
                timerDone ? 'text-emerald-400' : 'text-amber-300'
              }`}
            >
              {formatTime(secondsLeft)}
            </span>
            <div className="flex items-center gap-3">
              <button
                onClick={handleToggle}
                disabled={timerDone}
                className={`px-5 py-2.5 rounded-xl font-bold text-sm flex items-center gap-2 disabled:opacity-40 ${
                  isRunning
                    ? 'bg-amber-500 text-black'
                    : 'bg-amber-400 text-black active:bg-amber-300'
                }`}
              >
                {isRunning ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4 fill-black" />}
                {isRunning ? 'Pausar' : timerDone ? '¡Listo!' : 'Iniciar'}
              </button>
              <button
                onClick={handleReset}
                className="p-2.5 rounded-xl bg-surface-800 text-zinc-400 border border-surface-700 active:text-white"
              >
                <RotateCcw className="w-4 h-4" />
              </button>
            </div>
            {timerDone && (
              <p className="text-xs text-emerald-400 font-semibold">
                ¡Calentamiento completo! Podés comenzar el primer bloque.
              </p>
            )}
          </div>
        )}
      </div>

      {/* CTA */}
      <div className="pb-6">
        <button
          onClick={onStartFirstBlock}
          className="w-full py-4 px-5 rounded-2xl bg-gradient-to-r from-cardio-primary to-emerald-400 text-black font-extrabold text-base flex items-center justify-center gap-2.5 shadow-xl shadow-emerald-500/25 active:scale-[0.98] transition-transform"
        >
          <ChevronRight className="w-5 h-5" />
          <span>Pasar al Bloque A</span>
        </button>
      </div>
    </div>
  );
};
