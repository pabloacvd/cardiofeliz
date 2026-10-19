import type { Activity } from '../types/gamification';
import { GAME_CONFIG } from './config';
import { dayNumber, type DateKey } from './dates';
import { contextBefore, isRun, isWorkout, safeNumber, type GameContext } from './activities';
import { comebackStatus, isOnVacation } from './vacations';
import { weekProgress } from './weeks';

type MissionId = 'comeback_easy' | 'do_run' | 'do_workout' | 'long_session' | 'active_rest' | 'any_activity';

interface MissionDef {
  id: MissionId;
  title: string;
  xp: number;
  done: (dayActivities: readonly Activity[]) => boolean;
}

const minutesOf = (list: readonly Activity[]): number =>
  list.reduce((sum, a) => sum + safeNumber(a.durationSeconds), 0) / 60;

const DEFS: Record<MissionId, MissionDef> = {
  comeback_easy: {
    id: 'comeback_easy',
    title: 'Vuelta suave: 15 minutos de lo que quieras',
    xp: 25,
    done: (d) => minutesOf(d) >= 15,
  },
  do_run: {
    id: 'do_run',
    title: 'Registrá tu corrida',
    xp: 30,
    done: (d) => d.some(isRun),
  },
  do_workout: {
    id: 'do_workout',
    title: 'Terminá un entrenamiento completo',
    xp: 30,
    done: (d) => d.some(isWorkout),
  },
  long_session: {
    id: 'long_session',
    title: 'Sumá 40 minutos activos',
    xp: 25,
    done: (d) => minutesOf(d) >= 40,
  },
  active_rest: {
    id: 'active_rest',
    title: 'Hacé un descanso activo (caminata o movilidad)',
    xp: 15,
    done: (d) => d.some((a) => a.type === 'active_rest'),
  },
  any_activity: {
    id: 'any_activity',
    title: 'Moverte hoy: cualquier actividad cuenta',
    xp: 10,
    done: (d) => d.length > 0,
  },
};

const MAX_MISSIONS = 3;

export interface DailyMission {
  id: string;
  title: string;
  xp: number;
  done: boolean;
}

export interface DailyMissions {
  day: DateKey;
  missions: DailyMission[];
  allDone: boolean;
  /** XP de las misiones cumplidas + bonus si se cumplieron todas. */
  xpEarned: number;
  /** De vacaciones: no hay misiones. */
  hidden: boolean;
}

/**
 * Qué misiones se ofrecen en `day`. Se decide con lo ocurrido ANTES de ese día,
 * así la lista no cambia a lo largo del día aunque se vaya cumpliendo.
 * Siempre hay entre 2 y 3 (salvo vacaciones).
 */
export function pickDailyMissions(ctx: GameContext, day: DateKey = ctx.today): MissionId[] {
  if (isOnVacation(day, ctx.vacations)) return [];

  const before = contextBefore(ctx, day);
  const week = weekProgress(before, day);
  const picks: MissionId[] = [];

  if (comebackStatus(day, ctx.vacations).active) picks.push('comeback_easy');
  if (week.remainingRuns > 0) picks.push('do_run');
  if (week.remainingWorkouts > 0) picks.push('do_workout');

  // Rotación diaria determinista entre las opcionales.
  picks.push(dayNumber(day) % 2 === 0 ? 'long_session' : 'active_rest');
  picks.push('any_activity');

  return picks.slice(0, MAX_MISSIONS);
}

export function evaluateMissions(ctx: GameContext, day: DateKey = ctx.today): DailyMissions {
  const ids = pickDailyMissions(ctx, day);
  const dayActivities = ctx.activities.filter((a) => a.occurredOn === day);

  const missions = ids.map((id) => {
    const def = DEFS[id];
    return { id: def.id, title: def.title, xp: def.xp, done: def.done(dayActivities) };
  });
  const allDone = missions.length > 0 && missions.every((m) => m.done);
  const xpEarned =
    missions.filter((m) => m.done).reduce((sum, m) => sum + m.xp, 0) +
    (allDone ? GAME_CONFIG.xp.allMissionsBonus : 0);

  return { day, missions, allDone, xpEarned, hidden: missions.length === 0 };
}
