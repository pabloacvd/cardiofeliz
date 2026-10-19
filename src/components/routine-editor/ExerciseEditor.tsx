import React, { useState } from 'react';
import type { Ejercicio, EjercicioEMOM, EjercicioGenerico, TipoBloque } from '../../types/workout';
import { ArrowUp, ArrowDown, Trash2, Plus, Clock } from 'lucide-react';

interface ExerciseEditorProps {
  ejercicios: Ejercicio[];
  tipoBloque: TipoBloque;
  onAddExercise: () => void;
  onUpdateExercise: (index: number, patch: { detalle?: string; segundos?: number | null }) => void;
  onRemoveExercise: (index: number) => void;
  onMoveExercise: (fromIndex: number, toIndex: number) => void;
}

export const ExerciseEditor: React.FC<ExerciseEditorProps> = ({
  ejercicios,
  tipoBloque,
  onAddExercise,
  onUpdateExercise,
  onRemoveExercise,
  onMoveExercise,
}) => {
  const [deleteConfirmIndex, setDeleteConfirmIndex] = useState<number | null>(null);
  const isEmom = tipoBloque === 'EMOM';
  const allowsSeconds = tipoBloque === 'FINISHER' || tipoBloque === 'HIIT_INTERVALS';

  const handleDelete = (index: number) => {
    if (deleteConfirmIndex === index) {
      onRemoveExercise(index);
      setDeleteConfirmIndex(null);
    } else {
      setDeleteConfirmIndex(index);
    }
  };

  return (
    <div className="space-y-2.5">
      <div className="flex items-center justify-between">
        <label className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
          Ejercicios / Pasos ({ejercicios.length}/20)
        </label>
        {isEmom && (
          <span className="text-[10px] text-emerald-400 font-semibold">
            Minuto asignado automáticamente
          </span>
        )}
      </div>

      {ejercicios.length === 0 ? (
        <div className="p-3 rounded-xl bg-black/40 border border-dashed border-zinc-800 text-center text-xs text-zinc-500">
          Sin ejercicios todavía. Añadí al menos uno.
        </div>
      ) : (
        <div className="space-y-2">
          {ejercicios.map((ej, idx) => {
            const emomEj = ej as EjercicioEMOM;
            const genericoEj = ej as EjercicioGenerico;
            const isDeleting = deleteConfirmIndex === idx;

            return (
              <div
                key={idx}
                className="p-2.5 rounded-xl bg-black/70 border border-zinc-800 space-y-2 transition-all"
              >
                <div className="flex items-center gap-2">
                  {/* Badge */}
                  <div className="w-7 h-7 rounded-lg bg-surface-800 border border-zinc-700/80 flex items-center justify-center shrink-0 text-[11px] font-mono font-bold text-zinc-300">
                    {isEmom ? `M${emomEj.minuto ?? idx + 1}` : idx + 1}
                  </div>

                  {/* Detalle Input */}
                  <input
                    type="text"
                    maxLength={300}
                    value={ej.detalle}
                    onChange={(e) => onUpdateExercise(idx, { detalle: e.target.value })}
                    placeholder="Detalle del ejercicio o pausa..."
                    className="flex-1 min-w-0 rounded-lg bg-surface-900 border border-zinc-700/80 px-3 py-2 text-base text-white placeholder:text-zinc-600 focus:outline-none focus:border-cardio-primary"
                  />

                  {/* Actions */}
                  <div className="flex items-center gap-1 shrink-0">
                    <button
                      type="button"
                      disabled={idx === 0}
                      onClick={() => onMoveExercise(idx, idx - 1)}
                      aria-label="Subir ejercicio"
                      className="p-1.5 rounded-lg bg-surface-800 border border-zinc-700/60 text-zinc-400 disabled:opacity-30 disabled:pointer-events-none hover:text-white active:bg-surface-700"
                    >
                      <ArrowUp className="w-3.5 h-3.5" />
                    </button>
                    <button
                      type="button"
                      disabled={idx === ejercicios.length - 1}
                      onClick={() => onMoveExercise(idx, idx + 1)}
                      aria-label="Bajar ejercicio"
                      className="p-1.5 rounded-lg bg-surface-800 border border-zinc-700/60 text-zinc-400 disabled:opacity-30 disabled:pointer-events-none hover:text-white active:bg-surface-700"
                    >
                      <ArrowDown className="w-3.5 h-3.5" />
                    </button>
                    <button
                      type="button"
                      onClick={() => handleDelete(idx)}
                      aria-label={isDeleting ? 'Confirmar eliminar ejercicio' : 'Eliminar ejercicio'}
                      className={`p-1.5 rounded-lg border transition-all text-xs font-bold ${
                        isDeleting
                          ? 'bg-red-500/20 border-red-500 text-red-400 px-2'
                          : 'bg-surface-800 border-zinc-700/60 text-zinc-400 hover:text-red-400 active:bg-surface-700'
                      }`}
                    >
                      {isDeleting ? '¿Borrar?' : <Trash2 className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                </div>

                {/* Segundos opcionales para Finisher/HIIT */}
                {allowsSeconds && (
                  <div className="flex items-center gap-2 pl-9">
                    <Clock className="w-3.5 h-3.5 text-zinc-500 shrink-0" />
                    <span className="text-[11px] text-zinc-400 font-medium">Segundos:</span>
                    <input
                      type="number"
                      inputMode="numeric"
                      min={1}
                      max={600}
                      value={genericoEj.segundos ?? ''}
                      placeholder="Manual"
                      onChange={(e) => {
                        const val = parseInt(e.target.value, 10);
                        onUpdateExercise(idx, {
                          segundos: isNaN(val) ? null : val,
                        });
                      }}
                      className="w-24 rounded-md bg-surface-900 border border-zinc-700/80 px-2.5 py-1 text-sm text-white placeholder:text-zinc-600 focus:outline-none focus:border-cardio-primary"
                    />
                    <span className="text-[10px] text-zinc-500">
                      (Vacío = botón &ldquo;Listo&rdquo; manual)
                    </span>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {ejercicios.length < 20 && (
        <button
          type="button"
          onClick={onAddExercise}
          className="w-full py-2.5 px-3 rounded-xl bg-surface-800/80 border border-dashed border-zinc-700 hover:border-zinc-500 text-zinc-300 font-bold text-xs flex items-center justify-center gap-1.5 active:bg-surface-700 transition-colors"
        >
          <Plus className="w-3.5 h-3.5 text-cardio-primary" />
          <span>Agregar Ejercicio</span>
        </button>
      )}
    </div>
  );
};
