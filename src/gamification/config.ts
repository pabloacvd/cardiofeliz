/**
 * Reglas numéricas del juego (metas, XP, niveles, calorías, umbrales).
 * Los catálogos de textos y condiciones viven junto a su lógica: challenges.ts, missions.ts y achievements.ts.
 */

export interface RunMetPoint {
  speedKmh: number;
  met: number;
}

export interface LevelTier {
  fromLevel: number;
  name: string;
}

export interface MascotStageDef {
  stage: number;
  fromLevel: number;
  name: string;
  catchphrase: string;
}

export const GAME_CONFIG = {
  /** Meta semanal base (lunes a domingo). */
  weeklyGoal: { workouts: 3, runs: 2 },

  /** Duración por defecto de "Hoy corrí". */
  defaultRunMinutes: 30,

  streak: {
    /** Se gana 1 congelador cada N días de racha. */
    freezeEvery: 5,
    maxFreezes: 2,
    /** XP único por alcanzar cada hito de racha (se cuenta una sola vez por hito). */
    milestoneBonusXp: { 3: 20, 7: 50, 14: 100, 30: 200, 60: 400, 100: 800 } as Record<number, number>,
  },

  week: {
    /** Una semana con al menos esta cantidad de días de vacaciones queda "pausada". */
    vacationPauseMinDays: 4,
  },

  vacation: {
    /** Se avisa cuando las vacaciones superan esta cantidad de días. */
    longWarningDays: 30,
    /** Días de "¡Hay que recuperar!" después de volver (el día siguiente a endOn es el día 1). */
    comebackDays: 3,
    comebackXpMultiplier: 1.5,
  },

  xp: {
    workoutDay: 100,
    baseBlocks: 3,
    extraBlock: 10,
    run: 60,
    runBaseMinutes: 30,
    runStepMinutes: 5,
    runMaxTimeBonus: 20,
    runKmBonus: 10,
    activeRest: 20,
    perfectWeek: 150,
    challenge: 80,
    allMissionsBonus: 20,
  },

  levels: {
    /** XP acumulado para llegar al nivel L = stepXp * (L - 1) * L. */
    stepXp: 50,
    tiers: [
      { fromLevel: 1, name: 'Calentando motores' },
      { fromLevel: 3, name: 'En ritmo' },
      { fromLevel: 6, name: 'Constante' },
      { fromLevel: 10, name: 'Imparable' },
      { fromLevel: 15, name: 'Atleta' },
      { fromLevel: 20, name: 'Élite' },
      { fromLevel: 30, name: 'Leyenda' },
    ] as LevelTier[],
  },

  mascot: {
    stages: [
      { stage: 1, fromLevel: 1, name: 'Brasita', catchphrase: '¡Chispa!' },
      { stage: 2, fromLevel: 4, name: 'Llamita', catchphrase: '¡A prender!' },
      { stage: 3, fromLevel: 8, name: 'Fueguito', catchphrase: '¡Arde!' },
      { stage: 4, fromLevel: 14, name: 'Fogata', catchphrase: '¡Imparable!' },
      { stage: 5, fromLevel: 22, name: 'Fénix', catchphrase: '¡Renazco más fuerte!' },
    ] as MascotStageDef[],
  },

  calories: {
    /** Mismo rango que la restricción de cf_profiles.weight_kg. */
    weightMinKg: 20,
    weightMaxKg: 300,
    met: {
      workout: 8,
      activeRest: 3,
      /** Corrida sin distancia informada (ritmo moderado). */
      runDefault: 8.3,
      /** Velocidades mayores se consideran un error de carga y se usa runDefault. */
      maxPlausibleRunSpeedKmh: 25,
    },
    /** Equivalentes metabólicos (Compendium of Physical Activities), interpolados linealmente. */
    runTable: [
      { speedKmh: 4, met: 3.5 },
      { speedKmh: 6.4, met: 6.0 },
      { speedKmh: 8.0, met: 8.3 },
      { speedKmh: 9.7, met: 9.8 },
      { speedKmh: 11.3, met: 11.0 },
      { speedKmh: 12.9, met: 11.8 },
      { speedKmh: 14.5, met: 12.8 },
      { speedKmh: 16.1, met: 14.5 },
    ] as RunMetPoint[],
  },

  coach: {
    /** Días completos sin actividad (sin contar vacaciones) para el mensaje "te extrañamos". */
    lapseDays: 4,
  },

  achievements: {
    /** "Madrugadora": actividad iniciada antes de esta hora local. */
    earlyBirdBeforeHour: 8,
    /** "Volví": días sin actividad (sin contar vacaciones) antes de retomar. */
    comebackGapDays: 7,
  },

  challenges: {
    /** "Antes del mediodía". */
    morningBeforeHour: 12,
  },
};

export type GameConfig = typeof GAME_CONFIG;
