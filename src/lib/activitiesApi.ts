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
 * Sube una actividad (alta o edición). Idempotente: el mismo id con el mismo contenido
 * deja la fila igual, así que reintentar nunca duplica. Lanza ante cualquier error.
 */
export async function pushActivity(activity: Activity, userId: string): Promise<void> {
  if (!supabase) throw new Error('Supabase no configurado');
  const { error } = await supabase
    .from('cf_activities')
    .upsert(toDbActivity(activity, userId), { onConflict: 'id' });
  if (error) throw error;
}

/** Borra una actividad. Si ya no existe no es un error. Lanza ante cualquier otro error. */
export async function deleteActivityRemote(id: string): Promise<void> {
  if (!supabase) throw new Error('Supabase no configurado');
  const { error } = await supabase.from('cf_activities').delete().eq('id', id);
  if (error) throw error;
}
