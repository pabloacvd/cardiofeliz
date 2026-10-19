import React, { useState } from 'react';
import type { Bloque, BloqueBase, TipoBloque } from '../../types/workout';
import { TIPOS_VALIDOS } from '../../utils/routine';
import { ExerciseEditor } from './ExerciseEditor';
import {
  ChevronDown,
  ChevronUp,
  ArrowUp,
  ArrowDown,
  Copy,
  Trash2,
  Clock,
  Layers,
} from 'lucide-react';

interface BlockEditorProps {
  bloque: Bloque;
  index: number;
  totalBlocks: number;
  onChangeType: (newTipo: TipoBloque) => void;
  onUpdateBlock: (patch: Partial<BloqueBase>) => void;
  onDuplicateBlock: () => void;
  onRemoveBlock: () => void;
  onMoveBlock: (fromIndex: number, toIndex: number) => void;
  onAddExercise: () => void;
  onUpdateExercise: (index: number, patch: { detalle?: string; segundos?: number | null }) => void;
  onRemoveExercise: (index: number) => void;
  onMoveExercise: (fromIndex: number, toIndex: number) => void;
}

export const BlockEditor: React.FC<BlockEditorProps> = ({
  bloque,
  index,
  totalBlocks,
  onChangeType,
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

  const handleDelete = () => {
    if (confirmDelete) {
      onRemoveBlock();
      setConfirmDelete(false);
    } else {
      setConfirmDelete(true);
    }
  };

  const getBadgeStyle = (tipo: string) => {
    switch (tipo) {
      case 'EMOM':
        return 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30';
      case 'AMRAP':
        return 'bg-amber-500/15 text-amber-400 border-amber-500/30';
      case 'FOR_TIME':
        return 'bg-cyan-500/15 text-cyan-400 border-cyan-500/30';
      case 'TABATA':
        return 'bg-red-500/15 text-red-400 border-red-500/30';
      case 'TRISERIE':
        return 'bg-purple-500/15 text-purple-400 border-purple-500/30';
      case 'DENSITY':
        return 'bg-indigo-500/15 text-indigo-400 border-indigo-500/30';
      case 'FINISHER':
        return 'bg-orange-500/15 text-orange-400 border-orange-500/30';
      case 'HIIT_INTERVALS':
        return 'bg-rose-500/15 text-rose-400 border-rose-500/30';
      default:
        return 'bg-zinc-800 text-zinc-300 border-zinc-700';
    }
  };

  return (
    <div className="rounded-2xl border border-zinc-800 bg-surface-900 overflow-hidden space-y-0 transition-all shadow-sm">
      {/* Header */}
      <div className="p-3.5 flex items-center justify-between gap-2 bg-surface-900 border-b border-zinc-800/80">
        <button
          type="button"
          onClick={() => setIsExpanded(!isExpanded)}
          className="flex-1 flex items-center gap-2 text-left min-w-0"
        >
          <span
            className={`text-[10px] font-extrabold uppercase tracking-wider px-2 py-0.5 rounded-full border shrink-0 ${getBadgeStyle(
              bloque.tipo,
            )}`}
          >
            {bloque.tipo}
          </span>
          <span className="text-sm font-bold text-white truncate">
            {bloque.nombre || `Bloque ${index + 1}`}
          </span>
          {isExpanded ? (
            <ChevronUp className="w-4 h-4 text-zinc-400 shrink-0" />
          ) : (
            <ChevronDown className="w-4 h-4 text-zinc-400 shrink-0" />
          )}
        </button>

        {/* Action buttons */}
        <div className="flex items-center gap-1 shrink-0">
          <button
            type="button"
            disabled={index === 0}
            onClick={() => onMoveBlock(index, index - 1)}
            aria-label="Subir bloque"
            className="p-1.5 rounded-lg bg-surface-800 border border-zinc-700/60 text-zinc-400 disabled:opacity-30 disabled:pointer-events-none hover:text-white active:bg-surface-700"
          >
            <ArrowUp className="w-3.5 h-3.5" />
          </button>
          <button
            type="button"
            disabled={index === totalBlocks - 1}
            onClick={() => onMoveBlock(index, index + 1)}
            aria-label="Bajar bloque"
            className="p-1.5 rounded-lg bg-surface-800 border border-zinc-700/60 text-zinc-400 disabled:opacity-30 disabled:pointer-events-none hover:text-white active:bg-surface-700"
          >
            <ArrowDown className="w-3.5 h-3.5" />
          </button>
          <button
            type="button"
            onClick={onDuplicateBlock}
            aria-label="Duplicar bloque"
            title="Duplicar bloque"
            className="p-1.5 rounded-lg bg-surface-800 border border-zinc-700/60 text-zinc-400 hover:text-cardio-primary active:bg-surface-700"
          >
            <Copy className="w-3.5 h-3.5" />
          </button>
          <button
            type="button"
            onClick={handleDelete}
            aria-label={confirmDelete ? 'Confirmar eliminar bloque' : 'Eliminar bloque'}
            className={`p-1.5 rounded-lg border transition-all text-xs font-bold ${
              confirmDelete
                ? 'bg-red-500/20 border-red-500 text-red-400 px-2'
                : 'bg-surface-800 border-zinc-700/60 text-zinc-400 hover:text-red-400 active:bg-surface-700'
            }`}
          >
            {confirmDelete ? '¿Borrar?' : <Trash2 className="w-3.5 h-3.5" />}
          </button>
        </div>
      </div>

      {/* Body */}
      {isExpanded && (
        <div className="p-3.5 space-y-4">
          {/* Tipo y Nombre */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label
                htmlFor={`block-type-${bloque.id ?? index}`}
                className="block text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-1 flex items-center gap-1"
              >
                <Layers className="w-3.5 h-3.5 text-zinc-500" />
                Tipo de Bloque
              </label>
              <select
                id={`block-type-${bloque.id ?? index}`}
                value={bloque.tipo}
                onChange={(e) => onChangeType(e.target.value as TipoBloque)}
                className="w-full rounded-xl bg-black border border-zinc-700 px-3 py-2.5 text-base text-white focus:outline-none focus:border-cardio-primary"
              >
                {TIPOS_VALIDOS.map((t) => (
                  <option key={t} value={t}>
                    {t}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label
                htmlFor={`block-name-${bloque.id ?? index}`}
                className="block text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-1"
              >
                Nombre del Bloque
              </label>
              <input
                id={`block-name-${bloque.id ?? index}`}
                type="text"
                maxLength={120}
                value={bloque.nombre}
                onChange={(e) => onUpdateBlock({ nombre: e.target.value })}
                placeholder="Ej: Bloque A, Finisher Core..."
                className="w-full rounded-xl bg-black border border-zinc-700 px-3.5 py-2.5 text-base text-white focus:outline-none focus:border-cardio-primary"
              />
            </div>
          </div>

          {/* Parámetros específicos por tipo */}
          <div className="p-3 rounded-xl bg-black/50 border border-zinc-800/80 space-y-3">
            <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-wider flex items-center gap-1">
              <Clock className="w-3 h-3" />
              Parámetros de Tiempo y Rondas
            </span>

            {/* EMOM / AMRAP */}
            {(bloque.tipo === 'EMOM' || bloque.tipo === 'AMRAP') && (
              <div>
                <label className="block text-xs text-zinc-300 font-semibold mb-1">
                  Duración Total (Minutos)
                </label>
                <input
                  type="number"
                  inputMode="numeric"
                  min={1}
                  max={120}
                  value={bloque.duracion_minutos ?? ''}
                  onChange={(e) => {
                    const val = parseInt(e.target.value, 10);
                    onUpdateBlock({ duracion_minutos: isNaN(val) ? 1 : val });
                  }}
                  className="w-full rounded-lg bg-surface-900 border border-zinc-700 px-3 py-2 text-base text-white focus:outline-none focus:border-cardio-primary"
                />
              </div>
            )}

            {/* FOR_TIME */}
            {bloque.tipo === 'FOR_TIME' && (
              <div>
                <label className="block text-xs text-zinc-300 font-semibold mb-1">
                  Time Cap (Minutos Límite)
                </label>
                <input
                  type="number"
                  inputMode="numeric"
                  min={1}
                  max={120}
                  value={bloque.cap_minutos ?? ''}
                  onChange={(e) => {
                    const val = parseInt(e.target.value, 10);
                    onUpdateBlock({ cap_minutos: isNaN(val) ? 1 : val });
                  }}
                  className="w-full rounded-lg bg-surface-900 border border-zinc-700 px-3 py-2 text-base text-white focus:outline-none focus:border-cardio-primary"
                />
              </div>
            )}

            {/* TRISERIE / DENSITY */}
            {(bloque.tipo === 'TRISERIE' || bloque.tipo === 'DENSITY') && (
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs text-zinc-300 font-semibold mb-1">Rondas</label>
                  <input
                    type="number"
                    inputMode="numeric"
                    min={1}
                    max={99}
                    value={bloque.rondas ?? ''}
                    onChange={(e) => {
                      const val = parseInt(e.target.value, 10);
                      onUpdateBlock({ rondas: isNaN(val) ? 1 : val });
                    }}
                    className="w-full rounded-lg bg-surface-900 border border-zinc-700 px-3 py-2 text-base text-white focus:outline-none focus:border-cardio-primary"
                  />
                </div>
                <div>
                  <label className="block text-xs text-zinc-300 font-semibold mb-1">
                    Descanso (Segundos)
                  </label>
                  <input
                    type="number"
                    inputMode="numeric"
                    min={0}
                    max={600}
                    value={bloque.descanso_seg ?? ''}
                    onChange={(e) => {
                      const val = parseInt(e.target.value, 10);
                      onUpdateBlock({ descanso_seg: isNaN(val) ? 0 : val });
                    }}
                    className="w-full rounded-lg bg-surface-900 border border-zinc-700 px-3 py-2 text-base text-white focus:outline-none focus:border-cardio-primary"
                  />
                </div>
              </div>
            )}

            {/* TABATA */}
            {bloque.tipo === 'TABATA' && (
              <div className="space-y-3">
                <div className="grid grid-cols-3 gap-2">
                  <div>
                    <label className="block text-xs text-zinc-300 font-semibold mb-1">Rondas</label>
                    <input
                      type="number"
                      inputMode="numeric"
                      min={1}
                      max={99}
                      value={bloque.rondas ?? 8}
                      onChange={(e) => {
                        const val = parseInt(e.target.value, 10);
                        onUpdateBlock({ rondas: isNaN(val) ? 1 : val });
                      }}
                      className="w-full rounded-lg bg-surface-900 border border-zinc-700 px-2.5 py-2 text-base text-white focus:outline-none focus:border-cardio-primary"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-zinc-300 font-semibold mb-1">
                      Trabajo (s)
                    </label>
                    <input
                      type="number"
                      inputMode="numeric"
                      min={1}
                      max={600}
                      value={bloque.trabajo_seg ?? 20}
                      onChange={(e) => {
                        const val = parseInt(e.target.value, 10);
                        onUpdateBlock({ trabajo_seg: isNaN(val) ? 1 : val });
                      }}
                      className="w-full rounded-lg bg-surface-900 border border-zinc-700 px-2.5 py-2 text-base text-white focus:outline-none focus:border-cardio-primary"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-zinc-300 font-semibold mb-1">
                      Descanso (s)
                    </label>
                    <input
                      type="number"
                      inputMode="numeric"
                      min={1}
                      max={600}
                      value={bloque.descanso_tabata_seg ?? 10}
                      onChange={(e) => {
                        const val = parseInt(e.target.value, 10);
                        onUpdateBlock({ descanso_tabata_seg: isNaN(val) ? 1 : val });
                      }}
                      className="w-full rounded-lg bg-surface-900 border border-zinc-700 px-2.5 py-2 text-base text-white focus:outline-none focus:border-cardio-primary"
                    />
                  </div>
                </div>
                {bloque.estructura && (
                  <p className="text-[11px] text-zinc-400 bg-surface-900 px-3 py-1.5 rounded-lg border border-zinc-800">
                    <strong className="text-zinc-300">Estructura:</strong> {bloque.estructura}
                  </p>
                )}
              </div>
            )}

            {/* FINISHER */}
            {bloque.tipo === 'FINISHER' && (
              <div>
                <label className="block text-xs text-zinc-300 font-semibold mb-1">Rondas</label>
                <input
                  type="number"
                  inputMode="numeric"
                  min={1}
                  max={99}
                  value={bloque.rondas ?? 3}
                  onChange={(e) => {
                    const val = parseInt(e.target.value, 10);
                    onUpdateBlock({ rondas: isNaN(val) ? 1 : val });
                  }}
                  className="w-full rounded-lg bg-surface-900 border border-zinc-700 px-3 py-2 text-base text-white focus:outline-none focus:border-cardio-primary"
                />
              </div>
            )}

            {/* HIIT_INTERVALS */}
            {bloque.tipo === 'HIIT_INTERVALS' && (
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                <div>
                  <label className="block text-xs text-zinc-300 font-semibold mb-1">Rondas</label>
                  <input
                    type="number"
                    inputMode="numeric"
                    min={1}
                    max={99}
                    value={bloque.rondas ?? 4}
                    onChange={(e) => {
                      const val = parseInt(e.target.value, 10);
                      onUpdateBlock({ rondas: isNaN(val) ? 1 : val });
                    }}
                    className="w-full rounded-lg bg-surface-900 border border-zinc-700 px-2.5 py-2 text-base text-white focus:outline-none focus:border-cardio-primary"
                  />
                </div>
                <div>
                  <label className="block text-xs text-zinc-300 font-semibold mb-1">
                    Trabajo (s) (opc)
                  </label>
                  <input
                    type="number"
                    inputMode="numeric"
                    min={1}
                    max={600}
                    value={bloque.trabajo_seg ?? ''}
                    placeholder="Ej: 40"
                    onChange={(e) => {
                      const val = parseInt(e.target.value, 10);
                      onUpdateBlock({ trabajo_seg: isNaN(val) ? undefined : val });
                    }}
                    className="w-full rounded-lg bg-surface-900 border border-zinc-700 px-2.5 py-2 text-base text-white focus:outline-none focus:border-cardio-primary"
                  />
                </div>
                <div>
                  <label className="block text-xs text-zinc-300 font-semibold mb-1">
                    Duración (min) (opc)
                  </label>
                  <input
                    type="number"
                    inputMode="numeric"
                    min={1}
                    max={120}
                    value={bloque.duracion_minutos ?? ''}
                    placeholder="Ej: 12"
                    onChange={(e) => {
                      const val = parseInt(e.target.value, 10);
                      onUpdateBlock({ duracion_minutos: isNaN(val) ? undefined : val });
                    }}
                    className="w-full rounded-lg bg-surface-900 border border-zinc-700 px-2.5 py-2 text-base text-white focus:outline-none focus:border-cardio-primary"
                  />
                </div>
              </div>
            )}
          </div>

          {/* Ejercicios */}
          <ExerciseEditor
            ejercicios={bloque.ejercicios}
            tipoBloque={bloque.tipo}
            onAddExercise={onAddExercise}
            onUpdateExercise={onUpdateExercise}
            onRemoveExercise={onRemoveExercise}
            onMoveExercise={onMoveExercise}
          />
        </div>
      )}
    </div>
  );
};
