import { createClient, type SupabaseClient, type Session } from '@supabase/supabase-js';
import type { Database } from '../types/database';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim();
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim();

/**
 * Valida si las variables de entorno para Supabase están configuradas y son válidas.
 */
function isValidConfig(url?: string, key?: string): boolean {
  if (!url || !key) return false;
  try {
    const parsed = new URL(url);
    // Debe usar protocolo seguro HTTPS, excepto en desarrollo local
    const isLocalhost = parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1';
    return (parsed.protocol === 'https:' || (parsed.protocol === 'http:' && isLocalhost)) && key.length > 20;
  } catch {
    return false;
  }
}

export const isConfigured = isValidConfig(supabaseUrl, supabaseAnonKey);

/**
 * Cliente tipado de Supabase. Es `null` cuando no hay variables de entorno configuradas
 * para permitir funcionamiento 100% local sin fallar.
 */
export const supabase: SupabaseClient<Database> | null = isConfigured
  ? createClient<Database>(supabaseUrl!, supabaseAnonKey!, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: false,
      },
    })
  : null;

/**
 * Retorna true si Supabase está listo para ser utilizado en el entorno actual.
 */
export function isSupabaseConfigured(): boolean {
  return isConfigured && supabase !== null;
}

// ============================================================================
// AUTENTICACIÓN COMPARTIDA CON PLANDENTAL
// Mismo proyecto Supabase, mismos usuarios y contraseñas.
// El usuario ingresa un "username"; internamente Supabase Auth lo guarda como
// <username>@app.local (misma convención que PlanDental).
// ============================================================================

export interface AuthProfile {
  id: string;
  username: string;
  role: string;
}

const USERNAME_PATTERN = /^[a-z0-9._-]{1,64}$/;

function usernameToEmail(username: string): string {
  return `${username.toLowerCase().trim()}@app.local`;
}

/**
 * Inicia sesión con usuario + contraseña (mismas credenciales que PlanDental).
 * Lanza un Error con mensaje genérico ante cualquier falla de credenciales.
 */
export async function signIn(username: string, password: string): Promise<Session> {
  if (!supabase) throw new Error('El servicio no está disponible.');

  const normalized = username.toLowerCase().trim();
  if (!USERNAME_PATTERN.test(normalized) || password.length === 0 || password.length > 256) {
    throw new Error('Usuario o contraseña incorrectos.');
  }

  const { data, error } = await supabase.auth.signInWithPassword({
    email: usernameToEmail(normalized),
    password,
  });
  if (error || !data.session) {
    throw new Error('Usuario o contraseña incorrectos.');
  }
  return data.session;
}

export async function signOut(): Promise<void> {
  if (!supabase) return;
  await supabase.auth.signOut();
}

/**
 * Devuelve la sesión persistida (si existe) sin crear ninguna sesión nueva.
 * Si Supabase no está configurado o hay un error de red, retorna null.
 */
export async function getSession(): Promise<Session | null> {
  if (!supabase) return null;
  try {
    const { data, error } = await supabase.auth.getSession();
    if (error) return null;
    return data.session ?? null;
  } catch {
    return null;
  }
}

/**
 * Obtiene el ID del usuario autenticado, o null si no hay sesión.
 */
export async function getCurrentUserId(): Promise<string | null> {
  const session = await getSession();
  return session?.user?.id ?? null;
}

/**
 * Lee el perfil compartido (public.profiles de PlanDental) en modo SOLO LECTURA.
 * CardioFeliz nunca escribe en esa tabla.
 * Si no se puede leer, devuelve un perfil sintético a partir del email del usuario.
 */
export async function getAuthProfile(session: Session): Promise<AuthProfile> {
  const fallback: AuthProfile = {
    id: session.user.id,
    username: session.user.email?.split('@')[0] ?? 'usuario',
    role: 'user',
  };
  if (!supabase) return fallback;

  try {
    const { data, error } = await supabase
      .from('profiles' as never)
      .select('id, username, role')
      .eq('id', session.user.id)
      .single();
    if (error || !data) return fallback;
    return data as unknown as AuthProfile;
  } catch {
    return fallback;
  }
}

/**
 * Suscripción a cambios de autenticación. Devuelve la función para cancelar.
 */
export function onAuthChange(callback: (event: string, session: Session | null) => void): () => void {
  if (!supabase) return () => {};
  const { data } = supabase.auth.onAuthStateChange((event, session) => callback(event, session));
  return () => data.subscription.unsubscribe();
}
