import React from 'react';
import { Volume2, VolumeX, Shield, Zap, LogOut, CloudCheck, CloudUpload, CloudOff } from 'lucide-react';
import type { SyncStatus } from '../hooks/useActivities';

const SYNC_INDICATOR: Record<SyncStatus, { label: string; className: string; Icon: typeof CloudCheck }> = {
  synced: { label: 'Progreso sincronizado', className: 'text-zinc-500', Icon: CloudCheck },
  syncing: { label: 'Sincronizando progreso', className: 'text-cyan-400 animate-pulse', Icon: CloudUpload },
  pending: { label: 'Progreso guardado en este dispositivo, pendiente de sincronizar', className: 'text-amber-400', Icon: CloudUpload },
  offline: { label: 'Sin conexión: se sincronizará al volver', className: 'text-amber-400', Icon: CloudOff },
};

interface HeaderProps {
  syncStatus?: SyncStatus;
  isMuted: boolean;
  onToggleMute: () => void;
  isWakeLocked?: boolean;
  onHomeClick?: () => void;
  userName?: string;
  onSignOut?: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  syncStatus,
  isMuted,
  onToggleMute,
  isWakeLocked = false,
  onHomeClick,
  userName,
  onSignOut,
}) => {
  const syncInfo = syncStatus ? SYNC_INDICATOR[syncStatus] : null;

  const handleSignOut = () => {
    if (window.confirm('¿Cerrar sesión?')) {
      onSignOut?.();
    }
  };

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
            <span className="text-[11px] font-medium text-zinc-400">
              {userName ? `${userName} • Foco Quema Grasa` : 'Foco Quema Grasa'}
            </span>
          </div>
        </button>

        <div className="flex items-center gap-2">
          {/* Sync status */}
          {syncInfo && (
            <div
              role="status"
              aria-label={syncInfo.label}
              title={syncInfo.label}
              className={syncInfo.className}
            >
              <syncInfo.Icon className="w-4 h-4" />
            </div>
          )}

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

          {/* Sign out */}
          {onSignOut && (
            <button
              onClick={handleSignOut}
              aria-label="Cerrar sesión"
              className="p-2 rounded-xl border bg-surface-800 border-zinc-700 text-zinc-400 active:bg-surface-700 transition-colors"
            >
              <LogOut className="w-4 h-4" />
            </button>
          )}
        </div>
      </div>
    </header>
  );
};
