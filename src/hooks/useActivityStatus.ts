/**
 * useActivityStatus Hook
 * 
 * Tracks user activity and manages online/offline status in the database.
 * Updates status to offline after a period of inactivity.
 * Uses sendBeacon for reliable offline status on page close.
 */

import { useEffect, useRef, useCallback } from "react";
import { supabase } from "@/integrations/supabase/client";

const INACTIVITY_TIMEOUT = 600000; // 10 minutes in ms - sets user offline and logs out
const HEARTBEAT_INTERVAL = 30000; // 30 seconds

// Get Supabase URL and key for sendBeacon
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_KEY = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;

export const useActivityStatus = (userId: string | null) => {
  const lastActivityRef = useRef<number>(Date.now());
  const heartbeatIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const inactivityCheckRef = useRef<NodeJS.Timeout | null>(null);
  const visibilityTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const isOnlineRef = useRef<boolean>(false);

  // Update last activity timestamp
  const updateActivity = useCallback(() => {
    lastActivityRef.current = Date.now();
  }, []);

  // Set user offline using sendBeacon (reliable on page unload)
  const setOfflineBeacon = useCallback((userIdToUpdate: string) => {
    if (!SUPABASE_URL || !SUPABASE_KEY) return;

    const now = new Date().toISOString();
    
    // Use sendBeacon with Supabase REST API for reliable delivery on page close
    const url = `${SUPABASE_URL}/rest/v1/user_status?user_id=eq.${userIdToUpdate}`;
    const payload = JSON.stringify({
      is_online: false,
      last_seen: now,
      updated_at: now
    });

    const headers = {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Prefer': 'return=minimal'
    };

    // Create a Blob with the payload and headers
    const blob = new Blob([payload], { type: 'application/json' });
    
    // Try sendBeacon first (most reliable for page unload)
    if (navigator.sendBeacon) {
      // For sendBeacon, we need to use a simple POST, but Supabase PATCH requires headers
      // So we'll use fetch with keepalive as fallback
      try {
        fetch(url, {
          method: 'PATCH',
          headers,
          body: payload,
          keepalive: true // This ensures the request completes even if page closes
        }).catch(() => {});
      } catch (e) {
        console.error('Failed to send offline beacon:', e);
      }
    }
  }, []);

  // Set user online status in database
  // IMPORTANT: When going online, preserve "busy" status if user has active sessions
  const setOnlineStatus = useCallback(async (isOnline: boolean) => {
    if (!userId) return;

    const now = new Date().toISOString();
    isOnlineRef.current = isOnline;

    try {
      // When going online, check if user should actually be "busy"
      let statusText: string | undefined;
      if (isOnline) {
        const [{ count: chatCount }, { count: videoCount }] = await Promise.all([
          supabase.from("active_chat_sessions").select("*", { count: "exact", head: true })
            .or(`man_user_id.eq.${userId},woman_user_id.eq.${userId}`).eq("status", "active"),
          supabase.from("video_call_sessions").select("*", { count: "exact", head: true })
            .or(`man_user_id.eq.${userId},woman_user_id.eq.${userId}`).eq("status", "active"),
        ]);
        
        const totalVideoCalls = videoCount || 0;
        const totalChats = chatCount || 0;
        
        if (totalVideoCalls > 0) {
          statusText = "busy";
        } else if (totalChats >= 3) {
          statusText = "busy";
        } else {
          statusText = "online";
        }
      }

      // Update user_status table
      const { data: existing } = await supabase
        .from("user_status")
        .select("id")
        .eq("user_id", userId)
        .maybeSingle();

      const updateData: Record<string, unknown> = {
        is_online: isOnline,
        last_seen: now,
        updated_at: now,
      };
      
      // Only set status_text when we have a calculated value (going online)
      // or when going offline
      if (!isOnline) {
        updateData.status_text = "offline";
      } else if (statusText) {
        updateData.status_text = statusText;
      }

      if (existing) {
        await supabase
          .from("user_status")
          .update(updateData)
          .eq("user_id", userId);
      } else {
        await supabase
          .from("user_status")
          .insert({
            user_id: userId,
            is_online: isOnline,
            last_seen: now,
            status_text: isOnline ? (statusText || "online") : "offline",
          });
      }

      // Also update last_active_at in profiles table for real-time partner monitoring
      await supabase
        .from("profiles")
        .update({ last_active_at: now })
        .eq("user_id", userId);

    } catch (error) {
      console.error("Error updating online status:", error);
    }
  }, [userId]);

  // Start activity tracking
  useEffect(() => {
    if (!userId) return;

    // Activity event handlers
    const handleActivity = () => {
      const wasInactive = Date.now() - lastActivityRef.current > INACTIVITY_TIMEOUT;
      updateActivity();
      
      // If user was inactive and is now active, set them online
      if (wasInactive) {
        setOnlineStatus(true);
      }
    };

    // Add activity listeners
    const events = ['click', 'keydown', 'mousemove', 'touchstart', 'scroll'];
    events.forEach(event => {
      window.addEventListener(event, handleActivity, { passive: true });
    });

    // Set initial online status
    setOnlineStatus(true);

    // Heartbeat - periodically update online status
    heartbeatIntervalRef.current = setInterval(() => {
      const timeSinceActivity = Date.now() - lastActivityRef.current;
      
      if (timeSinceActivity < INACTIVITY_TIMEOUT) {
        // User is active, keep them online
        setOnlineStatus(true);
      }
    }, HEARTBEAT_INTERVAL);

    // Inactivity check - set offline and logout after 10 minutes
    inactivityCheckRef.current = setInterval(async () => {
      const timeSinceActivity = Date.now() - lastActivityRef.current;
      
      if (timeSinceActivity >= INACTIVITY_TIMEOUT) {
        // User is inactive for 10 minutes, set them offline and logout
        await setOnlineStatus(false);
        await supabase.auth.signOut();
        window.location.href = '/auth';
      }
    }, 10000); // Check every 10 seconds

    // Handle page visibility changes
    const handleVisibilityChange = () => {
      if (document.hidden) {
        // Page is hidden, mark as offline after short delay
        visibilityTimeoutRef.current = setTimeout(() => {
          if (document.hidden) {
            setOnlineStatus(false);
          }
        }, 30000); // 30 seconds grace period
      } else {
        // Clear any pending offline timeout
        if (visibilityTimeoutRef.current) {
          clearTimeout(visibilityTimeoutRef.current);
          visibilityTimeoutRef.current = null;
        }
        // Page is visible again
        updateActivity();
        setOnlineStatus(true);
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);

    // Handle page unload - use sendBeacon for reliable delivery
    const handleBeforeUnload = () => {
      // Use sendBeacon/keepalive fetch for reliable offline status on page close
      setOfflineBeacon(userId);
    };

    // Also handle pagehide which is more reliable on mobile
    const handlePageHide = (e: PageTransitionEvent) => {
      // If persisted is false, page is being unloaded
      if (!e.persisted) {
        setOfflineBeacon(userId);
      }
    };

    window.addEventListener('beforeunload', handleBeforeUnload);
    window.addEventListener('pagehide', handlePageHide);

    // Cleanup
    return () => {
      events.forEach(event => {
        window.removeEventListener(event, handleActivity);
      });
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      window.removeEventListener('beforeunload', handleBeforeUnload);
      window.removeEventListener('pagehide', handlePageHide);
      
      if (heartbeatIntervalRef.current) {
        clearInterval(heartbeatIntervalRef.current);
      }
      if (inactivityCheckRef.current) {
        clearInterval(inactivityCheckRef.current);
      }
      if (visibilityTimeoutRef.current) {
        clearTimeout(visibilityTimeoutRef.current);
      }

      // Set offline when hook unmounts (best effort)
      if (isOnlineRef.current) {
        setOnlineStatus(false);
      }
    };
  }, [userId, updateActivity, setOnlineStatus, setOfflineBeacon]);

  return {
    updateActivity,
    setOnlineStatus
  };
};
