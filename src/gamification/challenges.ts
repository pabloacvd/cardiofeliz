import type { Activity } from '../types/gamification';
import { GAME_CONFIG } from './config';
import {
  addDays,
  diffDays,
  weekEnd,
  weekNumber,
  weekStart,
  type DateKey,
} from './dates';
import { isRun, safeNumber, startedHour, type GameContext } from './activities';
import { isOnVacation, vacationDaysInRange } from './vacations';

export type ChallengeUnit = 'días' | 'km' | 'min';

interface ChallengeDef {
  id: string;
  title: string;
  description: string;
  target: number;
  unit: ChallengeUnit;
  /** Avance dentro de la semana (actividades ya filtradas a lunes–domingo). */
  progress: (inWeek: readonly Activity[]) => number;
  /** Decide, con el historial ANTERIOR a la semana, si el desafío se puede cumplir. */
  feasible: (prior: readonly Activity[]) => boolean;
}

const distinctDays = (list: readonly Activity[]): DateKey[] =>
  [...new Set(list.map((a) => a.occurredOn))].sort();

function longestConsecutiveDays(days: readonly DateKey[]): number {
  let best = 0;
  let run = 0;
  let prev: DateKey | null = null;
  for (const d of days) {
    run = prev !== null && diffDays(d, prev) === 1 ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

const CATALOG: readonly ChallengeDef[] = [
  {
    id: 'streak_3_days',
    title: '3 días seguidos',
    description: 'Estate activa 3 días seguidos esta semana.',
    target: 3,
    unit: 'días',
    progress: (w) => longestConsecutiveDays(distinctDays(w)),
    feasible: () => true,
  },
  {
    id: 'run_10_km',
    title: 'Corré 10 km',
    description: 'Sumá 10 km corridos esta semana.',
    target: 10,
    unit: 'km',
    progress: (w) => Math.round(w.filter(isRun).reduce((s, a) => s + safeNumber(a.distanceKm), 0) * 100) / 100,
    // Solo si ya se informaron km en alguna corrida: si no, sería imposible de medir.
    feasible: (prior) => prior.some((a) => isRun(a) && safeNumber(a.distanceKm) > 0),
  },
  {
    id: 'minutes_150',
    title: '150 minutos activos',
    description: 'Sumá 150 minutos de actividad esta semana.',
    target: 150,
    unit: 'min',
    progress: (w) => Math.round(w.reduce((s, a) => s + safeNumber(a.durationSeconds), 0) / 60),
    feasible: () => true,
  },
  {
    id: 'morning_2_days',
    title: 'Madrugadora',
    description: 'Entrená 2 días antes del mediodía.',
    target: 2,
    unit: 'días',
    progress: (w) =>
      distinctDays(
        w.filter((a) => {
          const h = startedHour(a);
          return h !== null && h < GAME_CONFIG.challenges.morningBeforeHour;
        }),
      ).length,
    // Necesita saber la hora de inicio: solo si ya hay actividades con hora registrada.
    feasible: (prior) => prior.some((a) => startedHour(a) !== null),
  },
  {
    id: 'long_run_40',
    title: 'Corrida larga',
    description: 'Hacé una corrida de 40 minutos o más.',
    target: 40,
    unit: 'min',
    progress: (w) => Math.round(Math.max(0, ...w.filter(isRun).map((a) => safeNumber(a.durationSeconds))) / 60),
    feasible: () => true,
  },
  {
    id: 'active_days_5',
    title: '5 días en movimiento',
    description: 'Estate activa 5 días distintos esta semana.',
    target: 5,
    unit: 'días',
    progress: (w) => distinctDays(w).length,
    feasible: () => true,
  },
];

export interface WeeklyChallenge {
  id: string;
  title: string;
  description: string;
  unit: ChallengeUnit;
  weekStart: DateKey;
  target: number;
  progress: number;
  /** 0 a 1. */
  ratio: number;
  done: boolean;
  xp: number;
  /** Semana con vacaciones suficientes y sin cumplir: no cuenta en contra. */
  paused: boolean;
  /** La semana en curso está de vacaciones: no se muestra. */
  hidden: boolean;
}

function pickDefinition(ws: DateKey, prior: readonly Activity[]): ChallengeDef {
  const base = weekNumber(ws);
  for (let i = 0; i < CATALOG.length; i++) {
    const def = CATALOG[(base + i) % CATALOG.length];
    if (def.feasible(prior)) return def;
  }
  return CATALOG[0];
}

/**
 * Desafío de la semana que contiene a `anyDay`.
 * Es determinista: depende solo del número de semana y del historial anterior a esa semana,
 * así que todos los dispositivos de un mismo usuario ven el mismo desafío.
 */
export function evaluateChallenge(ctx: GameContext, anyDay: DateKey = ctx.today): WeeklyChallenge {
  const ws = weekStart(anyDay);
  const we = weekEnd(anyDay);
  const prior = ctx.activities.filter((a) => a.occurredOn < ws);
  const inWeek = ctx.activities.filter((a) => a.occurredOn >= ws && a.occurredOn <= we);

  const def = pickDefinition(ws, prior);
  const progress = def.progress(inWeek);
  const done = progress >= def.target;
  const paused = !done && vacationDaysInRange(ws, we, ctx.vacations) >= GAME_CONFIG.week.vacationPauseMinDays;
  const isCurrentWeek = ctx.today >= ws && ctx.today <= we;

  return {
    id: def.id,
    title: def.title,
    description: def.description,
    unit: def.unit,
    weekStart: ws,
    target: def.target,
    progress,
    ratio: Math.min(1, progress / def.target),
    done,
    xp: GAME_CONFIG.xp.challenge,
    paused,
    hidden: isCurrentWeek && isOnVacation(ctx.today, ctx.vacations),
  };
}

/** Desafíos de todas las semanas, desde la primera con actividad hasta la actual. */
export function challengeHistory(ctx: GameContext): WeeklyChallenge[] {
  if (ctx.activities.length === 0) return [];
  const first = ctx.activities.reduce(
    (min, a) => (a.occurredOn < min ? a.occurredOn : min),
    ctx.activities[0].occurredOn,
  );
  const out: WeeklyChallenge[] = [];
  const last = weekStart(ctx.today);
  for (let ws = weekStart(first); ws <= last; ws = addDays(ws, 7)) {
    out.push(evaluateChallenge(ctx, ws));
  }
  return out;
}
