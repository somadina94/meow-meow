/**
 * useGroupCallHeartbeat — bills each ACTIVE man individually every minute.
 * The list of activeManIds is read from a ref so the interval always uses
 * the current list (men joining/leaving mid-session).
 *
 * Woman earns group_woman_rate × number_of_men this tick (one credit row per man).
 */
import { useEffect, useRef } from 'react';
import { billGroupCallMinute } from '@/services/billing.service';

interface GroupHeartbeatOptions {
  groupId: string;
  womanId: string;
  activeManIds: string[];
  intervalMs?: number;
  enabled?: boolean;
  onManInsufficientBalance?: (manId: string) => void;
}

export function useGroupCallHeartbeat({
  groupId, womanId, activeManIds,
  intervalMs = 60_000, enabled = true,
  onManInsufficientBalance,
}: GroupHeartbeatOptions) {
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const menRef = useRef(activeManIds);
  menRef.current = activeManIds;

  useEffect(() => {
    if (!enabled || !groupId || !womanId) return;
    const tick = async () => {
      await Promise.all(menRef.current.map(async (manId) => {
        const r = await billGroupCallMinute(groupId, 1.0, manId, womanId);
        if (!r.success && r.error?.includes('Insufficient balance')) {
          onManInsufficientBalance?.(manId);
        }
      }));
    };
    timerRef.current = setInterval(tick, intervalMs);
    return () => { if (timerRef.current) clearInterval(timerRef.current); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [groupId, womanId, intervalMs, enabled]);
}
