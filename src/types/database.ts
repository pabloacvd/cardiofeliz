/**
 * Tipos de base de datos Supabase para CardioFeliz.
 * Representan la estructura exacta de las tablas de PostgreSQL.
 */

export type ActivityType = 'workout_day' | 'run' | 'active_rest';
export type RunLocation = 'cinta' | 'calle';
export type WorkoutDayId = 'dia_1' | 'dia_2' | 'dia_3';

export type ProfileRow = {
  user_id: string;
  display_name: string | null;
  weight_kg: number | null;
  created_at: string;
  updated_at: string;
};

export type ProfileInsert = {
  user_id: string;
  display_name?: string | null;
  weight_kg?: number | null;
  created_at?: string;
  updated_at?: string;
};

export type ProfileUpdate = {
  display_name?: string | null;
  weight_kg?: number | null;
  updated_at?: string;
};

export type ActivityRow = {
  id: string;
  user_id: string;
  type: ActivityType;
  occurred_on: string; // YYYY-MM-DD
  started_at: string | null; // ISO string
  duration_seconds: number;
  day_id: string | null;
  blocks_completed: number | null;
  rounds_total: number | null;
  distance_km: number | null;
  run_location: RunLocation | null;
  feeling: number | null; // 1 to 5
  calories_kcal: number | null;
  xp_earned: number;
  created_at: string;
};

export type ActivityInsert = {
  id: string;
  user_id: string;
  type: ActivityType;
  occurred_on: string; // YYYY-MM-DD
  started_at?: string | null;
  duration_seconds: number;
  day_id?: string | null;
  blocks_completed?: number | null;
  rounds_total?: number | null;
  distance_km?: number | null;
  run_location?: RunLocation | null;
  feeling?: number | null;
  calories_kcal?: number | null;
  xp_earned?: number;
  created_at?: string;
};

export type ActivityUpdate = {
  type?: ActivityType;
  occurred_on?: string;
  started_at?: string | null;
  duration_seconds?: number;
  day_id?: string | null;
  blocks_completed?: number | null;
  rounds_total?: number | null;
  distance_km?: number | null;
  run_location?: RunLocation | null;
  feeling?: number | null;
  calories_kcal?: number | null;
  xp_earned?: number;
};

export type AchievementRow = {
  user_id: string;
  achievement_id: string;
  unlocked_at: string; // ISO string
};

export type AchievementInsert = {
  user_id: string;
  achievement_id: string;
  unlocked_at?: string;
};

export type VacationRow = {
  id: string;
  user_id: string;
  start_on: string; // YYYY-MM-DD
  end_on: string | null; // YYYY-MM-DD (null = activo)
  created_at: string;
};

export type VacationInsert = {
  id?: string;
  user_id: string;
  start_on: string; // YYYY-MM-DD
  end_on?: string | null;
  created_at?: string;
};

export type VacationUpdate = {
  start_on?: string;
  end_on?: string | null;
};

/**
 * Esquema completo de la base de datos para tipar el cliente Supabase
 */
export interface Database {
  public: {
    Tables: {
      cf_profiles: {
        Row: ProfileRow;
        Insert: ProfileInsert;
        Update: ProfileUpdate;
        Relationships: [];
      };
      cf_activities: {
        Row: ActivityRow;
        Insert: ActivityInsert;
        Update: ActivityUpdate;
        Relationships: [];
      };
      cf_achievements: {
        Row: AchievementRow;
        Insert: AchievementInsert;
        Update: AchievementRow;
        Relationships: [];
      };
      cf_vacations: {
        Row: VacationRow;
        Insert: VacationInsert;
        Update: VacationUpdate;
        Relationships: [];
      };
    };
    Views: { [_ in never]: never };
    Functions: { [_ in never]: never };
    Enums: { [_ in never]: never };
    CompositeTypes: { [_ in never]: never };
  };
}
