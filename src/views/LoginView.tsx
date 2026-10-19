import React, { useState } from 'react';
import { Zap, LogIn, Loader2, AlertCircle } from 'lucide-react';
import { signIn } from '../lib/supabase';

export const LoginView: React.FC = () => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (submitting) return;
    setError(null);
    setSubmitting(true);
    try {
      await signIn(username, password);
      // onAuthStateChange pasa a "signedIn" y AuthGate muestra la app.
    } catch (err) {
      setError(err instanceof Error ? err.message : 'No se pudo iniciar sesión.');
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-black text-white flex items-center justify-center px-4 pt-safe pb-safe">
      <div className="w-full max-w-sm space-y-6">
        <div className="text-center space-y-3">
          <div className="w-14 h-14 rounded-2xl bg-cardio-primary/15 border border-cardio-primary/40 flex items-center justify-center text-cardio-primary mx-auto">
            <Zap className="w-7 h-7 fill-cardio-primary" />
          </div>
          <div>
            <h1 className="text-2xl font-extrabold tracking-tight">CardioFeliz</h1>
            <p className="text-xs text-zinc-400 mt-1">Ingresá con tu usuario de siempre</p>
          </div>
        </div>

        <form
          onSubmit={handleSubmit}
          className="rounded-2xl border border-zinc-800 bg-surface-900 p-4 space-y-4"
        >
          <div className="space-y-1.5">
            <label htmlFor="login-username" className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Usuario
            </label>
            <input
              id="login-username"
              type="text"
              inputMode="text"
              autoComplete="username"
              autoCapitalize="none"
              autoCorrect="off"
              spellCheck={false}
              required
              maxLength={64}
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              disabled={submitting}
              className="w-full rounded-xl bg-black border border-zinc-700 px-3 py-3 text-base text-white placeholder-zinc-600 focus:outline-none focus:border-cardio-primary disabled:opacity-60"
            />
          </div>

          <div className="space-y-1.5">
            <label htmlFor="login-password" className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">
              Contraseña
            </label>
            <input
              id="login-password"
              type="password"
              autoComplete="current-password"
              required
              maxLength={256}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={submitting}
              className="w-full rounded-xl bg-black border border-zinc-700 px-3 py-3 text-base text-white placeholder-zinc-600 focus:outline-none focus:border-cardio-primary disabled:opacity-60"
            />
          </div>

          {error && (
            <div
              role="alert"
              className="flex items-center gap-2 rounded-xl border border-red-500/40 bg-red-950/40 px-3 py-2 text-xs font-semibold text-red-300"
            >
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <button
            type="submit"
            disabled={submitting || username.trim() === '' || password === ''}
            className="w-full py-3.5 rounded-2xl bg-gradient-to-r from-cardio-primary to-emerald-400 text-black font-extrabold text-sm flex items-center justify-center gap-2 active:scale-[0.98] transition-all disabled:opacity-50 disabled:active:scale-100"
          >
            {submitting ? <Loader2 className="w-4 h-4 animate-spin" /> : <LogIn className="w-4 h-4" />}
            <span>{submitting ? 'Ingresando…' : 'Ingresar'}</span>
          </button>
        </form>

        <p className="text-center text-[11px] text-zinc-500">
          Es el mismo usuario y contraseña que usás en PlanDental.
        </p>
      </div>
    </div>
  );
};
