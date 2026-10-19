import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { isSupabaseConfigured, onAuthChange, signOut as supabaseSignOut, supabase } from '../lib/supabase';
import { migrateLegacyStorage } from '../utils/userStorage';

export interface CurrentUser {
  userId: string;
  username: string;
  displayName: string;
  signOut: () => Promise<void>;
}

type AuthState =
  | { status: 'loading' }
  | { status: 'unconfigured' }
  | { status: 'signedOut' }
  | { status: 'signedIn'; userId: string; username: string };

interface AuthContextValue {
  state: AuthState;
  displayName: string | null;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function capitalize(value: string): string {
  return value.length > 0 ? value.charAt(0).toUpperCase() + value.slice(1) : value;
}

function usernameFromEmail(email: string | undefined): string {
  return email?.split('@')[0] ?? 'usuario';
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>(() =>
    isSupabaseConfigured() ? { status: 'loading' } : { status: 'unconfigured' },
  );
  const [displayName, setDisplayName] = useState<string | null>(null);

  // onAuthStateChange es la única fuente de verdad de la sesión (igual que en PlanDental).
  // Solo SIGNED_OUT / INITIAL_SESSION sin sesión muestran el login; otros eventos sin sesión son transitorios.
  useEffect(() => {
    if (!isSupabaseConfigured()) return;

    return onAuthChange((event, session) => {
      if (session) {
        migrateLegacyStorage(session.user.id);
        const username = usernameFromEmail(session.user.email);
        setState((prev) =>
          prev.status === 'signedIn' && prev.userId === session.user.id
            ? prev
            : { status: 'signedIn', userId: session.user.id, username },
        );
      } else if (event === 'SIGNED_OUT' || event === 'INITIAL_SESSION') {
        setDisplayName(null);
        setState({ status: 'signedOut' });
      }
    });
  }, []);

  // Nombre para mostrar: cf_profiles.display_name (si existe). Se consulta fuera del callback de auth.
  const signedInUserId = state.status === 'signedIn' ? state.userId : null;
  useEffect(() => {
    if (!signedInUserId || !supabase) return;
    let active = true;
    supabase
      .from('cf_profiles')
      .select('display_name')
      .eq('user_id', signedInUserId)
      .maybeSingle()
      .then(({ data }) => {
        if (active) setDisplayName(data?.display_name?.trim() || null);
      })
      .then(undefined, () => {
        // sin conexión: se usa el nombre de usuario
      });
    return () => {
      active = false;
    };
  }, [signedInUserId]);

  return <AuthContext.Provider value={{ state, displayName }}>{children}</AuthContext.Provider>;
}

export function useAuthState(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuthState debe usarse dentro de AuthProvider');
  return ctx.state;
}

/**
 * Usuario autenticado. Solo debe usarse debajo de AuthGate (garantiza que hay sesión).
 */
export function useCurrentUser(): CurrentUser {
  const ctx = useContext(AuthContext);
  if (!ctx || ctx.state.status !== 'signedIn') {
    throw new Error('useCurrentUser requiere una sesión activa');
  }
  const { userId, username } = ctx.state;
  return {
    userId,
    username,
    displayName: ctx.displayName ?? capitalize(username),
    signOut: supabaseSignOut,
  };
}
