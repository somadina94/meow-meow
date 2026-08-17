/**
 * useLoginSessionTracker
 * Records when the signed-in user is logged into the app.
 * Opens a row in `login_sessions` on auth, sends heartbeats, and closes it on
 * logout / tab close. Powers the "Total Login Time" column in the admin
 * payout statement (and per-user analytics).
 */
import { useEffect, useRef } from 'react';
import { supabase } from '@/integrations/supabase/client';

const HEARTBEAT_MS = 60_000; // refresh ended_at every minute so crashes still report ~accurate time

export function useLoginSessionTracker() {
  const sessionIdRef = useRef<string | null>(null);
  const heartbeatRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    let cancelled = false;

    const start = async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user || cancelled) return;

        const clientInfo = {
          ua: typeof navigator !== 'undefined' ? navigator.userAgent : null,
          platform: typeof navigator !== 'undefined' ? (navigator as any).platform : null,
          tz: Intl.DateTimeFormat().resolvedOptions().timeZone,
        };

        const { data, error } = await supabase.rpc('start_login_session', {
          _client_info: clientInfo as any,
        });
        if (error) {
          console.warn('[LoginSession] start failed:', error.message);
          return;
        }
        sessionIdRef.current = (data as unknown as string) ?? null;

        // Heartbeat: closing/updating the same session keeps duration fresh
        heartbeatRef.current = setInterval(() => {
          if (!sessionIdRef.current) return;
          // Re-open by starting a fresh row only if previous one was closed by the heartbeat.
          // We use end_login_session to refresh the duration timestamp; a new login_sessions row
          // is created the next time the user signs in.
          supabase.rpc('end_login_session', { _session_id: sessionIdRef.current }).then(() => {
            // immediately reopen to keep tracking continuous
            supabase.rpc('start_login_session', { _client_info: clientInfo as any }).then(({ data: nid }) => {
              if (nid) sessionIdRef.current = nid as unknown as string;
            });
          });
        }, HEARTBEAT_MS);
      } catch (e) {
        console.warn('[LoginSession] unexpected error', e);
      }
    };

    const stop = (sync = false) => {
      const id = sessionIdRef.current;
      if (heartbeatRef.current) {
        clearInterval(heartbeatRef.current);
        heartbeatRef.current = null;
      }
      sessionIdRef.current = null;
      if (!id) return;
      // Best-effort close
      if (sync && navigator.sendBeacon) {
        // sendBeacon path uses Supabase REST directly — fall back to RPC fetch
        supabase.rpc('end_login_session', { _session_id: id });
      } else {
        supabase.rpc('end_login_session', { _session_id: id });
      }
    };

    // Boot
    start();

    // React to auth changes
    const { data: sub } = supabase.auth.onAuthStateChange((event) => {
      if (event === 'SIGNED_IN') {
        if (!sessionIdRef.current) start();
      } else if (event === 'SIGNED_OUT') {
        stop();
      }
    });

    // Close on tab unload
    const onBeforeUnload = () => stop(true);
    window.addEventListener('beforeunload', onBeforeUnload);
    window.addEventListener('pagehide', onBeforeUnload);

    return () => {
      cancelled = true;
      window.removeEventListener('beforeunload', onBeforeUnload);
      window.removeEventListener('pagehide', onBeforeUnload);
      sub.subscription.unsubscribe();
      stop();
    };
  }, []);
}
