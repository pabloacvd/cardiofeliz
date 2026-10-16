import React, { useEffect, useState } from 'react';
import { Bloque, BloqueEMOM, BloqueAMRAP, BloqueForTime, BloqueTabata, BloqueTriserie, BloqueFinisher } from '../types/workout';
import { EmomTimer } from '../components/timers/EmomTimer';
import { AmrapTimer } from '../components/timers/AmrapTimer';
import { ForTimeTimer } from '../components/timers/ForTimeTimer';
import { TabataTimer } from '../components/timers/TabataTimer';
import { TriserieTimer } from '../components/timers/TriserieTimer';
import { FinisherTimer } from '../components/timers/FinisherTimer';
import { useWakeLock } from '../hooks/useWakeLock';
import { useAudioBeeps } from '../hooks/useAudioBeeps';
import { ShieldAlert, ArrowLeft } from 'lucide-react';

interface ActiveWorkoutViewProps {
  bloque: Bloque;
  diaNombre: string;
  onExit: () => void;
  onBlockCompleted: (totalSeconds: number, rounds?: number) => void;
}

export const ActiveWorkoutView: React.FC<ActiveWorkoutViewProps> = ({
  bloque,
  diaNombre,
  onExit,
  onBlockCompleted,
}) => {
  const { isLocked, requestWakeLock, releaseWakeLock } = useWakeLock();
  const { playCountdown, playGo, playRest, playVictory, unlockAudio } = useAudioBeeps();
  const [showExitConfirm, setShowExitConfirm] = useState(false);

  // Request Wake Lock on mount to prevent iPhone screen sleep
  useEffect(() => {
    requestWakeLock();
    return () => {
      releaseWakeLock();
    };
  }, [requestWakeLock, releaseWakeLock]);

  const handleComplete = (totalSeconds: number, rounds?: number) => {
    playVictory();
    onBlockCompleted(totalSeconds, rounds);
  };

  const handleRequestExit = () => {
    setShowExitConfirm(true);
  };

  const handleConfirmExit = () => {
    releaseWakeLock();
    onExit();
  };

  return (
    <div className="flex flex-col min-h-screen bg-black text-white px-4 pt-safe pb-safe animate-fadeIn relative">
      {/* Top Bar with Exit and Block Title */}
      <div className="flex items-center justify-between pb-3 border-b border-surface-800">
        <button
          onClick={handleRequestExit}
          className="flex items-center gap-1 text-xs font-bold text-zinc-400 hover:text-white bg-surface-900 border border-zinc-800 px-3 py-1.5 rounded-xl active:bg-surface-800"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Salir</span>
        </button>

        <div className="text-center flex-1 px-2 overflow-hidden">
          <span className="text-[10px] uppercase font-bold text-zinc-500 block truncate">
            {diaNombre}
          </span>
          <h1 className="text-xs sm:text-sm font-extrabold text-zinc-200 truncate">
            {bloque.nombre}
          </h1>
        </div>

        <div className="w-16 flex justify-end">
          {/* Visual indicator of wake lock */}
          <span
            className={`w-2.5 h-2.5 rounded-full ${
              isLocked ? 'bg-emerald-400 shadow-[0_0_8px_#22c55e]' : 'bg-zinc-700'
            }`}
            title={isLocked ? 'Pantalla protegida contra bloqueo' : 'Wake lock inactivo'}
          />
        </div>
      </div>

      {/* Timer Body */}
      <div className="flex-1 py-2 flex flex-col justify-center">
        {bloque.tipo === 'EMOM' && (
          <EmomTimer
            bloque={bloque as BloqueEMOM}
            onComplete={handleComplete}
            playCountdown={playCountdown}
            playGo={playGo}
            unlockAudio={unlockAudio}
          />
        )}

        {bloque.tipo === 'AMRAP' && (
          <AmrapTimer
            bloque={bloque as BloqueAMRAP}
            onComplete={handleComplete}
            playCountdown={playCountdown}
            playGo={playGo}
            unlockAudio={unlockAudio}
          />
        )}

        {bloque.tipo === 'FOR_TIME' && (
          <ForTimeTimer
            bloque={bloque as BloqueForTime}
            onComplete={handleComplete}
            playCountdown={playCountdown}
            playGo={playGo}
            unlockAudio={unlockAudio}
          />
        )}

        {bloque.tipo === 'TABATA' && (
          <TabataTimer
            bloque={bloque as BloqueTabata}
            onComplete={handleComplete}
            playCountdown={playCountdown}
            playGo={playGo}
            playRest={playRest}
            unlockAudio={unlockAudio}
          />
        )}

        {bloque.tipo === 'TRISERIE' && (
          <TriserieTimer
            bloque={bloque as BloqueTriserie}
            onComplete={handleComplete}
            playCountdown={playCountdown}
            playGo={playGo}
            playRest={playRest}
            unlockAudio={unlockAudio}
          />
        )}

        {bloque.tipo === 'FINISHER' && (
          <FinisherTimer
            bloque={bloque as BloqueFinisher}
            onComplete={handleComplete}
            playCountdown={playCountdown}
            playGo={playGo}
            playRest={playRest}
            unlockAudio={unlockAudio}
          />
        )}
      </div>

      {/* Exit Confirmation Modal */}
      {showExitConfirm && (
        <div className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex items-center justify-center p-4 animate-fadeIn">
          <div className="bg-surface-900 border border-zinc-700 rounded-3xl p-6 max-w-xs w-full text-center shadow-2xl space-y-4">
            <div className="w-12 h-12 rounded-2xl bg-amber-500/20 border border-amber-500/40 text-amber-400 mx-auto flex items-center justify-center">
              <ShieldAlert className="w-6 h-6" />
            </div>

            <div>
              <h3 className="text-base font-extrabold text-white">¿Detener Entrenamiento?</h3>
              <p className="text-xs text-zinc-400 mt-1">
                El progreso del temporizador actual se perderá si sales ahora.
              </p>
            </div>

            <div className="grid grid-cols-2 gap-2 pt-2">
              <button
                onClick={() => setShowExitConfirm(false)}
                className="py-3 rounded-xl bg-surface-800 text-zinc-300 font-bold text-xs active:bg-surface-700"
              >
                Continuar
              </button>
              <button
                onClick={handleConfirmExit}
                className="py-3 rounded-xl bg-red-600 text-white font-extrabold text-xs active:bg-red-700 shadow-lg shadow-red-600/30"
              >
                Salir
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
