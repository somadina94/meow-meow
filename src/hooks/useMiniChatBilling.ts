/**
 * 1:1 chat billing (₹4/min man, ₹2/min woman).
 * The on-screen second counter is the source of truth for leftover settlement.
 */
import { useState, useEffect, useRef, useCallback } from 'react';
import { billChatMinute } from '@/services/billing.service';
import type { BillingResult } from '@/services/billing.service';

interface UseMiniChatBillingProps {
  sessionId: string | null;
  manId: string;
  womanId: string;
  isActive: boolean;
  paused?: boolean;
  userId?: string;
  chatId?: string;
  activitySignal?: unknown;
  onInsufficientBalance?: () => void;
  onCharged?: (charged: number) => void;
  onSettled?: (result: BillingResult | null, elapsedSeconds: number) => void;
}

export const useMiniChatBilling = ({
  sessionId,
  manId,
  womanId,
  isActive,
  paused = false,
  userId,
  onInsufficientBalance,
  onCharged,
  onSettled,
}: UseMiniChatBillingProps) => {
  const [minutesBilled, setMinutesBilled] = useState(0);
  const [totalCharged, setTotalCharged] = useState(0);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [isBilling, setIsBilling] = useState(false);
  const [skipReason, setSkipReason] = useState<string | null>(null);

  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const startRef = useRef<number | null>(null);
  const pausedMsRef = useRef(0);
  const pauseAtRef = useRef<number | null>(null);
  const inFlightRef = useRef(false);
  const settlingRef = useRef(false);
  const leftoverPromiseRef = useRef<Promise<void> | null>(null);
  const stopBillingTimersRef = useRef<() => Promise<void>>(async () => {});
  const billedRef = useRef(0);
  const elapsedRef = useRef(0);
  const runIdRef = useRef(0);
  const wasRunningRef = useRef(false);
  const pausedFlagRef = useRef(paused);
  const sessionIdRef = useRef(sessionId);
  const manIdRef = useRef(manId);
  const womanIdRef = useRef(womanId);
  const onInsufficientRef = useRef(onInsufficientBalance);
  const onChargedRef = useRef(onCharged);
  const onSettledRef = useRef(onSettled);

  pausedFlagRef.current = paused;
  if (sessionId) sessionIdRef.current = sessionId;
  if (manId) manIdRef.current = manId;
  if (womanId) womanIdRef.current = womanId;
  onInsufficientRef.current = onInsufficientBalance;
  onChargedRef.current = onCharged;
  onSettledRef.current = onSettled;

  const applyCharge = useCallback((result: BillingResult, reason: string) => {
    if (result.skipped === 'admin' || result.super_user_skip || result.skipped === 'waiting_for_replies' || result.skipped === 'not_answered') {
      setSkipReason(result.skipped === 'admin' || result.super_user_skip ? 'admin' : result.skipped || null);
      if (result.skipped === 'waiting_for_replies' || result.skipped === 'not_answered') {
        console.info('[billing] skipped until both parties engage', result);
      } else {
        console.warn('[billing] server returned skip', result);
      }
      return false;
    }
    if (result.duplicate_skipped) {
      console.info('[billing] duplicate minute skipped', reason, result);
      return false;
    }
    if (result.success) {
      const charged = Number(result.charged);
      if (!Number.isFinite(charged) || charged <= 0) {
        console.warn('[billing] success but charged ₹0', result);
        return false;
      }
      const amount = charged;
      billedRef.current += 1;
      setMinutesBilled(billedRef.current);
      setTotalCharged((prev) => prev + amount);
      setSkipReason(null);
      console.info(`[billing] charged ₹${amount} (${reason})`, result);
      onChargedRef.current?.(amount);
      return true;
    }
    if (result.error && /insufficient/i.test(result.error)) {
      onInsufficientRef.current?.();
    }
    console.error('[billing] charge failed:', result);
    return false;
  }, []);

  const readElapsed = useCallback(() => {
    if (elapsedRef.current > 0) return elapsedRef.current;
    const start = startRef.current;
    if (!start) return 0;
    const frozen = pauseAtRef.current ? Date.now() - pauseAtRef.current : 0;
    return Math.max(0, Math.floor((Date.now() - start - pausedMsRef.current - frozen) / 1000));
  }, []);

  const billOneMinute = useCallback(async (minuteIndex: number, reason: string) => {
    const sid = sessionIdRef.current;
    const mid = manIdRef.current;
    const wid = womanIdRef.current;
    if (!sid || !mid || !wid || inFlightRef.current) return false;
    inFlightRef.current = true;
    try {
      const result = await billChatMinute(sid, 1, mid, wid, runIdRef.current + minuteIndex);
      return applyCharge(result, reason);
    } catch (e) {
      console.error('[billing] charge error:', e);
      return false;
    } finally {
      inFlightRef.current = false;
    }
  }, [applyCharge]);

  const stopTicker = useCallback(() => {
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, []);

  const startTicker = useCallback((start: number) => {
    stopTicker();
    intervalRef.current = setInterval(() => {
      if (pausedFlagRef.current) return;
      const secs = Math.max(0, Math.floor((Date.now() - start - pausedMsRef.current) / 1000));
      elapsedRef.current = secs;
      setElapsedSeconds(secs);
      const due = Math.floor(secs / 60);
      if (due > billedRef.current) {
        void billOneMinute(billedRef.current, `minute ${due}`);
      }
    }, 1000);
  }, [billOneMinute, stopTicker]);

  const stopBillingTimers = useCallback(async () => {
    if (leftoverPromiseRef.current) return leftoverPromiseRef.current;
    leftoverPromiseRef.current = (async () => {
      if (settlingRef.current) return;
      settlingRef.current = true;
      stopTicker();
      if (pauseAtRef.current) {
        pausedMsRef.current += Date.now() - pauseAtRef.current;
        pauseAtRef.current = null;
      }
      const elapsed = readElapsed();
      const sid = sessionIdRef.current;
      const mid = manIdRef.current;
      const wid = womanIdRef.current;
      startRef.current = null;
      setIsBilling(false);
      console.info('[billing] settling leftover', { elapsed, sid, mid, wid });
      if (!sid || !mid || !wid || elapsed < 1) {
        onSettledRef.current?.(null, elapsed);
        return;
      }
      try {
        const idx = runIdRef.current + Math.floor(elapsed / 60);
        const result = await billChatMinute(sid, 1, mid, wid, idx);
        if (result) applyCharge(result, `leftover ${elapsed}s`);
        onSettledRef.current?.(result ?? null, elapsed);
      } catch (e) {
        console.error('[billing] leftover error:', e);
        onSettledRef.current?.({ success: false, error: e instanceof Error ? e.message : 'leftover failed' }, elapsed);
      }
    })();
    return leftoverPromiseRef.current;
  }, [applyCharge, readElapsed, stopTicker]);

  stopBillingTimersRef.current = stopBillingTimers;

  useEffect(() => {
    const canRun =
      isActive &&
      !!sessionId &&
      !!manId &&
      !!womanId &&
      (!userId || userId === manId);

    if (!canRun) {
      stopTicker();
      if (wasRunningRef.current) {
        wasRunningRef.current = false;
        void stopBillingTimersRef.current();
      }
      return;
    }

    wasRunningRef.current = true;

    settlingRef.current = false;
    leftoverPromiseRef.current = null;
    billedRef.current = 0;
    elapsedRef.current = 0;
    runIdRef.current = Math.floor(Date.now() / 1000);
    pausedMsRef.current = 0;
    pauseAtRef.current = null;
    setMinutesBilled(0);
    setTotalCharged(0);
    setElapsedSeconds(0);
    setSkipReason(null);

    const start = Date.now();
    startRef.current = start;
    setIsBilling(true);
    console.info('[billing] started', { sessionId, manId, womanId });
    startTicker(start);

    return () => {
      stopTicker();
    };
  }, [isActive, sessionId, manId, womanId, userId, startTicker, stopTicker]);

  useEffect(() => {
    if (!startRef.current) return;
    if (paused) {
      stopTicker();
      if (!pauseAtRef.current) pauseAtRef.current = Date.now();
      return;
    }
    if (pauseAtRef.current) {
      pausedMsRef.current += Date.now() - pauseAtRef.current;
      pauseAtRef.current = null;
    }
    if (!intervalRef.current && startRef.current && !settlingRef.current) {
      startTicker(startRef.current);
      setIsBilling(true);
    }
  }, [paused, startTicker, stopTicker]);

  return {
    minutesBilled,
    totalCharged,
    elapsedSeconds,
    isBilling,
    skipReason,
    stopBillingTimers,
  };
};
