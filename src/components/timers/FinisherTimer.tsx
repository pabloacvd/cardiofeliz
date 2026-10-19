import React, { useState, useEffect, useMemo, useRef } from 'react';
import { BloqueFinisher, BloqueHiitIntervals } from '../../types/workout';
import { Play, Pause, Coffee, Sparkles, Wind, Check } from 'lucide-react';
import { formatSecondsOnly, formatTime } from '../../utils/time';
import { buildFinisherPhases, finisherProgress, getFinisherRounds } from '../../utils/timerConfig';

interface FinisherTimerProps {
  bloque: BloqueFinisher | BloqueHiitIntervals;
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
  const totalRounds = getFinisherRounds(bloque);
  const phases = useMemo(() => buildFinisherPhases(bloque), [bloque]);
  const blockLabel = bloque.tipo === 'HIIT_INTERVALS' ? 'HIIT POR INTERVALOS' : 'FINISHER';

  const [phaseIndex, setPhaseIndex] = useState(0);
  const [secondsLeft, setSecondsLeft] = useState(phases[0]?.seconds ?? 0);
  const [isRunning, setIsRunning] = useState(false);
  const [hasStarted, setHasStarted] = useState(false);
  const [totalElapsed, setTotalElapsed] = useState(0);

  // Refs para que el intervalo no se reinicie en cada tick y lea siempre el estado vigente.
  const phaseIndexRef = useRef(0);
  const secondsLeftRef = useRef(phases[0]?.seconds ?? 0);
  const elapsedRef = useRef(0);
  const callbacksRef = useRef({ onComplete, playCountdown, playGo, playRest });
  callbacksRef.current = { onComplete, playCountdown, playGo, playRest };

  const currentPhase = phases[phaseIndex];
  const isManual = currentPhase?.kind === 'MANUAL';
  const isRestLike = currentPhase?.kind === 'REST' || currentPhase?.kind === 'TRANSITION';

  const playPhaseSound = (kind: string | undefined) => {
    if (kind === 'REST' || kind === 'TRANSITION') callbacksRef.current.playRest();
    else callbacksRef.current.playGo();
  };

  const finish = () => {
    setIsRunning(false);
    callbacksRef.current.playGo();
    callbacksRef.current.onComplete(elapsedRef.current);
  };

  const advance = () => {
    const nextIdx = phaseIndexRef.current + 1;
    if (nextIdx >= phases.length) {
      finish();
      return;
    }
    const next = phases[nextIdx];
    phaseIndexRef.current = nextIdx;
    secondsLeftRef.current = next.seconds ?? 0;
    setPhaseIndex(nextIdx);
    setSecondsLeft(next.seconds ?? 0);
    playPhaseSound(next.kind);
  };

  useEffect(() => {
    if (!isRunning) return;

    const interval = setInterval(() => {
      elapsedRef.current += 1;
      setTotalElapsed(elapsedRef.current);

      const phase = phases[phaseIndexRef.current];
      // Los pasos manuales no tienen cuenta regresiva: solo corre el tiempo total.
      if (!phase || phase.seconds === null) return;

      const next = secondsLeftRef.current - 1;
      secondsLeftRef.current = next;
      setSecondsLeft(next);

      if (next > 0) {
        if (next <= 3) callbacksRef.current.playCountdown();
        return;
      }
      advance();
    }, 1000);

    return () => clearInterval(interval);
    // `advance` solo depende de refs, `phases` y setters estables.
  }, [isRunning, phases]);

  const handleToggle = () => {
    unlockAudio();
    if (phases.length === 0) return;
    if (!hasStarted) {
      setHasStarted(true);
      playPhaseSound(currentPhase?.kind);
    }
    setIsRunning((running) => !running);
  };

  const handleManualDone = () => {
    unlockAudio();
    advance();
  };

  const progress = finisherProgress(phases, phaseIndex, secondsLeft);

  const phasePill = (() => {
    switch (currentPhase?.kind) {
      case 'REST':
        return (
          <span className="flex items-center gap-1.5 text-amber-400 bg-amber-500/10 border-amber-500/30 px-3 py-1 rounded-full">
            <Coffee className="w-3.5 h-3.5" />
            Descanso
          </span>
        );
      case 'TRANSITION':
        return (
          <span className="flex items-center gap-1.5 text-amber-400 bg-amber-500/10 border-amber-500/30 px-3 py-1 rounded-full">
            <Wind className="w-3.5 h-3.5" />
            Transición {currentPhase.seconds}s
          </span>
        );
      case 'MANUAL':
        return (
          <span className="flex items-center gap-1.5 text-orange-400 bg-orange-500/10 border-orange-500/30 px-3 py-1 rounded-full">
            <Sparkles className="w-3.5 h-3.5" />
            Por repeticiones
          </span>
        );
      default:
        return (
          <span className="flex items-center gap-1.5 text-orange-400 bg-orange-500/10 border-orange-500/30 px-3 py-1 rounded-full">
            <Sparkles className="w-3.5 h-3.5" />
            Intervalo Activo {currentPhase?.seconds ?? 0}s
          </span>
        );
    }
  })();

  return (
    <div className="flex flex-col justify-between min-h-[calc(100vh-140px)] select-none">
      {/* Top Status */}
      <div className="space-y-2">
        <div className="flex items-center justify-between text-xs font-bold uppercase tracking-wider text-zinc-400">
          <span className="flex items-center gap-1.5 text-orange-400">
            <span className="w-2 h-2 rounded-full bg-orange-400 animate-pulse" />
            {blockLabel} ({totalRounds} {totalRounds === 1 ? 'Ronda' : 'Rondas'})
          </span>
          <span className="bg-surface-800 text-orange-300 font-bold px-3 py-1 rounded-full border border-orange-500/30">
            Ronda {currentPhase?.round ?? totalRounds}/{totalRounds} • {Math.min(phaseIndex + 1, phases.length)}/{phases.length}
          </span>
        </div>

        {/* Global Progress Bar */}
        <div className="w-full bg-surface-900 rounded-full h-1.5 overflow-hidden">
          <div
            className="bg-orange-500 h-full transition-all duration-300"
            style={{ width: `${progress * 100}%` }}
          />
        </div>
      </div>

      {/* Main Countdown & Exercise */}
      <div className="my-auto py-2 space-y-4 text-center">
        {currentPhase ? (
          <>
            {/* Phase Pill */}
            <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full border text-xs font-extrabold uppercase tracking-widest">
              {phasePill}
            </div>

            {/* Giant Number or manual hint */}
            {isManual ? (
              <div className="py-6">
                <div className="mx-auto w-24 h-24 rounded-3xl bg-orange-500/10 border border-orange-500/40 flex items-center justify-center">
                  <Check className="w-12 h-12 text-orange-400" />
                </div>
                <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest block mt-3">
                  Toca LISTO al terminar
                </span>
              </div>
            ) : (
              <div>
                <div
                  className={`text-[96px] sm:text-[120px] font-black font-timer tracking-tighter leading-none ${
                    isRestLike ? 'text-amber-400 drop-shadow-[0_0_20px_rgba(245,158,11,0.25)]' : 'text-orange-400 drop-shadow-[0_0_20px_rgba(249,115,22,0.25)]'
                  }`}
                >
                  00:{formatSecondsOnly(secondsLeft)}
                </div>
                <span className="text-xs font-bold text-zinc-500 uppercase tracking-widest block mt-1">
                  Segundos Restantes
                </span>
              </div>
            )}

            {/* Exercise Card */}
            <div
              className={`p-4 rounded-2xl border text-left ${
                isRestLike
                  ? 'bg-amber-950/20 border-amber-500/40 text-amber-200'
                  : 'bg-surface-900 border-orange-500/40 text-white'
              }`}
            >
              <span className="text-[10px] uppercase font-bold text-zinc-400 block mb-1">
                Ejercicio {currentPhase.exerciseIndex + 1} de {bloque.ejercicios.length}
              </span>
              <h2 className="text-lg font-extrabold leading-tight">
                {currentPhase.detalle}
              </h2>
            </div>
          </>
        ) : (
          <p className="text-sm text-zinc-400">Este bloque no tiene ejercicios configurados.</p>
        )}
      </div>

      {/* Bottom Controls */}
      <div className="space-y-3 pt-2">
        {isManual && isRunning ? (
          <div className="grid grid-cols-4 gap-2">
            <button
              onClick={handleManualDone}
              className="col-span-3 py-4 rounded-2xl font-black text-lg flex items-center justify-center gap-2 shadow-xl active:scale-[0.98] transition-all bg-gradient-to-r from-orange-500 to-amber-500 text-black shadow-orange-500/25"
            >
              <Check className="w-6 h-6" />
              <span>LISTO</span>
            </button>
            <button
              onClick={handleToggle}
              aria-label="Pausar"
              className="py-4 rounded-2xl bg-amber-500 text-black flex items-center justify-center active:scale-[0.98] transition-all"
            >
              <Pause className="w-6 h-6 fill-black" />
            </button>
          </div>
        ) : (
          <button
            onClick={handleToggle}
            disabled={phases.length === 0}
            className={`w-full py-4 rounded-2xl font-black text-lg flex items-center justify-center gap-2 shadow-xl active:scale-[0.98] transition-all disabled:opacity-40 ${
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
                <span>
                  {hasStarted
                    ? 'CONTINUAR'
                    : bloque.tipo === 'HIIT_INTERVALS'
                    ? 'INICIAR HIIT'
                    : 'INICIAR FINISHER'}
                </span>
              </>
            )}
          </button>
        )}

        <div className="flex items-center justify-between px-2 text-xs text-zinc-500">
          <span>Tiempo: {formatTime(totalElapsed)}</span>
          <button
            onClick={() => onComplete(elapsedRef.current)}
            className="text-zinc-400 hover:text-white font-semibold underline underline-offset-4"
          >
            Terminar Bloque
          </button>
        </div>
      </div>
    </div>
  );
};
