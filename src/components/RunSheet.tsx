import React, { useState } from 'react';
import { BottomSheet } from './BottomSheet';
import { addDays } from '../gamification';
import type { DateKey } from '../gamification/dates';
import {
  MAX_BACKDATE_DAYS,
  validateRunForm,
  type RunFields,
  type RunFormErrors,
  type RunFormValues,
} from '../utils/activityForm';
import type { DiaEntrenamiento } from '../types/workout';

interface RunSheetProps {
  title: string;
  submitLabel?: string;
  today: DateKey;
  initial: RunFormValues;
  workoutDays?: readonly DiaEntrenamiento[];
  onSubmit: (fields: RunFields) => void;
  onClose: () => void;
}

const FEELINGS: { value: number; emoji: string; label: string }[] = [
  { value: 1, emoji: '😣', label: 'Muy pesado' },
  { value: 2, emoji: '😕', label: 'Pesado' },
  { value: 3, emoji: '😐', label: 'Normal' },
  { value: 4, emoji: '🙂', label: 'Bien' },
  { value: 5, emoji: '🤩', label: 'Excelente' },
];

const INPUT_CLASS =
  'w-full rounded-xl bg-black border border-zinc-700 px-4 py-3 text-base text-white focus:outline-none focus:border-cardio-primary';
const LABEL_CLASS = 'block text-[11px] font-bold uppercase tracking-wider text-zinc-400 mb-1.5';

function chipClass(selected: boolean): string {
  return `flex-1 py-2.5 rounded-xl border text-xs font-bold transition-colors ${
    selected
      ? 'bg-cardio-primary/20 border-cardio-primary text-cardio-primary'
      : 'bg-black border-zinc-700 text-zinc-300 active:bg-surface-800'
  }`;
}

export const RunSheet: React.FC<RunSheetProps> = ({
  title,
  submitLabel,
  today,
  initial,
  workoutDays = [],
  onSubmit,
  onClose,
}) => {
  const [values, setValues] = useState<RunFormValues>(initial);
  const [errors, setErrors] = useState<RunFormErrors>({});

  const update = (patch: Partial<RunFormValues>) => {
    setValues((v) => ({ ...v, ...patch }));
    setErrors({});
  };

  const isWorkoutDay = values.exerciseType === 'workout_day';

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    const result = validateRunForm(values, today);
    if (!result.ok) {
      setErrors(result.errors);
      return;
    }
    onSubmit(result.fields);
  };

  const buttonText =
    submitLabel ?? (isWorkoutDay ? 'Guardar entrenamiento' : 'Guardar corrida');

  return (
    <BottomSheet title={title} onClose={onClose}>
      <form onSubmit={submit} className="space-y-4" noValidate>
        {!isWorkoutDay ? (
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label htmlFor="run-minutes" className={LABEL_CLASS}>
                Minutos
              </label>
              <input
                id="run-minutes"
                type="text"
                inputMode="numeric"
                autoComplete="off"
                value={values.minutes}
                onChange={(e) => update({ minutes: e.target.value })}
                aria-invalid={errors.minutes !== undefined}
                aria-describedby={errors.minutes ? 'run-minutes-error' : undefined}
                className={INPUT_CLASS}
              />
            </div>
            <div>
              <label htmlFor="run-km" className={LABEL_CLASS}>
                Km (opcional)
              </label>
              <input
                id="run-km"
                type="text"
                inputMode="decimal"
                autoComplete="off"
                value={values.km}
                onChange={(e) => update({ km: e.target.value })}
                aria-invalid={errors.km !== undefined}
                aria-describedby={errors.km ? 'run-km-error' : undefined}
                placeholder="Ej: 4,5"
                className={INPUT_CLASS}
              />
            </div>
          </div>
        ) : (
          <div>
            <label htmlFor="run-minutes" className={LABEL_CLASS}>
              Minutos
            </label>
            <input
              id="run-minutes"
              type="text"
              inputMode="numeric"
              autoComplete="off"
              value={values.minutes}
              onChange={(e) => update({ minutes: e.target.value })}
              aria-invalid={errors.minutes !== undefined}
              aria-describedby={errors.minutes ? 'run-minutes-error' : undefined}
              className={INPUT_CLASS}
            />
          </div>
        )}
        {errors.minutes && (
          <p id="run-minutes-error" role="alert" className="text-xs text-red-400">
            {errors.minutes}
          </p>
        )}
        {errors.km && !isWorkoutDay && (
          <p id="run-km-error" role="alert" className="text-xs text-red-400">
            {errors.km}
          </p>
        )}

        <fieldset>
          <legend className={LABEL_CLASS}>Tipo de ejercicio</legend>
          <div className="flex gap-2">
            <button
              type="button"
              aria-pressed={!isWorkoutDay}
              onClick={() => update({ exerciseType: 'run' })}
              className={chipClass(!isWorkoutDay)}
            >
              Corrida
            </button>
            <button
              type="button"
              aria-pressed={isWorkoutDay}
              onClick={() =>
                update({
                  exerciseType: 'workout_day',
                  dayId: values.dayId ?? workoutDays[0]?.id ?? null,
                })
              }
              className={chipClass(isWorkoutDay)}
            >
              Día de entrenamiento
            </button>
          </div>

          {isWorkoutDay && workoutDays.length > 0 && (
            <div className="space-y-1.5 mt-2.5">
              {workoutDays.map((dia) => {
                const isSelected = values.dayId === dia.id;
                return (
                  <button
                    key={dia.id}
                    type="button"
                    aria-pressed={isSelected}
                    onClick={() => update({ dayId: dia.id })}
                    className={`w-full text-left px-3.5 py-2.5 rounded-xl border text-xs font-bold transition-colors flex items-center justify-between gap-2 ${
                      isSelected
                        ? 'bg-cardio-primary/20 border-cardio-primary text-cardio-primary'
                        : 'bg-black border-zinc-700 text-zinc-300 hover:border-zinc-500 active:bg-surface-800'
                    }`}
                  >
                    <span className="truncate">{dia.nombre}</span>
                    {isSelected && (
                      <span className="text-cardio-primary text-sm flex-shrink-0" aria-hidden="true">
                        ✓
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          )}
          {errors.dayId && isWorkoutDay && (
            <p id="run-dayId-error" role="alert" className="text-xs text-red-400 mt-1.5">
              {errors.dayId}
            </p>
          )}
        </fieldset>

        <fieldset>
          <legend className={LABEL_CLASS}>Cómo te sentiste (opcional)</legend>
          <div className="flex gap-1.5">
            {FEELINGS.map((f) => (
              <button
                key={f.value}
                type="button"
                aria-pressed={values.feeling === f.value}
                aria-label={`${f.value} de 5: ${f.label}`}
                onClick={() => update({ feeling: values.feeling === f.value ? null : f.value })}
                className={`${chipClass(values.feeling === f.value)} text-lg`}
              >
                <span aria-hidden="true">{f.emoji}</span>
              </button>
            ))}
          </div>
        </fieldset>

        <div>
          <label htmlFor="run-date" className={LABEL_CLASS}>
            Fecha
          </label>
          <input
            id="run-date"
            type="date"
            value={values.date}
            min={addDays(today, -MAX_BACKDATE_DAYS)}
            max={today}
            onChange={(e) => update({ date: e.target.value })}
            aria-invalid={errors.date !== undefined}
            aria-describedby={errors.date ? 'run-date-error' : undefined}
            className={INPUT_CLASS}
          />
          {errors.date && (
            <p id="run-date-error" role="alert" className="mt-1.5 text-xs text-red-400">
              {errors.date}
            </p>
          )}
        </div>

        <button
          type="submit"
          className="w-full py-3.5 rounded-2xl bg-gradient-to-r from-cardio-primary to-emerald-400 text-black font-extrabold text-sm active:scale-[0.98] transition-transform"
        >
          {buttonText}
        </button>
      </form>
    </BottomSheet>
  );
};
