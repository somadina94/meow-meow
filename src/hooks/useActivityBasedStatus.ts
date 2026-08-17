import { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useUserActivity } from '@/contexts/UserActivityContext';
import { isSignedOut } from '@/hooks/useAuthReady';

interface UseActivityBasedStatusOptions {
  inactivityTimeout?: number;
  userId: string;
  onStatusChange?: (isOnline: boolean) => void;
}

export const useActivityBasedStatus = ({
  inactivityTimeout = 10 * 60 * 1000,
  userId,
  onStatusChange
}: UseActivityBasedStatusOptions) => {
  const [isOnline, setIsOnline] = useState(true);
  const [isManuallyOffline, setIsManuallyOffline] = useState(false);
  const inactivityTimerRef = useRef<NodeJS.Timeout | null>(null);
  const lastActivityRef = useRef<number>(Date.now());
  const lastDbUpdateRef = useRef<number>(0);
  const isOnlineRef = useRef(true);
  const isManuallyOfflineRef = useRef(false);
  const onStatusChangeRef = useRef(onStatusChange);
  const inactivityTimeoutRef = useRef(inactivityTimeout);

  isOnlineRef.current = isOnline;
  isManuallyOfflineRef.current = isManuallyOffline;
  onStatusChangeRef.current = onStatusChange;
  inactivityTimeoutRef.current = inactivityTimeout;

  const { subscribe } = useUserActivity();

  // LIGHTWEIGHT status update - only sets is_online + last_seen.
  const updateOnlineStatus = useCallback(async (online: boolean) => {
    if (!userId) return;

    const now = Date.now();
    if (online && now - lastDbUpdateRef.current < 20000) return;
    lastDbUpdateRef.current = now;

    try {
      await supabase
        .from('user_status')
        .upsert({
          user_id: userId,
          is_online: online,
          last_seen: new Date().toISOString(),
        }, { onConflict: 'user_id' });
    } catch (error) {
      console.error('Error updating online status:', error);
    }
  }, [userId]);

  const goOnline = useCallback(() => {
    if (isManuallyOfflineRef.current) return;
    if (!isOnlineRef.current) {
      isOnlineRef.current = true;
      setIsOnline(true);
      lastDbUpdateRef.current = 0;
      void updateOnlineStatus(true);
      onStatusChangeRef.current?.(true);
    }
    lastActivityRef.current = Date.now();
  }, [updateOnlineStatus]);

  const goOffline = useCallback(() => {
    if (isOnlineRef.current && !isManuallyOfflineRef.current) {
      isOnlineRef.current = false;
      setIsOnline(false);
      lastDbUpdateRef.current = 0;
      void updateOnlineStatus(false);
      onStatusChangeRef.current?.(false);
    }
  }, [updateOnlineStatus]);

  const toggleOnlineStatus = useCallback((online: boolean) => {
    isManuallyOfflineRef.current = !online;
    isOnlineRef.current = online;
    setIsManuallyOffline(!online);
    setIsOnline(online);
    lastDbUpdateRef.current = 0;
    void updateOnlineStatus(online);
    onStatusChangeRef.current?.(online);
    if (online) lastActivityRef.current = Date.now();
  }, [updateOnlineStatus]);

  const resetInactivityTimer = useCallback(() => {
    if (inactivityTimerRef.current) clearTimeout(inactivityTimerRef.current);
    if (isManuallyOfflineRef.current) return;
    goOnline();
    inactivityTimerRef.current = setTimeout(goOffline, inactivityTimeoutRef.current);
  }, [goOnline, goOffline]);

  // Subscribe once per userId. Do not depend on render-unstable parent callbacks —
  // that re-ran this effect, reset the write throttle, and looped Online refreshes.
  useEffect(() => {
    if (!userId) return;

    lastDbUpdateRef.current = 0;
    void updateOnlineStatus(true);
    resetInactivityTimer();

    const unsubscribe = subscribe(() => {
      resetInactivityTimer();
    });

    return () => {
      unsubscribe();
      if (inactivityTimerRef.current) clearTimeout(inactivityTimerRef.current);
    };
  }, [userId, resetInactivityTimer, subscribe, updateOnlineStatus]);

  // Set offline on unmount — only if user hasn't signed out
  useEffect(() => {
    return () => {
      if (userId && !isSignedOut()) {
        supabase.from('user_status').upsert({
          user_id: userId,
          is_online: false,
          last_seen: new Date().toISOString(),
        }, { onConflict: 'user_id' }).then(() => {}, () => {});
      }
    };
  }, [userId]);

  return { isOnline, isManuallyOffline, toggleOnlineStatus, goOnline, goOffline };
};
