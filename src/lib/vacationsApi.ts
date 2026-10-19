import { supabase } from './supabase';
import { toDbVacation, toDomainVacation, type VacationPeriod } from '../types/gamification';

/** Períodos de vacaciones del usuario. Lanza ante error. */
export async function fetchVacations(): Promise<VacationPeriod[]> {
  if (!supabase) throw new Error('Supabase no configurado');
  const { data, error } = await supabase
    .from('cf_vacations')
    .select('*')
    .order('start_on', { ascending: false });
  if (error) throw error;
  return data.map(toDomainVacation);
}

/** Guarda o actualiza un período de vacaciones. */
export async function pushVacation(vacation: VacationPeriod, userId: string): Promise<void> {
  if (!supabase) throw new Error('Supabase no configurado');
  const { error } = await supabase
    .from('cf_vacations')
    .upsert(toDbVacation(vacation, userId), { onConflict: 'id' });
  if (error) throw error;
}

/** Elimina un período de vacaciones por id. */
export async function deleteVacationRemote(id: string): Promise<void> {
  if (!supabase) throw new Error('Supabase no configurado');
  const { error } = await supabase.from('cf_vacations').delete().eq('id', id);
  if (error) throw error;
}
