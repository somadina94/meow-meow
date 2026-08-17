import { useState, useEffect, useRef } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { shouldBlockIncoming } from './useSessionPriority';

interface IncomingCall {
  callId: string;
  callerUserId: string;
  callerName: string;
  callerPhoto: string | null;
}

// Audio context for ringtone buzz
let ringAudioContext: AudioContext | null = null;
let ringIntervalId: NodeJS.Timeout | null = null;

// GEN-001 FIX: Pre-warm AudioContext on first user interaction for iOS Safari
let audioContextWarmed = false;
const warmAudioContext = () => {
  if (audioContextWarmed) return;
  audioContextWarmed = true;
  try {
    if (!ringAudioContext || ringAudioContext.state === 'closed') {
      ringAudioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
    }
    // Resume suspended context (iOS requires user gesture)
    if (ringAudioContext.state === 'suspended') {
      ringAudioContext.resume();
    }
  } catch (e) {
    console.warn('[IncomingCalls] Failed to pre-warm AudioContext:', e);
  }
};

// Register once on first user interaction
if (typeof document !== 'undefined') {
  const handler = () => {
    warmAudioContext();
    document.removeEventListener('click', handler);
    document.removeEventListener('touchstart', handler);
  };
  document.addEventListener('click', handler, { once: true });
  document.addEventListener('touchstart', handler, { once: true });
}

const playRingSound = () => {
  try {
    if (!ringAudioContext || ringAudioContext.state === 'closed') {
      ringAudioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
    }
    // GEN-001 FIX: Resume if suspended (iOS Safari)
    if (ringAudioContext.state === 'suspended') {
      ringAudioContext.resume();
    }
    const ctx = ringAudioContext;
    const now = ctx.currentTime;

    // Old-school telephone "tring-tring" — two rapid bell strikes
    const bellFreqs = [2000, 2500]; // High metallic bell frequencies
    const strikeGap = 0.08;

    for (let burst = 0; burst < 2; burst++) {
      const burstStart = now + burst * 0.35; // Two bursts 350ms apart

      for (let i = 0; i < 6; i++) {
        const t = burstStart + i * strikeGap;
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.connect(gain);
        gain.connect(ctx.destination);

        // Alternate between two bell frequencies for metallic ring
        osc.frequency.setValueAtTime(bellFreqs[i % 2], t);
        osc.type = 'square';

        // Sharp attack, quick decay — like a bell hammer strike
        gain.gain.setValueAtTime(0, t);
        gain.gain.linearRampToValueAtTime(0.15, t + 0.005);
        gain.gain.exponentialRampToValueAtTime(0.001, t + strikeGap - 0.01);

        osc.start(t);
        osc.stop(t + strikeGap);
      }
    }
  } catch (e) {
    console.error("Ring sound error:", e);
  }
};

const startRingLoop = () => {
  if (ringIntervalId) return;
  playRingSound();
  ringIntervalId = setInterval(playRingSound, 1500); // Repeat every 1.5s
};

export const stopRingLoop = () => {
  if (ringIntervalId) {
    clearInterval(ringIntervalId);
    ringIntervalId = null;
  }
};

// Global set to track call IDs initiated by the current user
// This prevents the initiator from seeing their own call as incoming
const outgoingCallIds = new Set<string>();

export const registerOutgoingCall = (callId: string) => {
  outgoingCallIds.add(callId);
  // Auto-cleanup after 2 minutes
  setTimeout(() => outgoingCallIds.delete(callId), 120_000);
};

export const useIncomingCalls = (currentUserId: string | null, userGender?: "male" | "female") => {
  const [incomingCall, setIncomingCall] = useState<IncomingCall | null>(null);
  const incomingCallRef = useRef<IncomingCall | null>(null);

  // Keep ref in sync
  useEffect(() => {
    incomingCallRef.current = incomingCall;
  }, [incomingCall]);

  // Continuous buzz sound while incoming call is active
  useEffect(() => {
    if (incomingCall) {
      startRingLoop();
    } else {
      stopRingLoop();
    }
    return () => stopRingLoop();
  }, [incomingCall]);

  useEffect(() => {
    if (!currentUserId) return;

    // Determine which column to listen on based on gender
    const gender = userGender || "female";
    const filterColumn = gender === "male" ? "man_user_id" : "woman_user_id";
    const callerColumn = gender === "male" ? "woman_user_id" : "man_user_id";

    // Subscribe to incoming calls for this user
    const channel = supabase
      .channel(`incoming-calls-${currentUserId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'video_call_sessions',
          filter: `${filterColumn}=eq.${currentUserId}`
        },
        async (payload) => {
          const call = payload.new as any;
          
          if (call.status === 'ringing' || call.status === 'connecting') {
            // Priority check: block incoming call if already in a P3 session
            const callType = call.call_type === 'audio' ? 'audio_call' : 'video_call';
            if (shouldBlockIncoming(callType)) {
              console.log('[IncomingCalls] Blocked by session priority — already in an active call/group');
              // Auto-decline the call so caller gets feedback
              await supabase
                .from('video_call_sessions')
                .update({ status: 'declined', end_reason: 'busy' })
                .eq('call_id', call.call_id);
              return;
            }

            // Skip if this is a call the current user initiated (by call_id tracking)
            if (outgoingCallIds.has(call.call_id)) {
              console.log('[IncomingCalls] Skipping own outgoing call (by call_id):', call.call_id);
              return;
            }

            const callerId = call[callerColumn];
            
            // Skip if the caller is the current user — this means WE initiated it
            if (callerId === currentUserId) {
              console.log('[IncomingCalls] Skipping own outgoing call (caller is self):', call.call_id);
              return;
            }

            // Additional check: if the call_id contains our user ID as initiator pattern
            if (call.call_id && call.call_id.startsWith(`call_${currentUserId}_`)) {
              console.log('[IncomingCalls] Skipping own outgoing call (call_id pattern):', call.call_id);
              return;
            }
            
            // Fetch caller info via secure RPC (excludes sensitive fields)
            const { fetchPublicProfile } = await import("@/lib/profile-queries");
            const callerProfile = await fetchPublicProfile(callerId);

            let callerName = callerProfile?.full_name || 'Someone';
            let callerPhoto = callerProfile?.photo_url || null;

            // Fallback to gender-specific profile table
            if (!callerProfile) {
              const fallbackTable = gender === "male" ? "female_profiles" : "male_profiles";
              const { data: fallbackProfile } = await supabase
                .from(fallbackTable)
                .select('full_name, photo_url')
                .eq('user_id', callerId)
                .single();
              
              if (fallbackProfile) {
                callerName = fallbackProfile.full_name || 'Someone';
                callerPhoto = fallbackProfile.photo_url;
              }
            }

            setIncomingCall({
              callId: call.call_id,
              callerUserId: callerId,
              callerName,
              callerPhoto
            });
          }
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'video_call_sessions',
          filter: `${filterColumn}=eq.${currentUserId}`
        },
        (payload) => {
          const call = payload.new as any;
          if (['ended', 'declined', 'missed', 'timeout_cleanup'].includes(call.status) && 
              incomingCallRef.current?.callId === call.call_id) {
            setIncomingCall(null);
          }
        }
      )
      .subscribe();

    // GEN-002 FIX: Polling fallback with exponential backoff
    // Only activates as a true fallback; backs off when no calls found
    let pollIntervalMs = 3000; // Start at 3s
    let consecutiveEmpty = 0;
    let pollTimeoutId: NodeJS.Timeout | null = null;

    const schedulePoll = () => {
      pollTimeoutId = setTimeout(pollForCalls, pollIntervalMs);
    };

    const pollForCalls = async () => {
      if (incomingCallRef.current) {
        // Already showing a call, reset backoff and schedule next
        consecutiveEmpty = 0;
        pollIntervalMs = 3000;
        schedulePoll();
        return;
      }

      const { data: ringingCalls } = await supabase
        .from('video_call_sessions')
        .select('call_id, man_user_id, woman_user_id, call_type, status, created_at')
        .eq(filterColumn, currentUserId)
        .in('status', ['ringing', 'connecting'])
        .order('created_at', { ascending: false })
        .limit(1);

      if (ringingCalls && ringingCalls.length > 0) {
        const call = ringingCalls[0];
        const callAge = Date.now() - new Date(call.created_at).getTime();
        
        // Only process calls less than 35 seconds old
        if (callAge <= 35000) {
          const callerId = call[callerColumn];
          if (callerId !== currentUserId && !outgoingCallIds.has(call.call_id) && !call.call_id?.startsWith(`call_${currentUserId}_`)) {
            const callType = call.call_type === 'audio' ? 'audio_call' : 'video_call';
            if (!shouldBlockIncoming(callType as any)) {
              // Fetch caller info
              const { fetchPublicProfile } = await import("@/lib/profile-queries");
              const callerProfile = await fetchPublicProfile(callerId);
              let callerName = callerProfile?.full_name || 'Someone';
              let callerPhoto = callerProfile?.photo_url || null;

              if (!callerProfile) {
                const fallbackTable = gender === "male" ? "female_profiles" : "male_profiles";
                const { data: fallbackProfile } = await supabase
                  .from(fallbackTable)
                  .select('full_name, photo_url')
                  .eq('user_id', callerId)
                  .single();
                if (fallbackProfile) {
                  callerName = fallbackProfile.full_name || 'Someone';
                  callerPhoto = fallbackProfile.photo_url;
                }
              }

              consecutiveEmpty = 0;
              pollIntervalMs = 3000;
              setIncomingCall({
                callId: call.call_id,
                callerUserId: callerId,
                callerName,
                callerPhoto
              });
              schedulePoll();
              return;
            }
          }
        }
      }

      // No calls found — exponential backoff (3s → 5s → 10s → 30s max)
      consecutiveEmpty++;
      if (consecutiveEmpty >= 3) {
        pollIntervalMs = Math.min(pollIntervalMs * 2, 30000);
      }
      schedulePoll();
    };

    schedulePoll();

    return () => {
      supabase.removeChannel(channel);
      if (pollTimeoutId) clearTimeout(pollTimeoutId);
    };
  }, [currentUserId, userGender]);

  const clearIncomingCall = () => {
    stopRingLoop();
    setIncomingCall(null);
  };

  return { incomingCall, clearIncomingCall };
};
