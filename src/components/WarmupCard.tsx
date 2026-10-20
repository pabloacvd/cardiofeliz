import React from 'react';
import { Activity } from 'lucide-react';

interface WarmupCardProps {
  calentamiento: string;
  calentamientoMinutos?: number;
}

export const WarmupCard: React.FC<WarmupCardProps> = ({ calentamiento, calentamientoMinutos }) => {
  return (
    <div className="rounded-2xl border border-amber-500/30 bg-gradient-to-b from-amber-950/20 to-surface-900 p-4 mb-4">
      <div className="flex items-center gap-2 mb-3">
        <div className="p-1.5 rounded-lg bg-amber-500/20 text-amber-400">
          <Activity className="w-4 h-4" />
        </div>
        <div>
          <h3 className="text-sm font-bold text-amber-300 uppercase tracking-wide">
            Calentamiento
          </h3>
          {calentamientoMinutos && calentamientoMinutos > 0 && (
            <span className="text-[11px] text-zinc-400">{calentamientoMinutos} min</span>
          )}
        </div>
      </div>

      <p className="text-xs text-zinc-200 leading-relaxed bg-black/40 p-2.5 rounded-xl border border-surface-800">
        {calentamiento}
      </p>
    </div>
  );
};
