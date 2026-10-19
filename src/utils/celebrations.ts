import type { LogOutcome } from '../gamification';

export type ToastKind = 'achievement' | 'level' | 'freeze';

export interface ToastItem {
  id: string;
  kind: ToastKind;
  title: string;
  detail: string;
}

/** Une los logros ya filtrados (los realmente nuevos) con el resto del resultado. */
export function withClaimedAchievements(outcome: LogOutcome, claimedIds: readonly string[]): LogOutcome {
  const claimed = new Set(claimedIds);
  return { ...outcome, newAchievements: outcome.newAchievements.filter((a) => claimed.has(a.id)) };
}

/** Avisos a mostrar tras un registro: logros nuevos, subida de nivel y congelador ganado. */
export function buildToasts(outcome: LogOutcome): ToastItem[] {
  const toasts: ToastItem[] = [];

  if (outcome.leveledUp) {
    toasts.push({
      id: `level-${outcome.levelAfter}`,
      kind: 'level',
      title: `¡Nivel ${outcome.levelAfter}!`,
      detail: outcome.tierName,
    });
  }
  for (const a of outcome.newAchievements) {
    toasts.push({ id: `achievement-${a.id}`, kind: 'achievement', title: `Logro: ${a.title}`, detail: a.description });
  }
  if (outcome.earnedFreeze) {
    toasts.push({
      id: `freeze-${outcome.streakAfter}`,
      kind: 'freeze',
      title: 'Ganaste un congelador',
      detail: 'Protege tu racha si algún día no podés entrenar.',
    });
  }
  return toasts;
}
