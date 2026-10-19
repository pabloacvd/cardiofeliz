import React, { useMemo, useState } from 'react';
import type { RutinaData } from '../types/workout';
import type { RoutineSyncStatus } from '../hooks/useRoutine';
import { validateRutina } from '../utils/routine';
import { isDefaultRoutine } from '../utils/routineImport';
import { getDefaultRoutine } from '../utils/routineSync';
import {
  cloneRutina,
  hasRoutineChanges,
  updateRoutineMeta,
  addDay,
  updateDay,
  removeDay,
  moveDay,
  addBlock,
  updateBlock,
  changeBlockType,
  duplicateBlock,
  removeBlock,
  moveBlock,
  addExercise,
  updateExercise,
  removeExercise,
  moveExercise,
} from '../utils/routineEdit';
import { RoutineMetaEditor } from '../components/routine-editor/RoutineMetaEditor';
import { DayEditor } from '../components/routine-editor/DayEditor';
import { RoutineBackupSection } from '../components/routine-editor/RoutineBackupSection';
import {
  ArrowLeft,
  Save,
  AlertCircle,
  Plus,
  Dumbbell,
  CheckCircle2,
  CloudUpload,
  CloudCheck,
  CloudOff,
  Info,
} from 'lucide-react';

interface RoutineEditorViewProps {
  rutina: RutinaData;
  onSave: (rutina: RutinaData) => Promise<void>;
  /** Borra la rutina personalizada y vuelve a la original. */
  onReset: () => Promise<void>;
  /** true si el usuario tiene una rutina personalizada guardada. */
  isCustom: boolean;
  onBack: () => void;
  syncStatus: RoutineSyncStatus;
  hasActiveBlockProgressToday?: boolean;
}

export const RoutineEditorView: React.FC<RoutineEditorViewProps> = ({
  rutina,
  onSave,
  onReset,
  isCustom,
  onBack,
  syncStatus,
  hasActiveBlockProgressToday = false,
}) => {
  const [draft, setDraft] = useState<RutinaData>(() => cloneRutina(rutina));
  const [isSaving, setIsSaving] = useState(false);
  const [saveFeedback, setSaveFeedback] = useState<{
    type: 'success' | 'error';
    message: string;
  } | null>(null);

  const hasChanges = useMemo(() => hasRoutineChanges(draft, rutina), [draft, rutina]);
  const validation = useMemo(() => validateRutina(draft), [draft]);
  // Si el borrador ya es la rutina original no hay nada que restaurar.
  const draftIsDefault = useMemo(() => validation.valid && isDefaultRoutine(draft), [draft, validation.valid]);

  const handleBack = () => {
    if (hasChanges) {
      const confirmDiscard = window.confirm(
        'Tenés cambios sin guardar. ¿Querés descartar los cambios y volver?',
      );
      if (!confirmDiscard) return;
    }
    onBack();
  };

  const handleSave = async () => {
    if (!validation.valid || isSaving) return;

    setIsSaving(true);
    setSaveFeedback(null);

    try {
      // Guardar exactamente la rutina original equivale a volver a no tener rutina personalizada:
      // se borra la fila remota en vez de guardar una copia.
      if (draftIsDefault && isCustom) {
        await onReset();
      } else {
        await onSave(draft);
      }
      setSaveFeedback({
        type: 'success',
        message: '¡Rutina guardada correctamente!',
      });
    } catch {
      setSaveFeedback({
        type: 'error',
        message: 'No se pudo guardar la rutina. Revisá los datos e intentá nuevamente.',
      });
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="space-y-4 animate-fadeIn pb-10">
      {/* Top Navigation */}
      <div className="flex items-center justify-between">
        <button
          type="button"
          onClick={handleBack}
          className="inline-flex items-center gap-1.5 text-xs font-bold text-zinc-400 hover:text-white active:scale-95 transition-all p-1 -ml-1"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Volver al Inicio</span>
        </button>

        {hasChanges && (
          <span className="text-[10px] font-extrabold uppercase tracking-wider px-2 py-0.5 rounded-full bg-amber-500/15 text-amber-400 border border-amber-500/30">
            Cambios sin guardar
          </span>
        )}
      </div>

      {/* Header */}
      <div className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-1">
        <div className="flex items-center gap-2">
          <div className="p-1.5 rounded-lg bg-cardio-primary/20 text-cardio-primary">
            <Dumbbell className="w-4 h-4" />
          </div>
          <span className="text-[11px] font-bold text-cardio-primary uppercase tracking-wider">
            Personalizar Plan
          </span>
        </div>
        <h2 className="text-xl font-extrabold text-white leading-tight">Mi Rutina</h2>
        <p className="text-xs text-zinc-400 leading-relaxed">
          Modificá los días de entrenamiento, bloques, tiempos y ejercicios a tu medida. Los
          cambios se aplicarán únicamente al tocar &ldquo;Guardar cambios&rdquo;.
        </p>
      </div>

      {/* Aviso de progreso de hoy si aplica */}
      {hasActiveBlockProgressToday && (
        <div className="p-3.5 rounded-2xl bg-surface-900 border border-zinc-800 flex items-start gap-2.5 text-xs text-zinc-300">
          <Info className="w-4 h-4 text-cardio-primary shrink-0 mt-0.5" />
          <p className="leading-snug">
            Ya completaste bloques hoy. Tu progreso diario se conserva por identificador de
            bloque al guardar.
          </p>
        </div>
      )}

      {/* Save Feedback Banner */}
      {saveFeedback && (
        <div
          role="status"
          className={`p-3.5 rounded-2xl border flex items-center gap-2.5 text-xs font-semibold ${
            saveFeedback.type === 'success'
              ? 'bg-emerald-950/40 border-emerald-500/40 text-emerald-300'
              : 'bg-red-950/40 border-red-500/40 text-red-300'
          }`}
        >
          {saveFeedback.type === 'success' ? (
            <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
          ) : (
            <AlertCircle className="w-4 h-4 text-red-400 shrink-0" />
          )}
          <div className="flex-1">
            <p>{saveFeedback.message}</p>
            {saveFeedback.type === 'success' && syncStatus === 'pending' && (
              <p className="text-[11px] text-amber-400/90 mt-0.5 font-normal">
                Guardado en este dispositivo. Pendiente de sincronizar con la nube al conectar.
              </p>
            )}
          </div>
        </div>
      )}

      {/* Validation Errors Box */}
      {!validation.valid && (
        <div
          role="alert"
          className="p-3.5 rounded-2xl bg-red-950/30 border border-red-500/40 space-y-2 text-xs text-red-300"
        >
          <div className="flex items-center gap-1.5 font-bold text-red-400">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span>Por favor corregí los siguientes errores para guardar:</span>
          </div>
          <ul className="list-disc list-inside space-y-1 pl-1 text-[11px] text-red-200">
            {validation.errors.map((err, idx) => (
              <li key={idx}>{err}</li>
            ))}
          </ul>
        </div>
      )}

      {/* Meta Editor (Objetivo & Edad) */}
      <RoutineMetaEditor
        usuario={draft.usuario}
        edad={draft.edad}
        objetivo={draft.objetivo}
        onUpdateEdad={(edad) => setDraft((curr) => updateRoutineMeta(curr, { edad }))}
        onUpdateObjetivo={(objetivo) =>
          setDraft((curr) => updateRoutineMeta(curr, { objetivo }))
        }
      />

      {/* Days List Section */}
      <div className="space-y-3">
        <div className="flex items-center justify-between px-1">
          <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-400">
            Días de Entrenamiento ({draft.dias_entrenamiento.length}/10)
          </h3>
        </div>

        {draft.dias_entrenamiento.map((dia, dIdx) => (
          <DayEditor
            key={dia.id}
            dia={dia}
            index={dIdx}
            totalDays={draft.dias_entrenamiento.length}
            onUpdateDay={(patch) => setDraft((curr) => updateDay(curr, dia.id, patch))}
            onRemoveDay={() => setDraft((curr) => removeDay(curr, dia.id))}
            onMoveDay={(fIdx, tIdx) => setDraft((curr) => moveDay(curr, fIdx, tIdx))}
            onAddBlock={(tipo) => setDraft((curr) => addBlock(curr, dia.id, tipo))}
            onChangeBlockType={(bloqueId, newTipo) =>
              setDraft((curr) => changeBlockType(curr, dia.id, bloqueId, newTipo))
            }
            onUpdateBlock={(bloqueId, patch) =>
              setDraft((curr) => updateBlock(curr, dia.id, bloqueId, patch))
            }
            onDuplicateBlock={(bloqueId) =>
              setDraft((curr) => duplicateBlock(curr, dia.id, bloqueId))
            }
            onRemoveBlock={(bloqueId) =>
              setDraft((curr) => removeBlock(curr, dia.id, bloqueId))
            }
            onMoveBlock={(fIdx, tIdx) =>
              setDraft((curr) => moveBlock(curr, dia.id, fIdx, tIdx))
            }
            onAddExercise={(bloqueId) =>
              setDraft((curr) => addExercise(curr, dia.id, bloqueId, ''))
            }
            onUpdateExercise={(bloqueId, eIdx, patch) =>
              setDraft((curr) => updateExercise(curr, dia.id, bloqueId, eIdx, patch))
            }
            onRemoveExercise={(bloqueId, eIdx) =>
              setDraft((curr) => removeExercise(curr, dia.id, bloqueId, eIdx))
            }
            onMoveExercise={(bloqueId, fIdx, tIdx) =>
              setDraft((curr) => moveExercise(curr, dia.id, bloqueId, fIdx, tIdx))
            }
          />
        ))}

        {draft.dias_entrenamiento.length < 10 && (
          <button
            type="button"
            onClick={() => setDraft((curr) => addDay(curr))}
            className="w-full py-3.5 px-4 rounded-2xl bg-surface-900 border border-dashed border-zinc-700 hover:border-zinc-500 active:scale-[0.98] text-zinc-300 font-extrabold text-sm flex items-center justify-center gap-2 transition-all shadow-md"
          >
            <Plus className="w-4 h-4 text-cardio-primary" />
            <span>Agregar Día de Entrenamiento</span>
          </button>
        )}
      </div>

      {/* Backup and Restore placeholder for Sub-tarea 6 */}
      <RoutineBackupSection
        draft={draft}
        usuario={draft.usuario}
        onImport={(imported) => setDraft(imported)}
        onRestoreDefault={() => setDraft(getDefaultRoutine(draft.usuario))}
        canRestore={!draftIsDefault}
      />

      {/* Sticky Bottom Actions */}
      <div className="pt-4 space-y-2">
        <button
          type="button"
          disabled={!validation.valid || isSaving || !hasChanges}
          onClick={handleSave}
          className="w-full py-4 px-5 rounded-2xl bg-gradient-to-r from-cardio-primary to-emerald-400 text-black font-extrabold text-base flex items-center justify-center gap-2.5 shadow-xl shadow-emerald-500/25 active:scale-[0.98] disabled:opacity-40 disabled:pointer-events-none transition-all"
        >
          <Save className="w-5 h-5 fill-black" />
          <span>{isSaving ? 'Guardando...' : 'Guardar Cambios'}</span>
        </button>

        <button
          type="button"
          onClick={handleBack}
          className="w-full py-3 rounded-2xl bg-surface-800 border border-zinc-700 text-zinc-300 font-bold text-xs active:bg-surface-700 transition-colors"
        >
          {hasChanges ? 'Cancelar y descartar cambios' : 'Volver a Home'}
        </button>

        {/* Sync state footnote */}
        <div className="flex items-center justify-center gap-1.5 text-[11px] text-zinc-500 pt-1">
          {syncStatus === 'synced' && (
            <>
              <CloudCheck className="w-3.5 h-3.5 text-zinc-500" />
              <span>Sincronizado con la nube</span>
            </>
          )}
          {syncStatus === 'syncing' && (
            <>
              <CloudUpload className="w-3.5 h-3.5 text-cyan-400 animate-pulse" />
              <span className="text-cyan-400">Sincronizando...</span>
            </>
          )}
          {syncStatus === 'pending' && (
            <>
              <CloudUpload className="w-3.5 h-3.5 text-amber-400" />
              <span className="text-amber-400">Cambios guardados localmente</span>
            </>
          )}
          {syncStatus === 'error' && (
            <>
              <CloudOff className="w-3.5 h-3.5 text-amber-400" />
              <span className="text-amber-400">Modo local (sin conexión)</span>
            </>
          )}
        </div>
      </div>
    </div>
  );
};
