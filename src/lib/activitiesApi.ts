import { supabase } from './supabase';
import { toDbActivity, toDomainActivity, type Activity } from '../types/gamification';

const PAGE_SIZE = 1000;

/** Descarga todo el historial del usuario (RLS limita a sus filas). Lanza ante cualquier error. */
export async function fetchAllActivities(): Promise<Activity[]> {
  if (!supabase) throw new Error('Supabase no configurado');

  const all: Activity[] = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await supabase
      .from('cf_activities')
      .select('*')
      .order('occurred_on', { ascending: false })
      .order('id')
      .range(from, from + PAGE_SIZE - 1);
    if (error) throw error;
    all.push(...data.map(toDomainActivity));
    if (data.length < PAGE_SIZE) break;
  }
  return all;
}

/**
 * Sube una actividad. Idempotente: si el id ya existe no se duplica ni se modifica
 * (las actividades no cambian una vez guardadas). Lanza ante cualquier error.
 */
export async function pushActivity(activity: Activity, userId: string): Promise<void> {
  if (!supabase) throw new Error('Supabase no configurado');
  const { error } = await supabase
    .from('cf_activities')
    .upsert(toDbActivity(activity, userId), { onConflict: 'id', ignoreDuplicates: true });
  if (error) throw error;
}
