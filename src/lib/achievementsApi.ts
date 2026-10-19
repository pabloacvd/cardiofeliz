import { supabase } from './supabase';
import { toDbAchievement, toDomainAchievement, type AchievementUnlock } from '../types/gamification';

/** Logros ya registrados del usuario (RLS limita a sus filas). Lanza ante error. */
export async function fetchAchievements(): Promise<AchievementUnlock[]> {
  if (!supabase) throw new Error('Supabase no configurado');
  const { data, error } = await supabase.from('cf_achievements').select('*');
  if (error) throw error;
  return data.map(toDomainAchievement);
}

/**
 * Registra logros. Idempotente: si ya existen se conservan tal cual (la fecha original no se pisa).
 * Lanza ante error.
 */
export async function pushAchievements(items: readonly AchievementUnlock[], userId: string): Promise<void> {
  if (!supabase || items.length === 0) {
    if (!supabase) throw new Error('Supabase no configurado');
    return;
  }
  const { error } = await supabase
    .from('cf_achievements')
    .upsert(items.map((i) => toDbAchievement(i, userId)), {
      onConflict: 'user_id,achievement_id',
      ignoreDuplicates: true,
    });
  if (error) throw error;
}
