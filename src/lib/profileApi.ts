import { supabase } from './supabase';

/** Lee el peso guardado en cf_profiles. null si no hay fila o no tiene peso. Lanza ante error. */
export async function fetchWeightKg(userId: string): Promise<number | null> {
  if (!supabase) throw new Error('Supabase no configurado');
  const { data, error } = await supabase
    .from('cf_profiles')
    .select('weight_kg')
    .eq('user_id', userId)
    .maybeSingle();
  if (error) throw error;
  return data?.weight_kg != null ? Number(data.weight_kg) : null;
}

/**
 * Guarda solo el peso. No envía display_name, así que no pisa el nombre existente.
 * Crea la fila si no existe. Lanza ante error.
 */
export async function pushWeightKg(userId: string, weightKg: number): Promise<void> {
  if (!supabase) throw new Error('Supabase no configurado');
  const { error } = await supabase
    .from('cf_profiles')
    .upsert({ user_id: userId, weight_kg: weightKg }, { onConflict: 'user_id' });
  if (error) throw error;
}
