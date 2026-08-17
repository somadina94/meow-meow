/**
 * Session Priority Manager
 * 
 * Priority levels:
 *   P1 (Chat)          — lowest, never blocks anything, runs alongside calls
 *   P3 (Audio/Video/Private Group Call) — highest, mutually exclusive
 * 
 * Rules:
 * - Chat (P1) continues alongside any P3 session
 * - If user is in any P3 session, incoming audio/video calls are suppressed
 * - Private group calls have same P3 priority as audio/video calls
 * - All P3 sessions are mutually exclusive
 */

type SessionType = 'chat' | 'audio_call' | 'video_call' | 'private_group_call';

interface ActiveSession {
  type: SessionType;
  id: string;
  priority: number;
  startedAt: number;
}

const PRIORITY_MAP: Record<SessionType, number> = {
  chat: 1,
  audio_call: 3,
  video_call: 3,
  private_group_call: 3,
};

// Global mutable state (singleton across all components)
let activeSessions: ActiveSession[] = [];
let listeners: Set<() => void> = new Set();

const notify = () => {
  listeners.forEach((fn) => fn());
};

/**
 * Register an active session. Call this when a call/chat starts.
 */
export const registerSession = (type: SessionType, id: string) => {
  // Don't double-register
  if (activeSessions.some((s) => s.type === type && s.id === id)) return;
  activeSessions.push({
    type,
    id,
    priority: PRIORITY_MAP[type],
    startedAt: Date.now(),
  });
  console.log(`[SessionPriority] Registered ${type} session: ${id}`, getActiveSessions());
  notify();

  // Auto-cleanup stale P3 sessions after 2 hours (safety net)
  if (PRIORITY_MAP[type] >= 3) {
    setTimeout(() => {
      const idx = activeSessions.findIndex((s) => s.type === type && s.id === id);
      if (idx !== -1) {
        console.warn(`[SessionPriority] Auto-cleaning stale ${type} session: ${id}`);
        activeSessions.splice(idx, 1);
        notify();
      }
    }, 2 * 60 * 60 * 1000);
  }
};

/**
 * Unregister a session when it ends.
 */
export const unregisterSession = (type: SessionType, id?: string) => {
  if (id) {
    activeSessions = activeSessions.filter((s) => !(s.type === type && s.id === id));
  } else {
    // Remove all sessions of this type
    activeSessions = activeSessions.filter((s) => s.type !== type);
  }
  console.log(`[SessionPriority] Unregistered ${type} session${id ? `: ${id}` : ''}`, getActiveSessions());
  notify();
};

/**
 * Check if an incoming session of a given type should be allowed.
 * 
 * Returns true if the incoming session should be BLOCKED.
 */
export const shouldBlockIncoming = (incomingType: SessionType): boolean => {
  const incomingPriority = PRIORITY_MAP[incomingType];
  
  // Chat (P1) is never blocked
  if (incomingPriority === 1) return false;
  
  // Clean up stale P3 sessions older than 3 hours before checking
  const now = Date.now();
  const maxAge = 3 * 60 * 60 * 1000;
  const before = activeSessions.length;
  activeSessions = activeSessions.filter((s) => s.priority < 3 || (now - s.startedAt) < maxAge);
  if (activeSessions.length !== before) {
    console.warn('[SessionPriority] Cleaned stale P3 sessions during block check');
    notify();
  }
  
  // P3 incoming (audio/video/group call) — block if ANY P3 session is active
  const hasActiveP3 = activeSessions.some((s) => s.priority >= 3);
  if (hasActiveP3) {
    console.log('[SessionPriority] Blocking incoming', incomingType, '— active P3 sessions:', 
      activeSessions.filter(s => s.priority >= 3).map(s => `${s.type}:${s.id}`));
  }
  return hasActiveP3;
};

/**
 * Check if user currently has an active P3 session (call of any type).
 */
export const hasActiveCall = (): boolean => {
  return activeSessions.some((s) => s.priority >= 3);
};

/**
 * Get all active sessions (for debugging/display).
 */
export const getActiveSessions = (): ActiveSession[] => {
  return [...activeSessions];
};

/**
 * Clear all P3 sessions (safety reset). Call on logout or major navigation.
 */
export const clearAllP3Sessions = () => {
  const before = activeSessions.length;
  activeSessions = activeSessions.filter((s) => s.priority < 3);
  if (activeSessions.length !== before) {
    console.log('[SessionPriority] Cleared all P3 sessions');
    notify();
  }
};

/**
 * React hook that subscribes to session priority changes.
 */
import { useState, useEffect, useSyncExternalStore, useCallback } from 'react';

export const useSessionPriority = () => {
  const subscribe = useCallback((callback: () => void) => {
    listeners.add(callback);
    return () => { listeners.delete(callback); };
  }, []);

  const getSnapshot = useCallback(() => {
    return activeSessions;
  }, []);

  const sessions = useSyncExternalStore(subscribe, getSnapshot);

  return {
    sessions,
    hasActiveCall: sessions.some((s) => s.priority >= 3),
    shouldBlockIncoming,
    registerSession,
    unregisterSession,
  };
};
