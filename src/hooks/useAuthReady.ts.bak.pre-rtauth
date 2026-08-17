/**
 * Global singleton auth state hook.
 * 
 * Pattern: getSession() first, then onAuthStateChange for subsequent changes.
 * All components share one auth state — no conflicting session checks.
 */
import { useState, useEffect, useRef } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '@/integrations/supabase/client';
import { clearUserContextCache } from '@/hooks/useOptimizedAuth';

// Module-level sign-out flag — avoids polluting globalThis/window
let _signedOut = false;
export const setSignedOut = (v: boolean) => { _signedOut = v; };
export const isSignedOut = () => _signedOut;

interface AuthState {
  user: User | null;
  isReady: boolean;
  session: Session | null;
}

// ── Global singleton state ──────────────────────────────────────────
let globalState: AuthState = { user: null, isReady: false, session: null };
let listeners = new Set<(s: AuthState) => void>();
let initialized = false;

function broadcast(next: AuthState) {
  globalState = next;
  listeners.forEach(fn => fn(next));
}

function boot() {
  if (initialized) return;
  initialized = true;

  // 1) Restore session from storage FIRST — with timeout to prevent hanging
  const sessionPromise = supabase.auth.getSession().then(async ({ data: { session } }) => {
    // Validate restored token. If the server rejects it (e.g. bad_jwt /
    // "missing sub claim" after a key rotation or stale cloud token on a
    // self-hosted backend), sign out LOCALLY so the user sees a clean login
    // instead of being bounced from protected routes on every refresh.
    if (session?.access_token) {
      try {
        const { error } = await supabase.auth.getUser();
        if (error) {
          console.warn('[Auth] Restored session rejected by server, clearing locally:', error.message);
          try { await supabase.auth.signOut({ scope: 'local' } as any); } catch {}
          broadcast({ user: null, session: null, isReady: true });
          return;
        }
      } catch {
        // Network hiccup — keep the session optimistically; autoRefresh will retry.
      }
    }
    broadcast({ user: session?.user ?? null, session, isReady: true });
  }).catch(() => {
    broadcast({ user: null, session: null, isReady: true });
  });

  // Safety timeout: 12s for slow mobile networks (2G/3G), was 5s
  const timeout = setTimeout(() => {
    if (!globalState.isReady) {
      console.warn('[Auth] Session restore timed out after 12s, proceeding without session');
      broadcast({ user: null, session: null, isReady: true });
    }
  }, 12000);

  sessionPromise.finally(() => clearTimeout(timeout));

  // 2) Listen for subsequent changes (sign-in, sign-out, token refresh)
  //    IMPORTANT: no async work inside this callback
  supabase.auth.onAuthStateChange((_event, session) => {
    if (_event === 'SIGNED_OUT') {
      setSignedOut(true);
      clearUserContextCache();
    } else if (session?.user) {
      setSignedOut(false);
    }
    broadcast({ user: session?.user ?? null, session, isReady: true });
  });
}


// ── Hook ────────────────────────────────────────────────────────────
export function useAuthReady() {
  const [state, setState] = useState<AuthState>(globalState);
  const stateRef = useRef(state);

  useEffect(() => {
    const listener = (next: AuthState) => {
      // Only re-render if meaningful auth state changed
      const prev = stateRef.current;
      if (
        prev.isReady === next.isReady &&
        prev.user?.id === next.user?.id &&
        prev.session?.expires_at === next.session?.expires_at
      ) return;
      stateRef.current = next;
      setState(next);
    };

    listeners.add(listener);
    boot(); // no-op if already initialised

    // Sync with current global state in case boot() already finished
    if (globalState.isReady && !stateRef.current.isReady) {
      stateRef.current = globalState;
      setState(globalState);
    }

    return () => { listeners.delete(listener); };
  }, []);

  return { user: state.user, isReady: state.isReady, session: state.session };
}
