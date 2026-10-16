import React from 'react';
import { Volume2, VolumeX, Shield, Zap } from 'lucide-react';

interface HeaderProps {
  isMuted: boolean;
  onToggleMute: () => void;
  isWakeLocked?: boolean;
  onHomeClick?: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  isMuted,
  onToggleMute,
  isWakeLocked = false,
  onHomeClick,
}) => {
  return (
    <header className="sticky top-0 z-40 w-full bg-black/90 backdrop-blur-md border-b border-surface-800 pt-safe px-4 pb-3">
      <div className="max-w-md mx-auto flex items-center justify-between">
        <button
          onClick={onHomeClick}
          className="flex items-center gap-2.5 text-left active:opacity-75 transition-opacity"
        >
          <div className="w-8 h-8 rounded-xl bg-cardio-primary/15 border border-cardio-primary/40 flex items-center justify-center text-cardio-primary">
            <Zap className="w-4 h-4 fill-cardio-primary" />
          </div>
          <div>
            <h1 className="text-base font-bold tracking-tight text-white flex items-center gap-1.5 leading-none">
              CardioFeliz
            </h1>
            <span className="text-[11px] font-medium text-zinc-400">Juli • Foco Quema Grasa</span>
          </div>
        </button>

        <div className="flex items-center gap-2">
          {/* Wake Lock Indicator */}
          {isWakeLocked && (
            <div className="flex items-center gap-1 bg-emerald-950/80 border border-emerald-500/40 text-emerald-400 text-[10px] font-semibold px-2 py-1 rounded-full animate-pulse">
              <Shield className="w-3 h-3" />
              <span>PANTALLA ACTIVA</span>
            </div>
          )}

          {/* Sound Toggle */}
          <button
            onClick={onToggleMute}
            aria-label={isMuted ? "Activar sonido" : "Silenciar"}
            className={`p-2 rounded-xl border transition-colors ${
              isMuted
                ? 'bg-surface-800 border-surface-700 text-zinc-500'
                : 'bg-surface-800 border-zinc-700 text-cardio-primary active:bg-surface-700'
            }`}
          >
            {isMuted ? <VolumeX className="w-4 h-4" /> : <Volume2 className="w-4 h-4" />}
          </button>
        </div>
      </div>
    </header>
  );
};
