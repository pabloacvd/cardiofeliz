import { supabase } from './supabase';

export interface RemoteRoutine {
  data: unknown;
  updatedAt: string;
}

/**
 * Lee la rutina personalizada del usuario en cf_routines.
 * Retorna { data, updatedAt } o null si no hay fila guardada.
 * Lanza ante error de base de datos o red.
 */
export async function fetchRoutine(userId: string): Promise<RemoteRoutine | null> {
  if (!supabase) throw new Error('Supabase no configurado');
  const { data, error } = await supabase
    .from('cf_routines')
    .select('data, updated_at')
    .eq('user_id', userId)
    .maybeSingle();

  if (error) throw error;
  if (!data) return null;

  return {
    data: data.data,
    updatedAt: data.updated_at,
  };
}

/**
 * Guarda o actualiza la rutina del usuario en cf_routines (upsert por user_id).
 * Retorna el updated_at asignado por la base de datos.
 * Lanza ante error.
 */
export async function pushRoutine(userId: string, data: unknown): Promise<{ updatedAt: string }> {
  if (!supabase) throw new Error('Supabase no configurado');
  const { data: result, error } = await supabase
    .from('cf_routines')
    .upsert({ user_id: userId, data }, { onConflict: 'user_id' })
    .select('updated_at')
    .single();

  if (error) throw error;
  return { updatedAt: result.updated_at };
}

/**
 * Elimina la rutina personalizada del usuario en cf_routines.
 * Lanza ante error.
 */
export async function deleteRoutineRemote(userId: string): Promise<void> {
  if (!supabase) throw new Error('Supabase no configurado');
  const { error } = await supabase.from('cf_routines').delete().eq('user_id', userId);
  if (error) throw error;
}
