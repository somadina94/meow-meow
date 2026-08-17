import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';

interface CircuitBreakerState {
  active: boolean;
  permanentlyDisabled: boolean;
  reason?: string;
  resumesAt?: string;
  loading: boolean;
}

const POLL_INTERVAL = 5 * 60_000; // 5 minutes — no need for aggressive polling

/**
 * Hook to check if video calls are disabled due to:
 * 1. High server resource utilization (circuit breaker - auto-resumes after 2h)
 * 2. Admin permanent disable toggle
 *
 * Reads directly from app_settings (RLS-protected, public read)
 * instead of invoking an edge function on every poll.
 */
export const useVideoCallCircuitBreaker = () => {
  const [state, setState] = useState<CircuitBreakerState>({
    active: false,
    permanentlyDisabled: false,
    loading: true,
  });

  const checkStatus = useCallback(async () => {
    try {
      // Query both settings directly from the DB — no edge function needed
      const { data: settings } = await supabase
        .from('app_settings')
        .select('setting_key, setting_value')
        .in('setting_key', [
          'video_call_circuit_breaker',
          'video_calls_permanently_disabled',
        ]);

      let active = false;
      let reason: string | undefined;
      let resumesAt: string | undefined;
      let permanentlyDisabled = false;

      for (const row of settings ?? []) {
        const val = typeof row.setting_value === 'string'
          ? (() => { try { return JSON.parse(row.setting_value); } catch { return row.setting_value; } })()
          : row.setting_value;

        if (row.setting_key === 'video_call_circuit_breaker' && val) {
          // Check if cooldown has passed (auto-resume logic)
          if (val.active && val.resumes_at) {
            const resumeTime = new Date(val.resumes_at).getTime();
            if (Date.now() >= resumeTime) {
              // Breaker expired — treat as inactive
              active = false;
            } else {
              active = true;
              reason = val.reason;
              resumesAt = val.resumes_at;
            }
          } else {
            active = val.active ?? false;
            reason = val.reason;
            resumesAt = val.resumes_at;
          }
        }

        if (row.setting_key === 'video_calls_permanently_disabled' && val) {
          permanentlyDisabled = val.disabled ?? false;
        }
      }

      setState({ active, permanentlyDisabled, reason, resumesAt, loading: false });
    } catch (err) {
      console.error('[CircuitBreaker] Check failed:', err);
      setState({ active: false, permanentlyDisabled: false, loading: false });
    }
  }, []);

  useEffect(() => {
    checkStatus();
    const interval = setInterval(checkStatus, POLL_INTERVAL);
    return () => clearInterval(interval);
  }, [checkStatus]);

  return {
    isVideoCallsDisabled: state.active || state.permanentlyDisabled,
    isPermanentlyDisabled: state.permanentlyDisabled,
    isCircuitBreakerActive: state.active,
    reason: state.permanentlyDisabled ? 'Permanently disabled by admin' : state.reason,
    resumesAt: state.resumesAt,
    loading: state.loading,
    refresh: checkStatus,
  };
};
