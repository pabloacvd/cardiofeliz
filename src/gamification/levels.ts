import { GAME_CONFIG, type MascotStageDef } from './config';

export interface LevelInfo {
  level: number;
  tierName: string;
  totalXp: number;
  /** XP acumulado dentro del nivel actual. */
  xpIntoLevel: number;
  /** XP total que dura el nivel actual. */
  xpForNextLevel: number;
  /** 0 a 1. */
  progress: number;
}

/** XP acumulado necesario para llegar al nivel `level` (el nivel 1 arranca en 0). */
export function xpForLevel(level: number): number {
  const l = Math.max(1, Math.floor(level));
  return GAME_CONFIG.levels.stepXp * (l - 1) * l;
}

export function tierNameForLevel(level: number): string {
  const tiers = GAME_CONFIG.levels.tiers;
  let name = tiers[0].name;
  for (const t of tiers) {
    if (level >= t.fromLevel) name = t.name;
  }
  return name;
}

export function levelFromXp(xp: number): LevelInfo {
  const totalXp = Number.isFinite(xp) && xp > 0 ? Math.floor(xp) : 0;
  const step = GAME_CONFIG.levels.stepXp;

  let level = Math.max(1, Math.floor((1 + Math.sqrt(1 + (4 * totalXp) / step)) / 2));
  while (xpForLevel(level + 1) <= totalXp) level += 1;
  while (level > 1 && xpForLevel(level) > totalXp) level -= 1;

  const base = xpForLevel(level);
  const xpForNextLevel = xpForLevel(level + 1) - base;
  const xpIntoLevel = totalXp - base;

  return {
    level,
    tierName: tierNameForLevel(level),
    totalXp,
    xpIntoLevel,
    xpForNextLevel,
    progress: xpForNextLevel > 0 ? xpIntoLevel / xpForNextLevel : 0,
  };
}

/** Etapa de la mascota según el nivel. */
export function mascotStage(level: number): MascotStageDef {
  const stages = GAME_CONFIG.mascot.stages;
  let current = stages[0];
  for (const s of stages) {
    if (level >= s.fromLevel) current = s;
  }
  return current;
}
