import React, { Fragment } from 'react';
import { Loader2, ServerOff } from 'lucide-react';
import { useAuthState } from '../auth/AuthContext';
import { LoginView } from '../views/LoginView';

/**
 * Exige sesión: sin sesión muestra el login. Los hijos se remontan al cambiar de usuario
 * para que cada usuario lea solo su propio progreso local.
 */
export const AuthGate: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const state = useAuthState();

  if (state.status === 'loading') {
    return (
      <div
        className="min-h-screen bg-black flex items-center justify-center text-cardio-primary"
        role="status"
        aria-label="Cargando"
      >
        <Loader2 className="w-6 h-6 animate-spin" />
      </div>
    );
  }

  if (state.status === 'unconfigured') {
    return (
      <div className="min-h-screen bg-black text-white flex items-center justify-center px-6 text-center">
        <div className="space-y-3 max-w-xs">
          <ServerOff className="w-8 h-8 text-zinc-500 mx-auto" />
          <h1 className="text-lg font-bold">Servicio no configurado</h1>
          <p className="text-xs text-zinc-400">
            Falta la configuración de conexión de la app. Avisá a quien la administra.
          </p>
        </div>
      </div>
    );
  }

  if (state.status === 'signedOut') {
    return <LoginView />;
  }

  return <Fragment key={state.userId}>{children}</Fragment>;
};
