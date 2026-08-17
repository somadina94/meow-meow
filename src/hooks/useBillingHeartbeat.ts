/**
 * useBillingHeartbeat — drop-in per-minute billing for chat/audio/video.
 * For private group calls use useGroupCallHeartbeat instead.
 *
 * Tracks a session-local minute index (persisted in sessionStorage) so the
 * man is never double-charged across tab restarts within the same UTC minute
 * AND never charged twice for the same elapsed minute when restart spans a
 * minute boundary. See audit Issue #13.
 */
import { useEffect, useRef } from 'react';
import { billMinute, type SessionType } from '@/services/billing.service';

interface HeartbeatOptions {
  sessionId: string;
  sessionType: SessionType;
  manId: string;
  womanId: string;
  intervalMs?: number;
  enabled?: boolean;
  onInsufficientBalance?: () => void;
  onError?: (msg: string) => void;
}

const storageKey = (sessionId: string, sessionType: SessionType) =>
  `billing:hb:${sessionType}:${sessionId}`;

export function useBillingHeartbeat({
  sessionId, sessionType, manId, womanId,
  intervalMs = 60_000, enabled = true,
  onInsufficientBalance, onError,
}: HeartbeatOptions) {
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const minuteRef = useRef<number>(0);

  useEffect(() => {
    if (!enabled || !sessionId || !manId || !womanId) return;

    // Resume the per-session counter across tab restarts.
    try {
      const persisted = sessionStorage.getItem(storageKey(sessionId, sessionType));
      minuteRef.current = persisted ? Math.max(0, parseInt(persisted, 10) || 0) : 0;
    } catch {
      minuteRef.current = 0;
    }

    const tick = async () => {
      const idx = minuteRef.current;
      const r = await billMinute(sessionId, sessionType, 1.0, manId, womanId, 1, idx);
      if (r.success && !r.duplicate_skipped) {
        minuteRef.current = idx + 1;
        try { sessionStorage.setItem(storageKey(sessionId, sessionType), String(minuteRef.current)); } catch { /* ignore */ }
      } else if (r.duplicate_skipped) {
        // Duplicate — advance counter so the next tick uses the next minute.
        minuteRef.current = idx + 1;
        try { sessionStorage.setItem(storageKey(sessionId, sessionType), String(minuteRef.current)); } catch { /* ignore */ }
      } else if (r.error?.includes('Insufficient balance')) {
        onInsufficientBalance?.();
      } else {
        onError?.(r.error ?? 'Billing error');
      }
    };
    timerRef.current = setInterval(tick, intervalMs);
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sessionId, sessionType, manId, womanId, intervalMs, enabled]);
}
