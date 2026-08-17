import { createContext, useContext, useEffect, useRef, useCallback, useState } from 'react';

interface UserActivityContextValue {
  /** Timestamp of last user activity */
  lastActivityTime: number;
  /** Subscribe to activity events. Returns unsubscribe function. */
  subscribe: (callback: () => void) => () => void;
}

const UserActivityContext = createContext<UserActivityContextValue | null>(null);

const ACTIVITY_EVENTS = ['mousedown', 'mousemove', 'keydown', 'scroll', 'touchstart', 'click'] as const;
const THROTTLE_MS = 5000; // 5s throttle — matches both existing implementations

export const UserActivityProvider = ({ children }: { children: React.ReactNode }) => {
  const subscribersRef = useRef<Set<() => void>>(new Set());
  const lastActivityRef = useRef(Date.now());
  // Use ref instead of state to avoid tree-wide re-renders every 5s
  const [lastActivityTime] = useState(() => Date.now());
  const lastActivityTimeRef = useRef(lastActivityTime);

  const subscribe = useCallback((callback: () => void) => {
    subscribersRef.current.add(callback);
    return () => { subscribersRef.current.delete(callback); };
  }, []);

  useEffect(() => {
    let lastEventTime = 0;

    const handleActivity = () => {
      const now = Date.now();
      if (now - lastEventTime < THROTTLE_MS) return;
      lastEventTime = now;
      lastActivityRef.current = now;
      lastActivityTimeRef.current = now;
      subscribersRef.current.forEach(cb => cb());
    };

    ACTIVITY_EVENTS.forEach(event => {
      document.addEventListener(event, handleActivity, { passive: true });
    });

    const handleVisibility = () => {
      if (document.visibilityState === 'visible') {
        handleActivity();
      }
    };
    document.addEventListener('visibilitychange', handleVisibility);

    return () => {
      ACTIVITY_EVENTS.forEach(event => {
        document.removeEventListener(event, handleActivity);
      });
      document.removeEventListener('visibilitychange', handleVisibility);
    };
  }, []);

  // Stable context value — never changes identity, avoids consumer re-renders
  const valueRef = useRef({ lastActivityTime, subscribe });
  valueRef.current.lastActivityTime = lastActivityTimeRef.current;

  return (
    <UserActivityContext.Provider value={valueRef.current}>
      {children}
    </UserActivityContext.Provider>
  );
};

export const useUserActivity = () => {
  const ctx = useContext(UserActivityContext);
  if (!ctx) throw new Error('useUserActivity must be used within UserActivityProvider');
  return ctx;
};
