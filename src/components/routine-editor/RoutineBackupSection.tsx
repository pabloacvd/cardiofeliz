import React, { useRef, useState } from 'react';
import { Download, Upload, RotateCcw, Copy, ClipboardPaste, AlertCircle, CheckCircle2 } from 'lucide-react';
import type { RutinaData } from '../../types/workout';
import {
  MAX_IMPORT_SIZE_BYTES,
  parseImportedRoutine,
  serializeRoutine,
} from '../../utils/routineImport';

const MAX_ERRORS_SHOWN = 10;

interface RoutineBackupSectionProps {
  /** Borrador actual: es lo que se exporta. */
  draft: RutinaData;
  /** Nombre de la sesión: siempre se fuerza sobre lo importado. */
  usuario: string;
  /** Reemplaza el borrador con la rutina importada (sin guardar). */
  onImport: (rutina: RutinaData) => void;
  /** Reemplaza el borrador con la rutina original (sin guardar). */
  onRestoreDefault: () => void;
  /** false si el borrador ya es la rutina original. */
  canRestore: boolean;
}

type Feedback = { type: 'success' | 'error'; messages: string[] } | null;

export const RoutineBackupSection: React.FC<RoutineBackupSectionProps> = ({
  draft,
  usuario,
  onImport,
  onRestoreDefault,
  canRestore,
}) => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [isPasteOpen, setIsPasteOpen] = useState(false);
  const [pastedText, setPastedText] = useState('');
  const [feedback, setFeedback] = useState<Feedback>(null);

  const showError = (errors: string[]) => {
    const shown = errors.slice(0, MAX_ERRORS_SHOWN);
    const extra = errors.length - shown.length;
    setFeedback({
      type: 'error',
      messages: extra > 0 ? [...shown, `…y ${extra} error${extra === 1 ? '' : 'es'} más.`] : shown,
    });
  };

  const showSuccess = (message: string) => setFeedback({ type: 'success', messages: [message] });

  const handleExport = () => {
    try {
      const blob = new Blob([serializeRoutine(draft)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'rutina-cardiofeliz.json';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
      showSuccess('Archivo exportado.');
    } catch {
      showError(['No se pudo exportar la rutina en este dispositivo.']);
    }
  };

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(serializeRoutine(draft));
      showSuccess('Rutina copiada al portapapeles.');
    } catch {
      showError(['No se pudo copiar. Probá con Exportar.']);
    }
  };

  const applyImport = (text: string): boolean => {
    const result = parseImportedRoutine(text, usuario);
    if (!result.ok) {
      showError(result.errors);
      return false;
    }
    if (
      !window.confirm(
        '¿Reemplazar el borrador actual con la rutina importada? Después tenés que tocar "Guardar Cambios" para aplicarla.',
      )
    ) {
      return false;
    }
    onImport(result.rutina);
    showSuccess('Rutina importada como borrador. Revisala y tocá "Guardar Cambios".');
    return true;
  };

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    // Se limpia para poder elegir de nuevo el mismo archivo.
    e.target.value = '';
    if (!file) return;

    // El tamaño se verifica antes de leer el contenido.
    if (file.size > MAX_IMPORT_SIZE_BYTES) {
      showError(['El archivo supera el tamaño máximo permitido (500 KB).']);
      return;
    }

    let text: string;
    try {
      text = await file.text();
    } catch {
      showError(['No se pudo leer el archivo.']);
      return;
    }
    applyImport(text);
  };

  const handleImportPasted = () => {
    if (applyImport(pastedText)) {
      setPastedText('');
      setIsPasteOpen(false);
    }
  };

  const handleRestore = () => {
    if (
      !window.confirm(
        '¿Restaurar la rutina original? Se reemplazará el borrador actual. Después tenés que tocar "Guardar Cambios" para aplicarla.',
      )
    ) {
      return;
    }
    onRestoreDefault();
    showSuccess('Rutina original cargada como borrador. Tocá "Guardar Cambios" para aplicarla.');
  };

  const buttonClass =
    'p-2.5 rounded-xl bg-surface-800 border border-zinc-700 text-zinc-200 font-semibold text-xs flex flex-col items-center justify-center gap-1 active:bg-surface-700 transition-colors disabled:opacity-40 disabled:pointer-events-none';

  return (
    <div className="rounded-2xl border border-zinc-800/80 bg-surface-900/60 p-4 space-y-3">
      <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-400">
        Copia de seguridad y restauración
      </h3>

      <p className="text-xs text-zinc-400 leading-relaxed">
        Exportá tu rutina como respaldo, importá una desde un archivo o texto, o volvé a la rutina
        original. Lo importado se carga como borrador: no cambia nada hasta que guardes.
      </p>

      <div className="grid grid-cols-3 gap-2 pt-1">
        <button type="button" onClick={handleExport} aria-label="Exportar rutina a archivo JSON" className={buttonClass}>
          <Download className="w-4 h-4" />
          <span>Exportar</span>
        </button>

        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          aria-label="Importar rutina desde un archivo JSON"
          className={buttonClass}
        >
          <Upload className="w-4 h-4" />
          <span>Importar</span>
        </button>

        <button
          type="button"
          onClick={handleRestore}
          disabled={!canRestore}
          aria-label="Restaurar rutina original"
          className={buttonClass}
        >
          <RotateCcw className="w-4 h-4" />
          <span>Restaurar</span>
        </button>
      </div>

      <div className="grid grid-cols-2 gap-2">
        <button type="button" onClick={handleCopy} aria-label="Copiar rutina al portapapeles" className={buttonClass}>
          <Copy className="w-4 h-4" />
          <span>Copiar JSON</span>
        </button>
        <button
          type="button"
          onClick={() => setIsPasteOpen((open) => !open)}
          aria-expanded={isPasteOpen}
          aria-label="Pegar rutina como texto JSON"
          className={buttonClass}
        >
          <ClipboardPaste className="w-4 h-4" />
          <span>Pegar JSON</span>
        </button>
      </div>

      <input
        ref={fileInputRef}
        type="file"
        accept="application/json,.json"
        onChange={handleFileChange}
        className="hidden"
        aria-hidden="true"
        tabIndex={-1}
      />

      {isPasteOpen && (
        <div className="space-y-2">
          <label htmlFor="routine-paste" className="block text-[11px] font-bold uppercase tracking-wider text-zinc-400">
            Pegá acá el JSON de la rutina
          </label>
          <textarea
            id="routine-paste"
            rows={6}
            maxLength={MAX_IMPORT_SIZE_BYTES}
            value={pastedText}
            onChange={(e) => setPastedText(e.target.value)}
            spellCheck={false}
            className="w-full rounded-xl bg-black border border-zinc-700 px-3.5 py-2.5 text-base font-mono text-white focus:outline-none focus:border-cardio-primary resize-y"
          />
          <button
            type="button"
            onClick={handleImportPasted}
            disabled={pastedText.trim().length === 0}
            className="w-full py-3 rounded-xl bg-cardio-primary text-black font-extrabold text-sm active:scale-[0.98] disabled:opacity-40 disabled:pointer-events-none transition-all"
          >
            Cargar como borrador
          </button>
        </div>
      )}

      {feedback && (
        <div
          role={feedback.type === 'error' ? 'alert' : 'status'}
          className={`p-3 rounded-xl border text-xs flex items-start gap-2 ${
            feedback.type === 'success'
              ? 'bg-emerald-950/40 border-emerald-500/40 text-emerald-300'
              : 'bg-red-950/40 border-red-500/40 text-red-300'
          }`}
        >
          {feedback.type === 'success' ? (
            <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
          ) : (
            <AlertCircle className="w-4 h-4 text-red-400 shrink-0 mt-0.5" />
          )}
          <ul className="space-y-1 flex-1">
            {feedback.messages.map((m, i) => (
              <li key={i}>{m}</li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
};
