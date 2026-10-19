/**
 * Motor de gamificación: funciones puras sobre `activities` + `vacations` + `today`.
 * No guarda nada: toda la información se deriva, así que cualquier dispositivo
 * del mismo usuario llega exactamente al mismo resultado.
 */

import { cleanActivities, cleanVacations, type GameContext } from './activities';
import { evaluateAchievements, type AchievementStatus } from './achievements';
import { evaluateChallenge, type WeeklyChallenge } from './challenges';
import { pickCoachMessage, type CoachMessage } from './coach';
import { levelFromXp, mascotStage, type LevelInfo } from './levels';
import { evaluateMissions, type DailyMissions } from './missions';
import { computeStreak, type StreakResult } from './streak';
import { comebackStatus, vacationStatus, type ComebackStatus, type VacationStatus } from './vacations';
import { computeWeeklyStreak, weekProgress, type WeeklyStreakResult, type WeekProgress } from './weeks';
import { computeXp, type XpBreakdown } from './xp';
import type { MascotStageDef } from './config';

export interface GameSummary {
  xp: XpBreakdown;
  level: LevelInfo;
  mascot: MascotStageDef;
  streak: StreakResult;
  weekly: WeeklyStreakResult;
  week: WeekProgress;
  challenge: WeeklyChallenge;
  missions: DailyMissions;
  achievements: AchievementStatus[];
  vacation: VacationStatus;
  comeback: ComebackStatus;
  coach: CoachMessage;
}

/** Normaliza el contexto (descarta datos inválidos o del futuro) y calcula todo el estado de juego. */
export function computeGameSummary(input: GameContext): GameSummary {
  const ctx: GameContext = {
    ...input,
    activities: cleanActivities(input.activities, input.today),
    vacations: cleanVacations(input.vacations),
  };

  const xp = computeXp(ctx);
  const level = levelFromXp(xp.total);

  return {
    xp,
    level,
    mascot: mascotStage(level.level),
    streak: computeStreak(ctx),
    weekly: computeWeeklyStreak(ctx),
    week: weekProgress(ctx, ctx.today),
    challenge: evaluateChallenge(ctx),
    missions: evaluateMissions(ctx),
    achievements: evaluateAchievements(ctx),
    vacation: vacationStatus(ctx.today, ctx.vacations),
    comeback: comebackStatus(ctx.today, ctx.vacations),
    coach: pickCoachMessage(ctx),
  };
}

export { estimateCalories, metForRun, sanitizeWeight } from './calories';
export { activityBaseXp, computeActivityXp } from './xp';
export { levelFromXp, mascotStage, xpForLevel } from './levels';
export { newlyUnlocked } from './achievements';
export { challengeHistory } from './challenges';
export { todayKey, toDateKey, weekStart, weekEnd, isoWeek, addDays, diffDays, eachDay } from './dates';
export { cleanActivities, cleanVacations } from './activities';
export type { GameContext } from './activities';
export { GAME_CONFIG } from './config';
