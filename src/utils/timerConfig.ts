/**
 * src/utils/timerConfig.ts
 *
 * Lógica pura de configuración y secuenciado de los timers de bloque:
 * - getTriserieConfig: rondas y descanso de Triserie/Density.
 * - getTabataConfig: rondas, trabajo y descanso de Tabata.
 * - buildFinisherPhases: secuencia de fases de Finisher/HIIT_INTERVALS.
 * - finisherProgress / finisherTotalSeconds: progreso y duración total.
 *
 * Todos los campos de configuración son opcionales; si faltan (o son inválidos)
 * valen los defaults históricos de cada timer.
 */

import type { BloqueBase, EjercicioGenerico } from '../types/workout';

// ---------------------------------------------------------------------------
// Defaults
// ---------------------------------------------------------------------------

export const DEFAULT_TRISERIE_ROUNDS = 4;
export const DEFAULT_TRISERIE_REST_SECONDS = 45;
export const DEFAULT_TABATA_ROUNDS = 8;
export const DEFAULT_TABATA_WORK_SECONDS = 20;
export const DEFAULT_TABATA_REST_SECONDS = 10;
export const DEFAULT_FINISHER_ROUNDS = 3;
/** Duración de un paso de descanso del Finisher/HIIT que no define `segundos`. */
export const DEFAULT_FINISHER_REST_SECONDS = 30;
/** Peso (en segundos) que un paso manual aporta a la barra de progreso. */
export const MANUAL_PHASE_WEIGHT_SECONDS = 30;

function positiveInt(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isInteger(value) && value > 0 ? value : undefined;
}

function nonNegativeInt(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 ? value : undefined;
}

/**
 * Extrae segundos de un texto tipo "45 seg", "45s" o "1 min".
 * Devuelve undefined si no se puede interpretar.
 */
export function parseRestSeconds(text: string | undefined): number | undefined {
  if (typeof text !== 'string') return undefined;
  const match = text.match(/(\d+)\s*(min|m\b)?/i);
  if (!match) return undefined;
  const value = parseInt(match[1], 10);
  if (!Number.isFinite(value)) return undefined;
  return match[2] ? value * 60 : value;
}

// ---------------------------------------------------------------------------
// Triserie / Density
// ---------------------------------------------------------------------------

export interface TriserieConfig {
  rounds: number;
  restSeconds: number;
}

export function getTriserieConfig(
  bloque: Pick<BloqueBase, 'rondas' | 'descanso_seg' | 'descanso_entre_rondas'>,
): TriserieConfig {
  return {
    rounds: positiveInt(bloque.rondas) ?? DEFAULT_TRISERIE_ROUNDS,
    restSeconds:
      nonNegativeInt(bloque.descanso_seg) ??
      parseRestSeconds(bloque.descanso_entre_rondas) ??
      DEFAULT_TRISERIE_REST_SECONDS,
  };
}

// ---------------------------------------------------------------------------
// Tabata
// ---------------------------------------------------------------------------

export interface TabataConfig {
  rounds: number;
  workSeconds: number;
  restSeconds: number;
}

export function getTabataConfig(
  bloque: Pick<BloqueBase, 'rondas' | 'trabajo_seg' | 'descanso_tabata_seg'>,
): TabataConfig {
  return {
    rounds: positiveInt(bloque.rondas) ?? DEFAULT_TABATA_ROUNDS,
    workSeconds: positiveInt(bloque.trabajo_seg) ?? DEFAULT_TABATA_WORK_SECONDS,
    restSeconds: positiveInt(bloque.descanso_tabata_seg) ?? DEFAULT_TABATA_REST_SECONDS,
  };
}

// ---------------------------------------------------------------------------
// Finisher / HIIT_INTERVALS
// ---------------------------------------------------------------------------

/**
 * - WORK: paso con cuenta regresiva (trabajo).
 * - TRANSITION: resto de un paso dividido por `trabajo_seg`; con cuenta regresiva.
 * - REST: paso de descanso (detalle contiene "descanso"); con cuenta regresiva.
 * - MANUAL: paso sin `segundos` que avanza con el botón "Listo".
 */
export type FinisherPhaseKind = 'WORK' | 'TRANSITION' | 'REST' | 'MANUAL';

export interface FinisherPhase {
  kind: FinisherPhaseKind;
  /** Ronda (1-based). */
  round: number;
  /** Índice del ejercicio dentro de la ronda (0-based). */
  exerciseIndex: number;
  detalle: string;
  /** Duración de la cuenta regresiva; null en pasos manuales. */
  seconds: number | null;
}

export function isRestExercise(ej: Pick<EjercicioGenerico, 'detalle'> | undefined): boolean {
  return !!ej && ej.detalle.toLowerCase().includes('descanso');
}

export function getFinisherRounds(bloque: Pick<BloqueBase, 'rondas'>): number {
  return positiveInt(bloque.rondas) ?? DEFAULT_FINISHER_ROUNDS;
}

/** Fases de una sola ronda, sin repetir. */
function buildRoundPhases(
  ejercicios: EjercicioGenerico[],
  trabajoSeg: number | undefined,
  round: number,
): FinisherPhase[] {
  const phases: FinisherPhase[] = [];

  ejercicios.forEach((ej, exerciseIndex) => {
    const segundos = positiveInt(ej.segundos);
    const base = { round, exerciseIndex, detalle: ej.detalle };

    if (isRestExercise(ej)) {
      phases.push({ ...base, kind: 'REST', seconds: segundos ?? DEFAULT_FINISHER_REST_SECONDS });
      return;
    }
    if (segundos === undefined) {
      phases.push({ ...base, kind: 'MANUAL', seconds: null });
      return;
    }
    if (trabajoSeg !== undefined && segundos > trabajoSeg) {
      phases.push({ ...base, kind: 'WORK', seconds: trabajoSeg });
      phases.push({ ...base, kind: 'TRANSITION', seconds: segundos - trabajoSeg });
      return;
    }
    phases.push({ ...base, kind: 'WORK', seconds: segundos });
  });

  return phases;
}

/** Secuencia completa de fases (todas las rondas) de un Finisher o HIIT_INTERVALS. */
export function buildFinisherPhases(
  bloque: Pick<BloqueBase, 'rondas' | 'trabajo_seg'> & { ejercicios: EjercicioGenerico[] },
): FinisherPhase[] {
  const rounds = getFinisherRounds(bloque);
  const trabajoSeg = positiveInt(bloque.trabajo_seg);
  const phases: FinisherPhase[] = [];
  for (let round = 1; round <= rounds; round++) {
    phases.push(...buildRoundPhases(bloque.ejercicios, trabajoSeg, round));
  }
  return phases;
}

function phaseWeight(phase: FinisherPhase): number {
  return phase.seconds ?? MANUAL_PHASE_WEIGHT_SECONDS;
}

/**
 * Progreso (0..1) dado el índice de fase actual y los segundos restantes de esa fase.
 * Las fases con tiempo pesan por su duración; las manuales pesan MANUAL_PHASE_WEIGHT_SECONDS.
 */
export function finisherProgress(
  phases: FinisherPhase[],
  phaseIndex: number,
  secondsLeft: number,
): number {
  if (phases.length === 0) return 0;
  const total = phases.reduce((acc, p) => acc + phaseWeight(p), 0);
  if (total <= 0) return 0;
  const idx = Math.min(Math.max(phaseIndex, 0), phases.length - 1);
  let done = 0;
  for (let i = 0; i < idx; i++) done += phaseWeight(phases[i]);
  const current = phases[idx];
  if (current.seconds !== null) {
    done += Math.min(Math.max(current.seconds - secondsLeft, 0), current.seconds);
  }
  return Math.min(done / total, 1);
}

/** Duración total en segundos; null si hay pasos manuales (duración desconocida). */
export function finisherTotalSeconds(phases: FinisherPhase[]): number | null {
  let total = 0;
  for (const p of phases) {
    if (p.seconds === null) return null;
    total += p.seconds;
  }
  return total;
}
