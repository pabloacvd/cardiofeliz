import React, { useState } from 'react';
import { BottomSheet } from './BottomSheet';
import { Palmtree, AlertCircle, Sparkles, Check, Trash2, Calendar } from 'lucide-react';
import type { VacationStatus } from '../gamification/vacations';
import type { DateKey } from '../gamification';

interface VacationSheetProps {
  status: VacationStatus;
  today: DateKey;
  onClose: () => void;
  onStartVacation: (startOn: DateKey) => void;
  onEndVacation: (today: DateKey) => void;
  onDeleteVacation?: (id: string) => void;
}

export const VacationSheet: React.FC<VacationSheetProps> = ({
  status,
  today,
  onClose,
  onStartVacation,
  onEndVacation,
  onDeleteVacation,
}) => {
  const [startDate, setStartDate] = useState<string>(today);
  const [confirmEnd, setConfirmEnd] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);

  const handleStart = (e: React.FormEvent) => {
    e.preventDefault();
    if (!startDate || startDate > today) return;
    onStartVacation(startDate);
    onClose();
  };

  const handleEnd = () => {
    if (!confirmEnd) {
      setConfirmEnd(true);
      return;
    }
    onEndVacation(today);
    onClose();
  };

  const handleDelete = () => {
    if (!confirmDelete) {
      setConfirmDelete(true);
      return;
    }
    if (status.current && onDeleteVacation) {
      onDeleteVacation(status.current.id);
    }
    onClose();
  };

  return (
    <BottomSheet title="Modo Vacaciones" onClose={onClose}>
      <div className="space-y-4 text-left">
        {status.active ? (
          <div className="space-y-4">
            <div className="p-4 rounded-2xl bg-purple-950/30 border border-purple-500/40 space-y-2">
              <div className="flex items-center gap-2 text-purple-300 font-extrabold text-sm">
                <Palmtree className="w-5 h-5 text-purple-400" />
                <span>Vacaciones en curso</span>
              </div>
              <p className="text-xs text-zinc-300 leading-relaxed">
                Iniciadas el <strong className="text-white">{status.current?.startOn}</strong> ({status.lengthDays}{' '}
                {status.lengthDays === 1 ? 'día' : 'días'}). Tu racha está congelada sin gastar congeladores.
              </p>
              {status.longWarning && (
                <div className="flex items-start gap-2 p-2.5 rounded-xl bg-orange-950/40 border border-orange-500/40 text-orange-300 text-xs">
                  <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Llevás más de 30 días de vacaciones. Tu racha se mantiene intacta.</span>
                </div>
              )}
            </div>

            <div className="p-3.5 rounded-2xl bg-surface-800/80 border border-zinc-700/60 space-y-1.5 text-xs text-zinc-300">
              <p className="font-bold text-white flex items-center gap-1.5">
                <Sparkles className="w-4 h-4 text-amber-400" />
                Al volver de vacaciones:
              </p>
              <p className="text-zinc-400 leading-snug">
                Se activan <strong>3 días de &quot;¡Hay que recuperar!&quot;</strong> con misiones suaves y un multiplicador
                de <strong>×1.5 XP</strong> en tus entrenamientos.
              </p>
            </div>

            <div className="space-y-2 pt-2">
              <button
                type="button"
                onClick={handleEnd}
                className={`w-full py-3.5 rounded-2xl font-extrabold text-sm flex items-center justify-center gap-2 transition-all ${
                  confirmEnd
                    ? 'bg-emerald-500 text-black shadow-lg shadow-emerald-500/20'
                    : 'bg-cardio-primary text-black'
                }`}
              >
                <Check className="w-4 h-4" />
                {confirmEnd ? '¿Confirmar regreso hoy?' : 'Volver de vacaciones hoy'}
              </button>

              {onDeleteVacation && status.current && (
                <button
                  type="button"
                  onClick={handleDelete}
                  className="w-full py-2.5 rounded-xl text-zinc-400 hover:text-red-400 text-xs font-semibold flex items-center justify-center gap-1.5 transition-colors"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  {confirmDelete ? '¿Eliminar este período?' : 'Cancelar período de vacaciones'}
                </button>
              )}
            </div>
          </div>
        ) : (
          <form onSubmit={handleStart} className="space-y-4">
            <div className="p-3.5 rounded-2xl bg-surface-800/60 border border-zinc-800 space-y-2 text-xs text-zinc-300">
              <div className="flex items-center gap-2 text-white font-bold">
                <Palmtree className="w-4 h-4 text-purple-400" />
                <span>¿Te vas de viaje o descanso?</span>
              </div>
              <p className="text-zinc-400 leading-relaxed">
                El Modo Vacaciones <strong>congela tu racha</strong> y la racha semanal mientras esté activo. No consume tus
                congeladores acumulados y podés reactivar tu rutina cuando vuelvas.
              </p>
            </div>

            <div>
              <label htmlFor="vacation-start" className="block text-xs font-bold text-zinc-300 mb-1.5">
                Fecha de inicio
              </label>
              <div className="relative">
                <input
                  id="vacation-start"
                  type="date"
                  value={startDate}
                  max={today}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="w-full rounded-xl bg-surface-800 border border-zinc-700 px-3 py-2.5 text-sm font-semibold text-white focus:outline-none focus:border-cardio-primary"
                  required
                />
                <Calendar className="w-4 h-4 text-zinc-400 absolute right-3 top-3 pointer-events-none" />
              </div>
              <span className="text-[11px] text-zinc-500 mt-1 block">Por defecto es hoy.</span>
            </div>

            <button
              type="submit"
              className="w-full py-3.5 rounded-2xl bg-purple-600 hover:bg-purple-500 text-white font-extrabold text-sm flex items-center justify-center gap-2 shadow-lg shadow-purple-600/25 transition-all"
            >
              <Palmtree className="w-4 h-4" />
              Activar Modo Vacaciones
            </button>
          </form>
        )}
      </div>
    </BottomSheet>
  );
};
