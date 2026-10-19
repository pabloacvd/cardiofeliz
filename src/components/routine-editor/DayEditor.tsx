import React, { useState } from 'react';
import type { DiaEntrenamiento, BloqueBase, TipoBloque } from '../../types/workout';
import { BlockEditor } from './BlockEditor';
import {
  ChevronDown,
  ChevronUp,
  ArrowUp,
  ArrowDown,
  Trash2,
  Plus,
  MapPin,
  Flame,
  Dumbbell,
} from 'lucide-react';

interface DayEditorProps {
  dia: DiaEntrenamiento;
  index: number;
  totalDays: number;
  onUpdateDay: (patch: { nombre?: string; ubicacion?: string; calentamiento?: string }) => void;
  onRemoveDay: () => void;
  onMoveDay: (fromIndex: number, toIndex: number) => void;
  onAddBlock: (tipo: TipoBloque) => void;
  onChangeBlockType: (bloqueId: string, newTipo: TipoBloque) => void;
  onUpdateBlock: (bloqueId: string, patch: Partial<BloqueBase>) => void;
  onDuplicateBlock: (bloqueId: string) => void;
  onRemoveBlock: (bloqueId: string) => void;
  onMoveBlock: (fromIndex: number, toIndex: number) => void;
  onAddExercise: (bloqueId: string) => void;
  onUpdateExercise: (
    bloqueId: string,
    exerciseIndex: number,
    patch: { detalle?: string; segundos?: number | null },
  ) => void;
  onRemoveExercise: (bloqueId: string, exerciseIndex: number) => void;
  onMoveExercise: (bloqueId: string, fromIndex: number, toIndex: number) => void;
}

export const DayEditor: React.FC<DayEditorProps> = ({
  dia,
  index,
  totalDays,
  onUpdateDay,
  onRemoveDay,
  onMoveDay,
  onAddBlock,
  onChangeBlockType,
  onUpdateBlock,
  onDuplicateBlock,
  onRemoveBlock,
  onMoveBlock,
  onAddExercise,
  onUpdateExercise,
  onRemoveExercise,
  onMoveExercise,
}) => {
  const [isExpanded, setIsExpanded] = useState(true);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [selectedNewType, setSelectedNewType] = useState<TipoBloque>('AMRAP');

  const handleDelete = () => {
    if (confirmDelete) {
      onRemoveDay();
      setConfirmDelete(false);
    } else {
      setConfirmDelete(true);
    }
  };

  return (
    <div className="rounded-2xl border border-zinc-800 bg-surface-900/90 overflow-hidden space-y-0 transition-all shadow-md">
      {/* Day Header */}
      <div className="p-4 flex items-center justify-between gap-2 bg-gradient-to-r from-surface-900 to-black border-b border-zinc-800">
        <button
          type="button"
          onClick={() => setIsExpanded(!isExpanded)}
          className="flex-1 flex items-center gap-2.5 text-left min-w-0"
        >
          <span className="text-[11px] font-extrabold uppercase tracking-wider px-2.5 py-0.5 rounded-full bg-cardio-primary/15 text-cardio-primary border border-cardio-primary/30 shrink-0">
            {`DÍA ${index + 1}`}
          </span>
          <div className="min-w-0 flex-1">
            <h3 className="text-base font-extrabold text-white leading-tight truncate">
              {dia.nombre || `Día ${index + 1}`}
            </h3>
            {dia.ubicacion && (
              <span className="text-[11px] text-zinc-400 flex items-center gap-1 truncate mt-0.5">
                <MapPin className="w-3 h-3 text-zinc-500 shrink-0" />
                {dia.ubicacion}
              </span>
            )}
          </div>
          {isExpanded ? (
            <ChevronUp className="w-5 h-5 text-zinc-400 shrink-0" />
          ) : (
            <ChevronDown className="w-5 h-5 text-zinc-400 shrink-0" />
          )}
        </button>

        {/* Action buttons */}
        <div className="flex items-center gap-1 shrink-0">
          <button
            type="button"
            disabled={index === 0}
            onClick={() => onMoveDay(index, index - 1)}
            aria-label="Subir día"
            className="p-2 rounded-xl bg-surface-800 border border-zinc-700/60 text-zinc-400 disabled:opacity-30 disabled:pointer-events-none hover:text-white active:bg-surface-700"
          >
            <ArrowUp className="w-4 h-4" />
          </button>
          <button
            type="button"
            disabled={index === totalDays - 1}
            onClick={() => onMoveDay(index, index + 1)}
            aria-label="Bajar día"
            className="p-2 rounded-xl bg-surface-800 border border-zinc-700/60 text-zinc-400 disabled:opacity-30 disabled:pointer-events-none hover:text-white active:bg-surface-700"
          >
            <ArrowDown className="w-4 h-4" />
          </button>
          <button
            type="button"
            onClick={handleDelete}
            aria-label={confirmDelete ? 'Confirmar eliminar día' : 'Eliminar día'}
            className={`p-2 rounded-xl border transition-all text-xs font-bold ${
              confirmDelete
                ? 'bg-red-500/20 border-red-500 text-red-400 px-2.5'
                : 'bg-surface-800 border-zinc-700/60 text-zinc-400 hover:text-red-400 active:bg-surface-700'
            }`}
          >
            {confirmDelete ? '¿Eliminar día?' : <Trash2 className="w-4 h-4" />}
          </button>
        </div>
      </div>

      {/* Day Body */}
      {isExpanded && (
        <div className="p-4 space-y-5">
          {/* Datos del Día */}
          <div className="space-y-3.5">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label
                  htmlFor={`day-name-${dia.id}`}
                  className="block text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-1"
                >
                  Nombre del Día
                </label>
                <input
                  id={`day-name-${dia.id}`}
                  type="text"
                  maxLength={120}
                  value={dia.nombre}
                  onChange={(e) => onUpdateDay({ nombre: e.target.value })}
                  placeholder="Ej: Día 1 - Tren Superior"
                  className="w-full rounded-xl bg-black border border-zinc-700 px-3.5 py-2.5 text-base text-white focus:outline-none focus:border-cardio-primary"
                />
              </div>

              <div>
                <label
                  htmlFor={`day-loc-${dia.id}`}
                  className="block text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-1 flex items-center gap-1"
                >
                  <MapPin className="w-3.5 h-3.5 text-zinc-500" />
                  Ubicación
                </label>
                <input
                  id={`day-loc-${dia.id}`}
                  type="text"
                  maxLength={120}
                  value={dia.ubicacion}
                  onChange={(e) => onUpdateDay({ ubicacion: e.target.value })}
                  placeholder="Ej: Gym, Parque o Casa"
                  className="w-full rounded-xl bg-black border border-zinc-700 px-3.5 py-2.5 text-base text-white focus:outline-none focus:border-cardio-primary"
                />
              </div>
            </div>

            {/* Calentamiento */}
            <div>
              <label
                htmlFor={`day-warmup-${dia.id}`}
                className="block text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-1 flex items-center gap-1"
              >
                <Flame className="w-3.5 h-3.5 text-amber-500" />
                Calentamiento
              </label>
              <textarea
                id={`day-warmup-${dia.id}`}
                maxLength={300}
                rows={2}
                value={dia.calentamiento}
                onChange={(e) => onUpdateDay({ calentamiento: e.target.value })}
                placeholder="Ej: 5 min caminata inclinada o movilidad articular..."
                className="w-full rounded-xl bg-black border border-zinc-700 px-3.5 py-2.5 text-base text-white focus:outline-none focus:border-cardio-primary resize-none"
              />
              <div className="flex justify-end">
                <span className="text-[10px] text-zinc-500">{dia.calentamiento.length}/300</span>
              </div>
            </div>
          </div>

          {/* Bloques */}
          <div className="space-y-3 pt-2 border-t border-zinc-800">
            <div className="flex items-center justify-between">
              <h4 className="text-xs font-bold uppercase tracking-wider text-zinc-300 flex items-center gap-1.5">
                <Dumbbell className="w-4 h-4 text-cardio-primary" />
                Bloques de Entrenamiento ({dia.bloques.length}/8)
              </h4>
            </div>

            {dia.bloques.length === 0 ? (
              <div className="p-4 rounded-xl bg-black/40 border border-dashed border-zinc-800 text-center text-xs text-zinc-500">
                Este día no tiene bloques de entrenamiento. Agregá al menos uno.
              </div>
            ) : (
              <div className="space-y-3">
                {dia.bloques.map((bloque, bIdx) => (
                  <BlockEditor
                    key={bloque.id ?? bIdx}
                    bloque={bloque}
                    index={bIdx}
                    totalBlocks={dia.bloques.length}
                    onChangeType={(newTipo) => onChangeBlockType(bloque.id!, newTipo)}
                    onUpdateBlock={(patch) => onUpdateBlock(bloque.id!, patch)}
                    onDuplicateBlock={() => onDuplicateBlock(bloque.id!)}
                    onRemoveBlock={() => onRemoveBlock(bloque.id!)}
                    onMoveBlock={(fIdx, tIdx) => onMoveBlock(fIdx, tIdx)}
                    onAddExercise={() => onAddExercise(bloque.id!)}
                    onUpdateExercise={(eIdx, patch) => onUpdateExercise(bloque.id!, eIdx, patch)}
                    onRemoveExercise={(eIdx) => onRemoveExercise(bloque.id!, eIdx)}
                    onMoveExercise={(fIdx, tIdx) => onMoveExercise(bloque.id!, fIdx, tIdx)}
                  />
                ))}
              </div>
            )}

            {/* Agregar Bloque */}
            {dia.bloques.length < 8 && (
              <div className="flex flex-col sm:flex-row items-center gap-2 pt-1">
                <select
                  value={selectedNewType}
                  onChange={(e) => setSelectedNewType(e.target.value as TipoBloque)}
                  className="w-full sm:w-auto flex-1 rounded-xl bg-black border border-zinc-700 px-3 py-2.5 text-sm text-white focus:outline-none focus:border-cardio-primary"
                >
                  <option value="AMRAP">AMRAP (Por tiempo)</option>
                  <option value="EMOM">EMOM (Cada minuto)</option>
                  <option value="TRISERIE">TRISERIE (Series con descanso)</option>
                  <option value="DENSITY">DENSITY (Rondas continuas)</option>
                  <option value="FOR_TIME">FOR TIME (Completar con time cap)</option>
                  <option value="TABATA">TABATA (Intervalos alta intensidad)</option>
                  <option value="FINISHER">FINISHER (Cierre de sesión)</option>
                  <option value="HIIT_INTERVALS">HIIT INTERVALS (Intervalos cronometrados)</option>
                </select>
                <button
                  type="button"
                  onClick={() => onAddBlock(selectedNewType)}
                  className="w-full sm:w-auto py-2.5 px-4 rounded-xl bg-cardio-primary text-black font-extrabold text-xs flex items-center justify-center gap-1.5 active:scale-[0.98] transition-transform shadow-md"
                >
                  <Plus className="w-4 h-4" />
                  <span>Agregar Bloque</span>
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
