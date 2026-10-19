import React, { useCallback, useEffect, useRef, useState } from 'react';
import confetti from 'canvas-confetti';
import { Footprints, Flame, Zap, Undo2, SlidersHorizontal, Scale, Trophy, Leaf } from 'lucide-react';
import type { Activity } from '../types/gamification';
import { GAME_CONFIG, logOutcome, withActivity, type GameContext, type LogOutcome } from '../gamification';
import { weekProgress } from '../gamification/weeks';
import type { DateKey } from '../gamification/dates';
import { defaultRunForm, runFormFromActivity, type RunFields } from '../utils/activityForm';
import type { ActivityDraft } from '../utils/workoutDay';
import type { AddActivityOptions } from '../hooks/useActivities';
import { RunSheet } from './RunSheet';
import { WeightSheet } from './WeightSheet';

const RESULT_VISIBLE_MS = 12_000;

interface QuickLogCardProps {
  today: DateKey;
  activities: readonly Activity[];
  weightKg: number | null;
  weightLoaded: boolean;
  weightPromptDismissed: boolean;
  onDismissWeightPrompt: () => void;
  onSetWeight: (kg: number) => boolean;
  addActivity: (draft: ActivityDraft, options?: AddActivityOptions) => Activity;
  updateActivity: (id: string, patch: Partial<ActivityDraft>, options?: AddActivityOptions) => Activity | null;
  removeActivity: (id: string) => void;
  fillMissingCalories: (weightKg: number) => void;
  onUnlockAudio: () => void;
  onCelebrate: () => void;
  /** Se llama tras registrar (o corregir) una actividad, para registrar logros y mostrar avisos. */
  onOutcome: (outcome: LogOutcome, isAdjustment: boolean) => void;
}

type Sheet = 'weight' | 'adjust' | 'detailed' | null;
type PendingAction = { kind: 'quick_run' } | { kind: 'active_rest' } | null;

interface LoggedResult {
  activityId: string;
  kind: 'run' | 'active_rest';
  outcome: LogOutcome;
  activity: Activity;
}

function celebrate(): void {
  if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return;
  try {
    confetti({ particleCount: 70, spread: 65, origin: { y: 0.55 }, colors: ['#22c55e', '#06b6d4', '#f59e0b', '#ec4899'] });
  } catch {
    // el confeti es solo decorativo
  }
}

export const QuickLogCard: React.FC<QuickLogCardProps> = ({
  today,
  activities,
  weightKg,
  weightLoaded,
  weightPromptDismissed,
  onDismissWeightPrompt,
  onSetWeight,
  addActivity,
  updateActivity,
  removeActivity,
  fillMissingCalories,
  onUnlockAudio,
  onCelebrate,
  onOutcome,
}) => {
  const [sheet, setSheet] = useState<Sheet>(null);
  const [pending, setPending] = useState<PendingAction>(null);
  const [result, setResult] = useState<LoggedResult | null>(null);
  const [confirmDuplicate, setConfirmDuplicate] = useState<PendingAction>(null);
  const resultRef = useRef<HTMLDivElement>(null);

  const week = weekProgress({ activities, vacations: [], today }, today);
  const runsToday = activities.filter((a) => a.type === 'run' && a.occurredOn === today).length;
  const restToday = activities.some((a) => a.type === 'active_rest' && a.occurredOn === today);

  // El resultado se oculta solo, salvo que se esté ajustando.
  useEffect(() => {
    if (!result || sheet !== null) return;
    const timer = window.setTimeout(() => setResult(null), RESULT_VISIBLE_MS);
    return () => window.clearTimeout(timer);
  }, [result, sheet]);

  useEffect(() => {
    if (result) resultRef.current?.focus();
  }, [result?.activityId]);

  const gameContext = useCallback(
    (weight: number | null, list: readonly Activity[]): GameContext => ({
      activities: list,
      vacations: [],
      today,
      weightKg: weight,
    }),
    [today],
  );

  const save = useCallback(
    (draft: ActivityDraft, kind: LoggedResult['kind'], weight: number | null) => {
      const before = gameContext(weight, activities);
      const saved = addActivity(draft, { weightKg: weight });
      const outcome = logOutcome(before, withActivity(before, saved));
      setResult({ activityId: saved.id, kind, outcome, activity: saved });
      celebrate();
      onCelebrate();
      onOutcome(outcome, false);
    },
    [activities, addActivity, gameContext, onCelebrate, onOutcome],
  );

  const runAction = useCallback(
    (action: NonNullable<PendingAction>, weight: number | null) => {
      if (action.kind === 'quick_run') {
        save(
          {
            type: 'run',
            occurredOn: today,
            startedAt: new Date().toISOString(),
            durationSeconds: GAME_CONFIG.defaultRunMinutes * 60,
          },
          'run',
          weight,
        );
      } else {
        save(
          { type: 'active_rest', occurredOn: today, startedAt: new Date().toISOString(), durationSeconds: 10 * 60 },
          'active_rest',
          weight,
        );
      }
    },
    [save, today],
  );

  /** Punto de entrada de los botones: pide el peso la primera vez y evita el doble registro accidental. */
  const start = (action: NonNullable<PendingAction>, skipDuplicateCheck = false) => {
    onUnlockAudio();
    const isDuplicate = action.kind === 'quick_run' ? runsToday > 0 : restToday;
    if (isDuplicate && !skipDuplicateCheck) {
      setConfirmDuplicate(action);
      return;
    }
    setConfirmDuplicate(null);
    setResult(null);
    if (weightKg === null && weightLoaded && !weightPromptDismissed) {
      setPending(action);
      setSheet('weight');
      return;
    }
    runAction(action, weightKg);
  };

  const closeWeightSheet = () => {
    setSheet(null);
    setPending(null);
  };

  const handleWeightSaved = (kg: number) => {
    if (!onSetWeight(kg)) return;
    fillMissingCalories(kg);
    const action = pending;
    setSheet(null);
    setPending(null);
    if (action) runAction(action, kg);
  };

  const handleWeightSkipped = () => {
    onDismissWeightPrompt();
    const action = pending;
    setSheet(null);
    setPending(null);
    if (action) runAction(action, null);
  };

  const handleUndo = () => {
    if (!result) return;
    removeActivity(result.activityId);
    setResult(null);
  };

  const handleAdjust = (fields: RunFields) => {
    if (!result) return;
    const others = activities.filter((a) => a.id !== result.activityId);
    const before = gameContext(weightKg, others);
    const updated = updateActivity(
      result.activityId,
      {
        durationSeconds: fields.durationSeconds,
        distanceKm: fields.distanceKm,
        runLocation: fields.runLocation,
        feeling: fields.feeling,
        occurredOn: fields.occurredOn,
      },
      { weightKg },
    );
    setSheet(null);
    if (updated) {
      const outcome = logOutcome(before, withActivity(before, updated));
      setResult({ ...result, activity: updated, outcome });
      onOutcome(outcome, true);
    }
  };

  const handleDetailed = (fields: RunFields) => {
    setSheet(null);
    save(
      {
        type: 'run',
        occurredOn: fields.occurredOn,
        startedAt: fields.occurredOn === today ? new Date().toISOString() : null,
        durationSeconds: fields.durationSeconds,
        distanceKm: fields.distanceKm,
        runLocation: fields.runLocation,
        feeling: fields.feeling,
      },
      'run',
      weightKg,
    );
  };

  const goalReached = week.runs >= week.runsGoal;

  return (
    <section aria-label="Registrar actividad" className="space-y-3">
      <div className="rounded-2xl border border-cyan-500/30 bg-gradient-to-br from-surface-900 to-black p-4 shadow-lg">
        <div className="flex items-center justify-between gap-2 mb-3">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded-lg bg-cyan-500/20 text-cyan-400">
              <Footprints className="w-4 h-4" aria-hidden="true" />
            </div>
            <span className="text-[11px] font-bold uppercase tracking-wider text-cyan-400">Corridas de la semana</span>
          </div>
          <span className="text-xs font-extrabold text-white" aria-label={`${week.runs} de ${week.runsGoal} corridas`}>
            {week.runs}/{week.runsGoal}
          </span>
        </div>

        <p className="text-xs text-zinc-400 mb-3 leading-relaxed">
          {goalReached
            ? '¡Meta de corridas cumplida esta semana! Cada una de más suma XP.'
            : `Tu meta son ${week.runsGoal} corridas por semana. Te ${week.remainingRuns === 1 ? 'falta 1' : `faltan ${week.remainingRuns}`}.`}
        </p>

        <button
          type="button"
          onClick={() => start({ kind: 'quick_run' })}
          className="w-full py-4 rounded-2xl bg-gradient-to-r from-cyan-400 to-emerald-400 text-black font-extrabold text-base flex items-center justify-center gap-2.5 shadow-xl shadow-cyan-500/20 active:scale-[0.98] transition-transform"
        >
          <Footprints className="w-5 h-5" aria-hidden="true" />
          <span>Hoy corrí ({GAME_CONFIG.defaultRunMinutes} min)</span>
        </button>

        <div className="grid grid-cols-2 gap-2 mt-2">
          <button
            type="button"
            onClick={() => {
              onUnlockAudio();
              setResult(null);
              setSheet('detailed');
            }}
            className="py-2.5 rounded-xl bg-surface-800 border border-zinc-700 text-zinc-200 font-bold text-xs flex items-center justify-center gap-1.5 active:bg-surface-700"
          >
            <SlidersHorizontal className="w-3.5 h-3.5" aria-hidden="true" />
            Con detalles / otro día
          </button>
          <button
            type="button"
            onClick={() => start({ kind: 'active_rest' })}
            className="py-2.5 rounded-xl bg-surface-800 border border-zinc-700 text-zinc-200 font-bold text-xs flex items-center justify-center gap-1.5 active:bg-surface-700"
          >
            <Leaf className="w-3.5 h-3.5 text-emerald-400" aria-hidden="true" />
            Descanso activo
          </button>
        </div>

        <button
          type="button"
          onClick={() => {
            setPending(null);
            setSheet('weight');
          }}
          className="mt-3 inline-flex items-center gap-1.5 text-[11px] text-zinc-500 active:text-zinc-300"
        >
          <Scale className="w-3 h-3" aria-hidden="true" />
          {weightKg !== null ? `Peso: ${String(weightKg).replace('.', ',')} kg · editar` : 'Cargar mi peso para estimar calorías'}
        </button>
      </div>

      {confirmDuplicate && (
        <div role="alertdialog" aria-label="Confirmar nuevo registro" className="rounded-2xl border border-amber-500/40 bg-amber-950/30 p-4 space-y-3">
          <p className="text-sm text-amber-200 font-semibold">
            {confirmDuplicate.kind === 'quick_run'
              ? 'Ya registraste una corrida hoy. ¿Registrar otra?'
              : 'Ya registraste un descanso activo hoy. Solo el primero suma XP. ¿Registrar otro igual?'}
          </p>
          <div className="grid grid-cols-2 gap-2">
            <button
              type="button"
              onClick={() => setConfirmDuplicate(null)}
              className="py-2.5 rounded-xl bg-surface-800 border border-zinc-700 text-zinc-200 font-bold text-xs active:bg-surface-700"
            >
              No, gracias
            </button>
            <button
              type="button"
              onClick={() => start(confirmDuplicate, true)}
              className="py-2.5 rounded-xl bg-amber-400 text-black font-extrabold text-xs active:scale-[0.98]"
            >
              Sí, registrar
            </button>
          </div>
        </div>
      )}

      {result && (
        <div
          ref={resultRef}
          tabIndex={-1}
          role="status"
          aria-live="polite"
          className="rounded-2xl border border-cardio-primary/40 bg-emerald-950/30 p-4 space-y-3 outline-none animate-fadeIn"
        >
          <div className="flex items-center gap-2 text-emerald-300">
            <Trophy className="w-4 h-4" aria-hidden="true" />
            <span className="text-sm font-extrabold">
              {result.kind === 'run' ? '¡Corrida registrada!' : '¡Descanso activo registrado!'}
            </span>
          </div>

          <div className="flex flex-wrap gap-2 text-xs font-bold">
            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-amber-500/15 text-amber-300 border border-amber-500/30">
              <Zap className="w-3 h-3" aria-hidden="true" />+{result.outcome.xpGained} XP
            </span>
            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-orange-500/15 text-orange-300 border border-orange-500/30">
              <Flame className="w-3 h-3" aria-hidden="true" />
              Racha: {result.outcome.streakAfter} {result.outcome.streakAfter === 1 ? 'día' : 'días'}
            </span>
            {result.activity.caloriesKcal != null && (
              <span className="px-2.5 py-1 rounded-full bg-zinc-800 text-zinc-300 border border-zinc-700">
                ~{Math.round(result.activity.caloriesKcal)} kcal (estimado)
              </span>
            )}
          </div>

          {result.kind === 'run' && (
            <p className="text-xs text-zinc-300">
              Corridas de la semana: {result.outcome.weekRuns}/{result.outcome.runsGoal}
              {result.outcome.weekRuns >= result.outcome.runsGoal ? ' · ¡meta cumplida!' : ''}
            </p>
          )}
          <div className={`grid gap-2 ${result.kind === 'run' ? 'grid-cols-2' : 'grid-cols-1'}`}>
            {result.kind === 'run' && (
              <button
                type="button"
                onClick={() => setSheet('adjust')}
                className="py-2.5 rounded-xl bg-surface-800 border border-zinc-700 text-zinc-100 font-bold text-xs flex items-center justify-center gap-1.5 active:bg-surface-700"
              >
                <SlidersHorizontal className="w-3.5 h-3.5" aria-hidden="true" />
                Ajustar
              </button>
            )}
            <button
              type="button"
              onClick={handleUndo}
              className="py-2.5 rounded-xl bg-surface-800 border border-zinc-700 text-zinc-100 font-bold text-xs flex items-center justify-center gap-1.5 active:bg-surface-700"
            >
              <Undo2 className="w-3.5 h-3.5" aria-hidden="true" />
              Deshacer
            </button>
          </div>
        </div>
      )}

      {sheet === 'weight' && (
        <WeightSheet
          initialKg={weightKg}
          skipLabel={pending ? 'Ahora no, guardar sin calorías' : undefined}
          onSave={handleWeightSaved}
          onSkip={pending ? handleWeightSkipped : undefined}
          onClose={closeWeightSheet}
        />
      )}

      {sheet === 'adjust' && result && result.kind === 'run' && (
        <RunSheet
          title="Ajustar corrida"
          submitLabel="Guardar cambios"
          today={today}
          initial={runFormFromActivity(result.activity)}
          onSubmit={handleAdjust}
          onClose={() => setSheet(null)}
        />
      )}

      {sheet === 'detailed' && (
        <RunSheet
          title="Registrar corrida"
          submitLabel="Guardar corrida"
          today={today}
          initial={defaultRunForm(today)}
          onSubmit={handleDetailed}
          onClose={() => setSheet(null)}
        />
      )}
    </section>
  );
};
