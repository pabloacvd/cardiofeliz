import React, { useState } from 'react';
import { BottomSheet } from './BottomSheet';
import { parseWeight } from '../utils/activityForm';

interface WeightSheetProps {
  initialKg: number | null;
  /** Texto del botón secundario; si no se pasa, no se ofrece omitir. */
  skipLabel?: string;
  onSave: (kg: number) => void;
  onSkip?: () => void;
  onClose: () => void;
}

export const WeightSheet: React.FC<WeightSheetProps> = ({ initialKg, skipLabel, onSave, onSkip, onClose }) => {
  const [text, setText] = useState(initialKg !== null ? String(initialKg).replace('.', ',') : '');
  const [error, setError] = useState<string | null>(null);

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    const kg = parseWeight(text);
    if (kg === null) {
      setError('Ingresá un peso entre 20 y 300 kg.');
      return;
    }
    onSave(kg);
  };

  return (
    <BottomSheet title="Tu peso" onClose={onClose}>
      <form onSubmit={submit} className="space-y-4" noValidate>
        <p className="text-xs text-zinc-400 leading-relaxed">
          Lo usamos solo para estimar las calorías de tus entrenamientos y corridas. Es una estimación y la pedimos una sola vez; podés cambiarla cuando quieras.
        </p>

        <div>
          <label htmlFor="weight-kg" className="block text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-1.5">
            Peso (kg)
          </label>
          <input
            id="weight-kg"
            type="text"
            inputMode="decimal"
            autoComplete="off"
            value={text}
            onChange={(e) => {
              setText(e.target.value);
              setError(null);
            }}
            aria-invalid={error !== null}
            aria-describedby={error ? 'weight-kg-error' : undefined}
            placeholder="Ej: 62,5"
            className="w-full rounded-xl bg-black border border-zinc-700 px-4 py-3 text-base text-white focus:outline-none focus:border-cardio-primary"
          />
          {error && (
            <p id="weight-kg-error" role="alert" className="mt-1.5 text-xs text-red-400">
              {error}
            </p>
          )}
        </div>

        <button
          type="submit"
          className="w-full py-3.5 rounded-2xl bg-gradient-to-r from-cardio-primary to-emerald-400 text-black font-extrabold text-sm active:scale-[0.98] transition-transform"
        >
          Guardar peso
        </button>
        {onSkip && skipLabel && (
          <button
            type="button"
            onClick={onSkip}
            className="w-full py-3 rounded-2xl bg-surface-800 border border-zinc-700 text-zinc-300 font-bold text-xs active:bg-surface-700"
          >
            {skipLabel}
          </button>
        )}
      </form>
    </BottomSheet>
  );
};
