/**
 * useMiniChatBilling — chat billing via unified billing.service.
 * Billing starts only after both parties have replied, then any started minute
 * is charged as a full minute with idempotent minute indexes.
 */
import { useEffect, useRef, useState, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { billChatMinute } from '@/services/billing.service';

interface UseMiniChatBillingProps {
  chatId: string | null;
  isActive: boolean;
  onInsufficientBalance?: () => void;
  sessionId?: string | null;
  manId?: string;       // auth user_id of the paying man (RPC resolves if profile.id is passed)
  womanId?: string;     // auth user_id of the earning woman (RPC resolves if profile.id is passed)
  sessionType?: 'chat' | 'audio_call' | 'video_call'; // unused — chat only
  activitySignal?: unknown;
}

const MUTUAL_REPLY_WINDOW_MS = 2 * 60 * 1000;
const MUTUAL_IDLE_PAUSE_MS = 2 * 60 * 1000;

export function useMiniChatBilling({
  chatId,
  isActive,
  onInsufficientBalance,
  sessionId,
  manId,
  womanId,
}: UseMiniChatBillingProps) {
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const gateRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const startTimeRef = useRef<number>(0);
  const minuteOffsetRef = useRef<number>(0);
  const billedThisPeriodRef = useRef<number>(0);
  const billingActiveRef = useRef(false);
  const billingInProgressRef = useRef(false);
  const valuesRef = useRef({ chatId, sessionId, manId, womanId, onInsufficientBalance });
  const [minutesBilled, setMinutesBilled] = useState(0);
  const [totalCharged, setTotalCharged] = useState(0);
  const [isBilling, setIsBilling] = useState(false);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);

  valuesRef.current = { chatId, sessionId, manId, womanId, onInsufficientBalance };

  const reset = useCallback(() => {
    setMinutesBilled(0);
    setTotalCharged(0);
    setElapsedSeconds(0);
  }, []);

  const clearBillingTimer = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  const billOneMinute = useCallback(async (minuteIndex: number) => {
    const { sessionId: sId, chatId: cId, manId: mId, womanId: wId, onInsufficientBalance: onLowBalance } = valuesRef.current;
    const billingSession = sId || cId;
    if (!billingSession || !mId || !wId || billingInProgressRef.current) return;

    billingInProgressRef.current = true;
    try {
      const r = await billChatMinute(billingSession, 1.0, mId, wId, minuteIndex);
      if (r.success && !r.duplicate_skipped) {
        setMinutesBilled(m => m + 1);
        setTotalCharged(t => t + (r.charged ?? 0));
      } else if (r.error?.includes('Insufficient balance')) {
        onLowBalance?.();
      }
    } finally {
      billingInProgressRef.current = false;
    }
  }, []);

  const stopBillingTimers = useCallback(async () => {
    if (!billingActiveRef.current) return;

    clearBillingTimer();
    billingActiveRef.current = false;
    setIsBilling(false);

    const elapsedSec = Math.floor((Date.now() - startTimeRef.current) / 1000);
    if (elapsedSec >= 1) {
      const fullMinutes = Math.floor(elapsedSec / 60);
      const leftoverSec = elapsedSec - fullMinutes * 60;
      if (leftoverSec >= 1 || billedThisPeriodRef.current === 0) {
        await billOneMinute(minuteOffsetRef.current + billedThisPeriodRef.current);
      }
    }
  }, [billOneMinute, clearBillingTimer]);

  const startBillingTimers = useCallback(async () => {
    if (billingActiveRef.current) return;
    const { sessionId: sId, chatId: cId } = valuesRef.current;
    let sessionStartedAt = Date.now();

    if (sId) {
      const { data } = await supabase
        .from('active_chat_sessions')
        .select('started_at')
        .eq('id', sId)
        .maybeSingle();
      sessionStartedAt = data?.started_at ? new Date(data.started_at).getTime() : sessionStartedAt;
    } else if (cId) {
      const { data } = await supabase
        .from('active_chat_sessions')
        .select('started_at')
        .eq('chat_id', cId)
        .in('status', ['active', 'billing_paused'])
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      sessionStartedAt = data?.started_at ? new Date(data.started_at).getTime() : sessionStartedAt;
    }


    minuteOffsetRef.current = Math.max(0, Math.floor((Date.now() - sessionStartedAt) / 60_000));
    billedThisPeriodRef.current = 0;
    startTimeRef.current = Date.now();
    billingActiveRef.current = true;
    setElapsedSeconds(0);
    setIsBilling(true);

    timerRef.current = setInterval(() => {
      const elapsed = Math.floor((Date.now() - startTimeRef.current) / 1000);
      setElapsedSeconds(elapsed);
      if (elapsed >= (billedThisPeriodRef.current + 1) * 60) {
        const minuteIndex = minuteOffsetRef.current + billedThisPeriodRef.current;
        billedThisPeriodRef.current += 1;
        void billOneMinute(minuteIndex);
      }
    }, 1000);
  }, [billOneMinute]);

  useEffect(() => {
    const checkBillingGate = async () => {
      const { chatId: cId, manId: mId, womanId: wId } = valuesRef.current;
      if (!isActive || !cId || !mId || !wId) {
        await stopBillingTimers();
        return;
      }

      const [{ data: manMessages }, { data: womanMessages }, { data: presence }] = await Promise.all([
        supabase.from('chat_messages').select('created_at').eq('chat_id', cId).eq('sender_id', mId).order('created_at', { ascending: false }).limit(1),
        supabase.from('chat_messages').select('created_at').eq('chat_id', cId).eq('sender_id', wId).order('created_at', { ascending: false }).limit(1),
        supabase.from('user_status').select('user_id, is_online').in('user_id', [mId, wId]),
      ]);

      const manLast = manMessages?.[0]?.created_at ? new Date(manMessages[0].created_at).getTime() : 0;
      const womanLast = womanMessages?.[0]?.created_at ? new Date(womanMessages[0].created_at).getTime() : 0;
      const bothReplied = manLast > 0 && womanLast > 0;
      const now = Date.now();
      const replyGapOk = bothReplied && Math.abs(manLast - womanLast) <= MUTUAL_REPLY_WINDOW_MS;
      const bothIdle = bothReplied && now - manLast >= MUTUAL_IDLE_PAUSE_MS && now - womanLast >= MUTUAL_IDLE_PAUSE_MS;
      const onlineMap = new Map((presence ?? []).map((p: any) => [p.user_id, !!p.is_online]));
      const bothOnline = (onlineMap.get(mId) ?? false) && (onlineMap.get(wId) ?? false);

      if (bothReplied && replyGapOk && !bothIdle && bothOnline) {
        await startBillingTimers();
      } else {
        await stopBillingTimers();
      }
    };

    void checkBillingGate();
    gateRef.current = setInterval(() => void checkBillingGate(), 1000);

    return () => {
      if (gateRef.current) {
        clearInterval(gateRef.current);
        gateRef.current = null;
      }
      void stopBillingTimers();
    };
  }, [isActive, startBillingTimers, stopBillingTimers]);

  return { minutesBilled, totalCharged, isBilling, elapsedSeconds, reset, stopBillingTimers };
}

export default useMiniChatBilling;

