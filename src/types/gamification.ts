/**
 * Modelos de dominio para Gamificación, Actividades y Analíticas.
 * Incluye funciones de mapeo bidireccional con los tipos de Supabase.
 */

import type {
  ActivityRow,
  ActivityInsert,
  ActivityType,
  RunLocation,
  WorkoutDayId,
  ProfileRow,
  ProfileInsert,
  AchievementRow,
  AchievementInsert,
  VacationRow,
  VacationInsert,
} from './database';

export type { ActivityType, RunLocation, WorkoutDayId };

/**
 * Modelo de dominio para una Actividad realizada por el usuario.
 */
export interface Activity {
  id: string; // UUID v4 idempotente generado en cliente
  userId?: string;
  type: ActivityType;
  occurredOn: string; // YYYY-MM-DD (fecha local)
  startedAt?: string | null; // ISO string
  durationSeconds: number;
  dayId?: WorkoutDayId | string | null;
  blocksCompleted?: number | null;
  roundsTotal?: number | null;
  distanceKm?: number | null;
  runLocation?: RunLocation | null;
  feeling?: number | null; // 1 (muy pesado) - 5 (excelente)
  caloriesKcal?: number | null;
  xpEarned: number;
  createdAt?: string;
}

/**
 * Modelo de dominio para el Perfil de usuario.
 */
export interface UserProfile {
  userId: string;
  displayName?: string | null;
  weightKg?: number | null;
  createdAt?: string;
  updatedAt?: string;
}

/**
 * Modelo de dominio para un Logro desbloqueado.
 */
export interface AchievementUnlock {
  userId?: string;
  achievementId: string;
  unlockedAt: string; // ISO string
}

/**
 * Modelo de dominio para un período de Vacaciones.
 */
export interface VacationPeriod {
  id: string;
  userId?: string;
  startOn: string; // YYYY-MM-DD
  endOn?: string | null; // YYYY-MM-DD, null mientras esté activa
  createdAt?: string;
}

// ============================================================================
// FUNCIONES DE MAPEO (DB <-> DOMAIN)
// ============================================================================

export function toDomainProfile(row: ProfileRow): UserProfile {
  return {
    userId: row.user_id,
    displayName: row.display_name,
    weightKg: row.weight_kg !== null ? Number(row.weight_kg) : null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function toDbProfile(domain: UserProfile): ProfileInsert {
  return {
    user_id: domain.userId,
    display_name: domain.displayName ?? null,
    weight_kg: domain.weightKg ?? null,
  };
}

export function toDomainActivity(row: ActivityRow): Activity {
  return {
    id: row.id,
    userId: row.user_id,
    type: row.type,
    occurredOn: row.occurred_on,
    startedAt: row.started_at,
    durationSeconds: row.duration_seconds,
    dayId: row.day_id,
    blocksCompleted: row.blocks_completed,
    roundsTotal: row.rounds_total,
    distanceKm: row.distance_km !== null ? Number(row.distance_km) : null,
    runLocation: row.run_location,
    feeling: row.feeling,
    caloriesKcal: row.calories_kcal !== null ? Number(row.calories_kcal) : null,
    xpEarned: row.xp_earned,
    createdAt: row.created_at,
  };
}

export function toDbActivity(domain: Activity, userId: string): ActivityInsert {
  return {
    id: domain.id,
    user_id: domain.userId ?? userId,
    type: domain.type,
    occurred_on: domain.occurredOn,
    started_at: domain.startedAt ?? null,
    duration_seconds: domain.durationSeconds,
    day_id: domain.dayId ?? null,
    blocks_completed: domain.blocksCompleted ?? null,
    rounds_total: domain.roundsTotal ?? null,
    distance_km: domain.distanceKm ?? null,
    run_location: domain.runLocation ?? null,
    feeling: domain.feeling ?? null,
    calories_kcal: domain.caloriesKcal ?? null,
    xp_earned: domain.xpEarned,
  };
}

export function toDomainAchievement(row: AchievementRow): AchievementUnlock {
  return {
    userId: row.user_id,
    achievementId: row.achievement_id,
    unlockedAt: row.unlocked_at,
  };
}

export function toDbAchievement(domain: AchievementUnlock, userId: string): AchievementInsert {
  return {
    user_id: domain.userId ?? userId,
    achievement_id: domain.achievementId,
    unlocked_at: domain.unlockedAt,
  };
}

export function toDomainVacation(row: VacationRow): VacationPeriod {
  return {
    id: row.id,
    userId: row.user_id,
    startOn: row.start_on,
    endOn: row.end_on,
    createdAt: row.created_at,
  };
}

export function toDbVacation(domain: VacationPeriod, userId: string): VacationInsert {
  return {
    id: domain.id,
    user_id: domain.userId ?? userId,
    start_on: domain.startOn,
    end_on: domain.endOn ?? null,
  };
}
