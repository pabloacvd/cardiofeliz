import React from 'react';
import { User, Scale, Palmtree, LogOut } from 'lucide-react';

interface AccountSectionProps {
  userName: string;
  weightKg: number | null;
  onEditWeight: () => void;
  onManageVacations: () => void;
  isVacationActive: boolean;
  onSignOut: () => void;
}

export const AccountSection: React.FC<AccountSectionProps> = ({
  userName,
  weightKg,
  onEditWeight,
  onManageVacations,
  isVacationActive,
  onSignOut,
}) => {
  const handleSignOut = () => {
    if (window.confirm('¿Cerrar sesión?')) {
      onSignOut();
    }
  };

  return (
    <div
      role="region"
      aria-label="Cuenta y Configuración"
      className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-4 shadow-lg"
    >
      <div className="flex items-center gap-2">
        <div className="p-1.5 rounded-lg bg-zinc-800 text-zinc-300">
          <User className="w-4 h-4" />
        </div>
        <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
          Cuenta y Preferencias
        </h3>
      </div>

      <div className="space-y-2">
        {/* Usuario */}
        <div className="flex items-center justify-between p-3 rounded-xl bg-black/50 border border-zinc-800/80">
          <div>
            <span className="text-[10px] text-zinc-500 uppercase font-bold block">Usuario Conectado</span>
            <span className="text-sm font-extrabold text-white">{userName}</span>
          </div>
        </div>

        {/* Peso */}
        <div className="flex items-center justify-between p-3 rounded-xl bg-black/50 border border-zinc-800/80">
          <div>
            <span className="text-[10px] text-zinc-500 uppercase font-bold block">Peso Corporal</span>
            <span className="text-sm font-extrabold text-white">
              {weightKg !== null ? `${String(weightKg).replace('.', ',')} kg` : 'Sin registrar'}
            </span>
          </div>
          <button
            type="button"
            onClick={onEditWeight}
            className="px-3 py-1.5 rounded-lg bg-surface-800 hover:bg-surface-700 text-xs font-bold text-zinc-200 border border-zinc-700 flex items-center gap-1.5 transition-colors"
          >
            <Scale className="w-3.5 h-3.5 text-cardio-primary" />
            Editar
          </button>
        </div>

        {/* Modo Vacaciones */}
        <div className="flex items-center justify-between p-3 rounded-xl bg-black/50 border border-zinc-800/80">
          <div>
            <span className="text-[10px] text-zinc-500 uppercase font-bold block">Modo Vacaciones</span>
            <span className={`text-xs font-bold ${isVacationActive ? 'text-purple-400' : 'text-zinc-400'}`}>
              {isVacationActive ? 'Activo (Racha pausada)' : 'Inactivo'}
            </span>
          </div>
          <button
            type="button"
            onClick={onManageVacations}
            className="px-3 py-1.5 rounded-lg bg-surface-800 hover:bg-surface-700 text-xs font-bold text-zinc-200 border border-zinc-700 flex items-center gap-1.5 transition-colors"
          >
            <Palmtree className="w-3.5 h-3.5 text-purple-400" />
            Gestionar
          </button>
        </div>

        {/* Cerrar Sesión */}
        <button
          type="button"
          onClick={handleSignOut}
          className="w-full mt-2 py-3 rounded-xl bg-red-950/20 hover:bg-red-950/40 border border-red-500/30 text-red-400 hover:text-red-300 text-xs font-extrabold flex items-center justify-center gap-2 transition-colors"
        >
          <LogOut className="w-4 h-4" />
          Cerrar Sesión
        </button>
      </div>
    </div>
  );
};
