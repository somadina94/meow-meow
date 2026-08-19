import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
/**
 * usePrivateGroupCall Hook
 * 
 * Enhanced group call hook for private groups with:
 * - Host-only video (participants are audio-only)
 * - 100 participant limit
 * - No hard time limit — sessions run until the host ends them or midnight reset
 * - Per-minute billing with refund on early end
 */

import { useState, useRef, useCallback, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
// useChatPricing removed — billing system removed
import { toast } from 'sonner';
import { ICE_SERVERS_SFU } from '@/lib/iceServers';
import { playMedia } from '@/lib/media';
import { billGroupCallMinute, billFinalPartialMinute } from '@/services/billing.service';

export const MAX_PARTICIPANTS = 100;
// No hard time limit — sessions run until the host ends them or midnight reset.
export const MAX_DURATION_MINUTES = Infinity;
export const BILLING_INTERVAL_SECONDS = 60; // Heartbeat every 60s; one billing tick per minute

interface Participant {
  id: string;
  name: string;
  photo?: string;
  audioStream?: MediaStream;
  videoStream?: MediaStream; // Remote video stream from host
  isOwner: boolean;
  joinedAt: number;
  amountPaid: number;
  balanceRemaining: number;
  micEnabled: boolean; // Whether host has enabled this participant's mic
}

interface PeerConnectionEntry {
  pc: RTCPeerConnection;
  participantId: string;
}

interface GroupSession {
  sessionId: string;
  groupId: string;
  hostId: string;
  startTime: number;
  participants: Map<string, Participant>;
  totalEarnings: number;
}

interface UsePrivateGroupCallProps {
  groupId: string;
  groupName: string;
  currentUserId: string;
  userName: string;
  userPhoto?: string | null;
  hostLanguage?: string | null;
  /** auth user_id of the live host this viewer joined */
  hostUserId?: string | null;
  isOwner: boolean;
  giftAmountRequired: number;
  preAcquiredStream?: MediaStream | null;
  onParticipantJoin?: (participant: Participant) => void;
  onParticipantLeave?: (participantId: string, reason: string) => void;
  onSessionEnd?: (refunded: boolean) => void;
}

interface PrivateGroupCallState {
  isConnecting: boolean;
  isConnected: boolean;
  isLive: boolean;
  participants: Participant[];
  viewerCount: number;
  error: string | null;
  remainingTime: number; // seconds
  totalEarnings: number;
  isRefunding: boolean;
  hostStream: MediaStream | null; // Host's remote stream for participants
  hostStatus: HostStatus; // Host presence/activity state visible to all
}

export type HostStatus = 'live' | 'away' | 'muted' | 'camera-off' | 'left';

export function usePrivateGroupCall({
  groupId,
  groupName,
  currentUserId,
  userName,
  userPhoto,
  hostLanguage,
  hostUserId = null,
  isOwner,
  giftAmountRequired,
  preAcquiredStream,
  onParticipantJoin,
  onParticipantLeave,
  onSessionEnd,
}: UsePrivateGroupCallProps) {
  const [state, setState] = useState<PrivateGroupCallState>({
    isConnecting: false,
    isConnected: false,
    isLive: false,
    participants: [],
    viewerCount: 0,
    error: null,
    remainingTime: 0, // No time limit
    totalEarnings: 0,
    isRefunding: false,
    hostStream: null,
    hostStatus: 'live',
  });

  const pricing = { groupCallRatePerMinute: 4 };
  const localVideoRef = useRef<HTMLVideoElement>(null);
  const remoteVideoRef = useRef<HTMLVideoElement>(null);
  const localStream = useRef<MediaStream | null>(null);
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null);
  const sessionRef = useRef<GroupSession | null>(null);
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const billingRef = useRef<NodeJS.Timeout | null>(null);
  const billingInProgressRef = useRef<boolean>(false);
  const peerConnections = useRef<Map<string, RTCPeerConnection>>(new Map());
  const cleanupRef = useRef<(manualLeave?: boolean) => void>(() => {});
  const onSessionEndRef = useRef(onSessionEnd);
  onSessionEndRef.current = onSessionEnd;
  const hostUserIdRef = useRef<string | null>(hostUserId ?? null);
  hostUserIdRef.current = hostUserId ?? null;
  const sessionEndedRef = useRef(false);
  const hostStreamRef = useRef<MediaStream | null>(null);
  const finishViewerSessionRef = useRef<(refunded: boolean) => void>(() => {});

  const finishViewerSession = useCallback((refunded: boolean) => {
    if (isOwner || sessionEndedRef.current) return;
    sessionEndedRef.current = true;
    setState(prev => ({
      ...prev,
      hostStatus: 'left',
      hostStream: null,
      isConnected: false,
      isConnecting: false,
      isLive: false,
    }));
    hostStreamRef.current = null;
    cleanupRef.current(false);
    onSessionEndRef.current?.(refunded);
  }, [isOwner]);
  finishViewerSessionRef.current = finishViewerSession;

  // ICE servers: free open-source STUN only + optional self-hosted coturn TURN
  // No paid third-party TURN services used.

  // Create a peer connection to a specific participant
  // Architecture: Host sends video+audio to each participant via 1-to-many.
  // Participants send audio-only back to host. No participant-to-participant connections.
  const createPeerConnection = useCallback((participantId: string) => {
    const pc = new RTCPeerConnection({
      ...ICE_SERVERS_SFU,
      iceCandidatePoolSize: 1,
    });

    // Only add local tracks - host sends video+audio, participants send audio only
    if (localStream.current) {
      localStream.current.getTracks().forEach(track => {
        const sender = pc.addTrack(track, localStream.current!);
        // Medium quality (480p) — balanced for CPU/bandwidth, no blur
        try {
          const params = sender.getParameters();
          if (!params.encodings || params.encodings.length === 0) {
            params.encodings = [{}];
          }
          if (track.kind === 'video') {
            params.encodings[0].maxBitrate = 600_000; // 600 kbps for 480p
            params.encodings[0].maxFramerate = 24;
          } else if (track.kind === 'audio') {
            params.encodings[0].maxBitrate = 48_000; // 48 kbps Opus
          }
          sender.setParameters(params).catch(() => {});
        } catch (_) { /* browser may not support */ }
      });
    }

    // Handle ICE candidates
    pc.onicecandidate = (event) => {
      if (event.candidate && channelRef.current) {
        channelRef.current.send({
          type: 'broadcast',
          event: 'ice-candidate',
          payload: {
            candidate: event.candidate,
            from: currentUserId,
            to: participantId,
          },
        });
      }
    };

    // Handle remote stream (participants receive host video here)
    pc.ontrack = (event) => {
      const [remoteStream] = event.streams;
      console.log(`[PrivateGroupCall] Received remote track from ${participantId}`, remoteStream.getTracks().map(t => t.kind));
      
      // If we're a participant and this stream is from the host, set it as hostStream
      if (!isOwner) {
        const videoTracks = remoteStream.getVideoTracks();
        const audioTracks = remoteStream.getAudioTracks();
        console.log('[PrivateGroupCall] Setting hostStream for participant', {
          videoTracks: videoTracks.length,
          audioTracks: audioTracks.length,
          videoEnabled: videoTracks.map(t => t.enabled),
          videoMuted: videoTracks.map(t => t.muted),
          videoReadyState: videoTracks.map(t => t.readyState),
        });
        setState(prev => ({ ...prev, hostStream: remoteStream }));
        hostStreamRef.current = remoteStream;
        
        // Also try to attach to video element immediately if available
        if (remoteVideoRef.current) {
          console.log('[PrivateGroupCall] Attaching hostStream to video element immediately');
          remoteVideoRef.current.srcObject = remoteStream;
          void playMedia(remoteVideoRef.current);
        }
      }
    };

    pc.onconnectionstatechange = () => {
      console.log(`[PrivateGroupCall] Connection state with ${participantId}:`, pc.connectionState);
      if (isOwner) return;
      if (pc.connectionState === 'failed') {
        pc.close();
        peerConnections.current.delete(participantId);
      }
      if (['failed', 'disconnected', 'closed'].includes(pc.connectionState)) {
        setTimeout(async () => {
          if (sessionEndedRef.current) return;
          const hostId = hostUserIdRef.current || sessionRef.current?.hostId;
          if (!hostId) return;
          const { data } = await supabase
            .from('group_active_hosts')
            .select('id')
            .eq('group_id', groupId)
            .eq('host_id', hostId)
            .eq('is_active', true)
            .maybeSingle();
          if (!data) finishViewerSessionRef.current(true);
        }, 1500);
      }
    };

    peerConnections.current.set(participantId, pc);
    return pc;
  }, [currentUserId, isOwner, groupId]);

  // Handle incoming WebRTC offer
  const handleOffer = useCallback(async (offer: RTCSessionDescriptionInit, fromId: string) => {
    let pc = peerConnections.current.get(fromId);
    
    // If existing PC is already stable/connected, close and recreate for clean renegotiation
    if (pc && (pc.signalingState === 'stable' || pc.connectionState === 'connected')) {
      console.log(`[PrivateGroupCall] Closing existing connection to ${fromId} for renegotiation`);
      pc.close();
      peerConnections.current.delete(fromId);
      pc = undefined;
    }
    
    if (!pc) {
      pc = createPeerConnection(fromId);
    }

    try {
      await pc.setRemoteDescription(new RTCSessionDescription(offer));

      // GRP-F-001 FIX: drain queued ICE candidates after setting remote description
      await drainIceCandidateQueue(fromId);

      const answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      channelRef.current?.send({
        type: 'broadcast',
        event: 'answer',
        payload: {
          answer,
          from: currentUserId,
          to: fromId,
        },
      });
    } catch (error) {
      console.error('[PrivateGroupCall] Error handling offer:', error);
      toast.error('Call connection failed', { description: 'Unable to establish call connection. Please try again.' });
    }
  }, [createPeerConnection, currentUserId]);

  // Handle incoming WebRTC answer
  const handleAnswer = useCallback(async (answer: RTCSessionDescriptionInit, fromId: string) => {
    const pc = peerConnections.current.get(fromId);
    if (pc) {
      // Guard: only set remote description if we're waiting for an answer
      if (pc.signalingState !== 'have-local-offer') {
        console.log(`[PrivateGroupCall] Ignoring duplicate answer from ${fromId} (state: ${pc.signalingState})`);
        return;
      }
      try {
        await pc.setRemoteDescription(new RTCSessionDescription(answer));

        // GRP-F-001 FIX: drain queued ICE candidates after setting remote description
        await drainIceCandidateQueue(fromId);
      } catch (error) {
        console.error('[PrivateGroupCall] Error handling answer:', error);
      toast.error('Call connection failed', { description: 'Unable to complete call setup. Please try again.' });
      }
    }
  }, []);

  // GRP-F-001 FIX: ICE candidate queue per participant
  const iceCandidateQueueRef = useRef<Map<string, RTCIceCandidateInit[]>>(new Map());

  // Handle incoming ICE candidate — queue if remote description not set yet
  const handleIceCandidate = useCallback(async (candidate: RTCIceCandidateInit, fromId: string) => {
    const pc = peerConnections.current.get(fromId);
    if (!pc) {
      // No PC yet — queue for later
      const queue = iceCandidateQueueRef.current.get(fromId) || [];
      queue.push(candidate);
      iceCandidateQueueRef.current.set(fromId, queue);
      return;
    }
    if (!pc.remoteDescription) {
      // PC exists but remote description not set — queue
      const queue = iceCandidateQueueRef.current.get(fromId) || [];
      queue.push(candidate);
      iceCandidateQueueRef.current.set(fromId, queue);
      return;
    }
    try {
      await pc.addIceCandidate(new RTCIceCandidate(candidate));
    } catch (error) {
      console.error('[PrivateGroupCall] Error handling ICE candidate:', error);
    }
  }, []);

  // GRP-F-001 FIX: Drain queued ICE candidates after remote description is set
  const drainIceCandidateQueue = useCallback(async (participantId: string) => {
    const pc = peerConnections.current.get(participantId);
    const queue = iceCandidateQueueRef.current.get(participantId);
    if (!pc || !queue || queue.length === 0) return;
    for (const candidate of queue) {
      try {
        await pc.addIceCandidate(new RTCIceCandidate(candidate));
      } catch (error) {
        console.error('[PrivateGroupCall] Error adding queued ICE candidate:', error);
      }
    }
    iceCandidateQueueRef.current.delete(participantId);
  }, []);

  // Initiate WebRTC connection to a participant (host sends offer)
  const connectToParticipant = useCallback(async (participantId: string) => {
    // Guard: skip if a working connection already exists
    const existingPc = peerConnections.current.get(participantId);
    if (existingPc && existingPc.connectionState !== 'failed' && existingPc.connectionState !== 'closed') {
      console.log(`[PrivateGroupCall] Already connected to ${participantId} (state: ${existingPc.connectionState}), skipping`);
      return;
    }

    try {
      const pc = createPeerConnection(participantId);
      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      channelRef.current?.send({
        type: 'broadcast',
        event: 'offer',
        payload: {
          offer,
          from: currentUserId,
          to: participantId,
        },
      });
      console.log(`[PrivateGroupCall] Sent offer to ${participantId}`);
    } catch (error) {
      console.error('[PrivateGroupCall] Error connecting to participant:', error);
      toast.error('Connection failed', { description: 'Unable to connect to a participant. They may have left.' });
    }
  }, [createPeerConnection, currentUserId]);

  // Initialize host media (video + audio)
  // Uses pre-acquired stream if available to maintain user gesture context
  const initHostMedia = useCallback(async () => {
    try {
      let stream: MediaStream;
      
      // Check if pre-acquired stream is still valid (tracks alive and active)
      const preStreamValid = preAcquiredStream 
        && preAcquiredStream.active 
        && preAcquiredStream.getTracks().length > 0
        && preAcquiredStream.getTracks().every(t => t.readyState === 'live');
      
      if (preStreamValid) {
        console.log('[PrivateGroupCall] Using pre-acquired media stream for host');
        stream = preAcquiredStream!;
      } else {
        console.log('[PrivateGroupCall] Pre-acquired stream invalid/missing, acquiring new stream');
        try {
          stream = await navigator.mediaDevices.getUserMedia({
            video: {
              width: { ideal: 640, max: 854 },
              height: { ideal: 480, max: 480 },
              frameRate: { ideal: 24, max: 24 },
              facingMode: 'user',
            },
            audio: {
              echoCancellation: true,
              noiseSuppression: true,
              autoGainControl: true,
              sampleRate: 48000,
              channelCount: 1,
            },
          });
        } catch (mediaErr) {
          console.error('[PrivateGroupCall] getUserMedia fallback failed:', mediaErr);
      const mErr = classifyError(mediaErr);
      toast.error(mErr.title, { description: mErr.message });
          setState(prev => ({ ...prev, error: 'Could not access camera/microphone. Please try again.' }));
          return null;
        }
      }
      
      localStream.current = stream;
      if (localVideoRef.current) {
        localVideoRef.current.srcObject = stream;
      }
      return stream;
    } catch (error) {
      console.error('Error accessing media:', error);
      const mediaErr = classifyError(error);
      toast.error(mediaErr.title, { description: mediaErr.message });
      setState(prev => ({ ...prev, error: 'Could not access camera/microphone' }));
      return null;
    }
  }, [preAcquiredStream]);

  // Initialize participant media (audio only - no video, mic disabled by default)
  // Uses pre-acquired stream if available to maintain user gesture context
  const initParticipantMedia = useCallback(async () => {
    try {
      let stream: MediaStream;
      if (preAcquiredStream && preAcquiredStream.active && preAcquiredStream.getTracks().length > 0) {
        console.log('[PrivateGroupCall] Using pre-acquired media stream for participant');
        stream = preAcquiredStream;
      } else {
        stream = await navigator.mediaDevices.getUserMedia({
          video: false,
          audio: {
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          },
        });
      }
      
      // Mic is disabled by default for participants
      stream.getAudioTracks().forEach(track => {
        track.enabled = false;
      });
      
      localStream.current = stream;
      return stream;
    } catch (error) {
      console.error('Error accessing audio:', error);
      const audioErr = classifyError(error);
      toast.error(audioErr.title, { description: audioErr.message });
      setState(prev => ({ ...prev, error: 'Could not access microphone' }));
      return null;
    }
  }, [preAcquiredStream]);

  // Check if user can join (balance check) - uses chat rates (₹4/min men, ₹2/min women)
  const checkCanJoin = useCallback(async (): Promise<{ canJoin: boolean; balance: number }> => {
    if (isOwner) return { canJoin: true, balance: 0 };

    const costPerMinute = pricing.groupCallRatePerMinute; // Use group call rate
    const minBalance = costPerMinute * 5; // Need at least 5 minutes worth

    // Read canonical balance via SoT RPC (wallet_transactions), not legacy wallets.balance
    const { data: walletData } = await supabase.rpc('get_men_wallet_balance', { p_user_id: currentUserId });
    const balance = Number((walletData as Record<string, number> | null)?.balance) || 0;
    
    if (balance < minBalance) {
      return { canJoin: false, balance };
    }

    return { canJoin: true, balance };
  }, [currentUserId, isOwner, pricing.groupCallRatePerMinute]);

  // Start billing timer (runs every minute)
  const startBillingTimer = useCallback(() => {
    if (billingRef.current) clearInterval(billingRef.current);

    let missedHostCycles = 0;

    billingRef.current = setInterval(async () => {
      if (sessionEndedRef.current || !sessionRef.current) return;
      if (!isOwner && !hostStreamRef.current) return;

      if (!isOwner) {
        // Participants track consecutive cycles without a host billing update.
        // The RPC returns duplicate_skipped when host already billed this cycle.
        // If 2+ consecutive cycles are NOT duplicate_skipped, host is likely down
        // — participant takes over billing deterministically.
        if (missedHostCycles < 2) {
          missedHostCycles++;
          // Still attempt billing — if host is active, RPC returns duplicate_skipped
          // and we reset the counter. If not, counter grows and we take over.
        }
      }
      
      // Prevent concurrent billing calls
      if (billingInProgressRef.current) {
        console.log('[GROUP] Billing already in progress - skipping');
        return;
      }
      billingInProgressRef.current = true;

      try {
        const session = sessionRef.current;
        if (!session) return;

        // ── Viewer (man) self-bill fallback ──────────────────────────────
        // The host normally drives billing. If the host's tab is backgrounded,
        // network-flaked, or the session is short, the viewer bills himself.
        // bill_session_minute is idempotent on (session_id, man_id, minute_idx),
        // so a duplicate from host + viewer is a safe no-op.
        if (!isOwner) {
          const minuteIdx = Math.max(1, Math.floor((Date.now() - session.startTime) / 60000));
          const [{ data: manProfile }, { data: womanProfile }] = await Promise.all([
            supabase.from('profiles').select('id').eq('user_id', currentUserId).maybeSingle(),
            supabase.from('profiles').select('id').eq('user_id', session.hostId).maybeSingle(),
          ]);
          if (!manProfile?.id || !womanProfile?.id) return;

          const r = await billGroupCallMinute(session.sessionId, 1.0, manProfile.id, womanProfile.id, minuteIdx);
          if (r.skipped === 'host_not_live') {
            finishViewerSessionRef.current(true);
            return;
          }
          if (!r.success && r.error?.includes('Insufficient balance')) {
            console.warn('[GROUP] Viewer ejected — insufficient balance');
            toast.error('Insufficient balance — leaving call');
            onParticipantLeave?.(currentUserId, 'insufficient_balance');
          }
          return;
        }

        // ── Host drives billing for every active man ─────────────────────
        const { data: hostProfile } = await supabase
          .from('profiles').select('id').eq('user_id', session.hostId).maybeSingle();
        if (!hostProfile?.id) return;

        const activeMen = Array.from(session.participants.values()).filter(p => !p.isOwner);
        if (activeMen.length === 0) {
          console.log('[GROUP] No men in room — billing paused');
          return;
        }

        const minuteIdx = Math.max(1, Math.floor((Date.now() - session.startTime) / 60000));

        await Promise.all(activeMen.map(async (man) => {
          const { data: manProfile } = await supabase
            .from('profiles').select('id').eq('user_id', man.id).maybeSingle();
          if (!manProfile?.id) return;

          const r = await billGroupCallMinute(session.sessionId, 1.0, manProfile.id, hostProfile.id, minuteIdx);
          if (!r.success && r.error?.includes('Insufficient balance')) {
            console.warn('[GROUP] Ejecting man for insufficient balance:', man.id);
            onParticipantLeave?.(man.id, 'insufficient_balance');
          }
        }));
      } catch (err) {
        console.error('[GROUP] Billing error:', err);
      } finally {
        billingInProgressRef.current = false;
      }
    }, BILLING_INTERVAL_SECONDS * 1000);
  }, [isOwner, onParticipantLeave, currentUserId]);

  // Start elapsed time tracker (no time limit)
  const startCountdownTimer = useCallback(() => {
    if (timerRef.current) clearInterval(timerRef.current);

    const startTime = Date.now();

    timerRef.current = setInterval(() => {
      const elapsed = Math.floor((Date.now() - startTime) / 1000);
      setState(prev => ({ ...prev, remainingTime: elapsed }));
    }, 1000);
  }, []);

  // No refund logic needed - billing is per-minute, no prepayment
  const processRefunds = useCallback(async () => {
    // No-op: men are billed per minute as they go, nothing to refund
    return;
  }, []);

  // Setup signaling channel
  const setupSignaling = useCallback(async () => {
    // GRP-F-006 FIX: Clean up existing channel with delay to allow flush
    if (channelRef.current) {
      supabase.removeChannel(channelRef.current);
      channelRef.current = null;
      // Allow pending broadcasts to flush before creating new channel
      await new Promise(r => setTimeout(r, 400));
    }

    const channel = supabase.channel(`private-group-${groupId}`, {
      config: {
        broadcast: { self: false },
        presence: { key: currentUserId },
      },
    });

    channel
      .on('presence', { event: 'sync' }, () => {
        const presenceState = channel.presenceState();
        const participantIds = Object.keys(presenceState);
        if (sessionRef.current) {
          for (const key of participantIds) {
            if (sessionRef.current.participants.has(key)) continue;
            const meta = (presenceState[key]?.[0] || {}) as { name?: string; photo?: string; isOwner?: boolean };
            const isHost = meta.isOwner === true
              || key === hostUserIdRef.current
              || key === sessionRef.current.hostId;
            sessionRef.current.participants.set(key, {
              id: key,
              name: meta.name || (isHost ? 'Host' : 'Unknown'),
              photo: meta.photo,
              isOwner: isHost,
              joinedAt: Date.now(),
              amountPaid: 0,
              balanceRemaining: 0,
              micEnabled: isHost,
            });
          }
          setState(prev => ({
            ...prev,
            viewerCount: participantIds.length,
            participants: Array.from(sessionRef.current?.participants.values() || []),
          }));
        } else {
          setState(prev => ({ ...prev, viewerCount: participantIds.length }));
        }
      })
      .on('presence', { event: 'join' }, async ({ key, newPresences }) => {
        if (key === currentUserId) return;

        // Check participant limit
        if (sessionRef.current && sessionRef.current.participants.size >= MAX_PARTICIPANTS) {
          channel.send({
            type: 'broadcast',
            event: 'join-rejected',
            payload: { participantId: key, reason: 'group_full' },
          });
          return;
        }

        const presence = newPresences[0] as { name?: string; photo?: string; isOwner?: boolean; balance?: number } | undefined;
        const newParticipant: Participant = {
          id: key,
          name: presence?.name || 'Unknown',
          photo: presence?.photo,
          isOwner: presence?.isOwner || false,
          joinedAt: Date.now(),
          amountPaid: 0,
          balanceRemaining: presence?.balance || 0,
          micEnabled: false, // Mic disabled by default, only host can enable
        };

        if (sessionRef.current) {
          sessionRef.current.participants.set(key, newParticipant);
        }

        onParticipantJoin?.(newParticipant);
        
        setState(prev => ({
          ...prev,
          participants: Array.from(sessionRef.current?.participants.values() || []),
          viewerCount: sessionRef.current?.participants.size || 0,
        }));

        // Bill immediately on man-join so wallet_transactions records every session,
        // even short ones that end before the first 60s billing tick.
        // The minute_index=0 ensures idempotency vs the host's per-minute timer.
        if (isOwner && !newParticipant.isOwner && sessionRef.current) {
          const session = sessionRef.current;
          (async () => {
            try {
              const [{ data: hostProfile }, { data: manProfile }] = await Promise.all([
                supabase.from('profiles').select('id').eq('user_id', session.hostId).maybeSingle(),
                supabase.from('profiles').select('id').eq('user_id', key).maybeSingle(),
              ]);
              if (!hostProfile?.id || !manProfile?.id) return;
              const r = await billGroupCallMinute(session.sessionId, 1.0, manProfile.id, hostProfile.id, 0);
              if (!r.success && r.error?.includes('Insufficient balance')) {
                console.warn('[GROUP] Ejecting man on join — insufficient balance:', key);
                onParticipantLeave?.(key, 'insufficient_balance');
              }
            } catch (err) {
              console.error('[GROUP] First-minute billing on join failed:', err);
            }
          })();
        }

        // DON'T send offer here - wait for participant's 'participant-ready' signal
        // This avoids the race condition where the offer arrives before the participant's listeners are ready
      })
      .on('presence', { event: 'leave' }, ({ key }) => {
        // Capture whether the leaver was the host BEFORE we delete them
        const leaver = sessionRef.current?.participants.get(key);
        const hostId = hostUserIdRef.current || sessionRef.current?.hostId;
        const leaverWasHost = leaver?.isOwner === true || (!!hostId && key === hostId);

        if (sessionRef.current) {
          sessionRef.current.participants.delete(key);
        }
        
        // Close peer connection
        const pc = peerConnections.current.get(key);
        if (pc) {
          pc.close();
          peerConnections.current.delete(key);
        }

        // IMPORTANT: do NOT revoke group access on raw presence-leave events.
        // Realtime presence can briefly flap during reconnects, and revoking here
        // causes chat inserts to fail under RLS even though the user is still in
        // the active group call. Access is revoked only on explicit leave/cleanup,
        // host stop-live, or server-side billing removal for low balance.
        
        onParticipantLeave?.(key, 'left');

        // ─── Host disconnect → kick all participants ───────────────────────
        // If the host's presence drops (intentional leave, tab close, network drop)
        // and we did NOT receive an explicit `stream-ended` broadcast, every
        // participant should be auto-disconnected from the call.
        if (leaverWasHost && !isOwner) {
          toast.info('Host disconnected. The call has ended.');
          finishViewerSessionRef.current(true);
          return;
        }
        
        const remainingParticipants = Array.from(sessionRef.current?.participants.values() || []);
        const nonHostCount = remainingParticipants.filter(p => !p.isOwner).length;
        
        // Notify host when the last participant leaves
        if (isOwner && nonHostCount === 0 && remainingParticipants.length > 0) {
          toast.info('Last participant left the group call. You are the only one remaining.');
        }
        
        setState(prev => ({
          ...prev,
          participants: remainingParticipants,
          viewerCount: remainingParticipants.length,
        }));
      })
      .on('broadcast', { event: 'stream-ended' }, ({ payload }) => {
        if (!isOwner) {
          toast.info(payload.refunded ? 'Host ended the call.' : 'The call has ended.');
          finishViewerSessionRef.current(!!payload.refunded);
        }
      })
      .on('broadcast', { event: 'participant-removed' }, ({ payload }) => {
        if (payload.participantId === currentUserId) {
          toast.error('You were removed: Insufficient balance');
          // Participant ejected for insufficient balance — revoke access
          cleanup(true);
        }
      })
      .on('broadcast', { event: 'join-rejected' }, ({ payload }) => {
        if (payload.participantId === currentUserId) {
          if (payload.reason === 'group_full') {
            toast.error(`Group is full (max ${MAX_PARTICIPANTS} participants)`);
          }
          // Join rejected (group full) — revoke any membership
          cleanup(true);
        }
      })
      // Participant signals it's ready to receive WebRTC offer
      .on('broadcast', { event: 'participant-ready' }, async ({ payload }) => {
        if (isOwner && localStream.current && payload.participantId) {
          console.log(`[PrivateGroupCall] Participant ${payload.participantId} is ready, sending WebRTC offer`);
          // Small delay to ensure participant's listeners are fully active
          setTimeout(() => {
            connectToParticipant(payload.participantId);
          }, 300);
        }
      })
      // WebRTC signaling events
      .on('broadcast', { event: 'offer' }, async ({ payload }) => {
        if (payload.to === currentUserId) {
          console.log(`[PrivateGroupCall] Received offer from ${payload.from}`);
          await handleOffer(payload.offer, payload.from);
        }
      })
      .on('broadcast', { event: 'answer' }, async ({ payload }) => {
        if (payload.to === currentUserId) {
          console.log(`[PrivateGroupCall] Received answer from ${payload.from}`);
          await handleAnswer(payload.answer, payload.from);
        }
      })
      .on('broadcast', { event: 'ice-candidate' }, async ({ payload }) => {
        if (payload.to === currentUserId) {
          await handleIceCandidate(payload.candidate, payload.from);
        }
      })
      .on('broadcast', { event: 'mic-control' }, ({ payload }) => {
        // Host controls participant mic remotely
        if (payload.participantId === currentUserId && !isOwner) {
          const enabled = payload.enabled;
          if (localStream.current) {
            localStream.current.getAudioTracks().forEach(track => {
              track.enabled = enabled;
            });
          }
          toast.info(enabled ? 'Host enabled your microphone' : 'Host disabled your microphone');
        }
        // Update participant state for all clients
        if (sessionRef.current) {
          const participant = sessionRef.current.participants.get(payload.participantId);
          if (participant) {
            participant.micEnabled = payload.enabled;
            setState(prev => ({
              ...prev,
              participants: Array.from(sessionRef.current?.participants.values() || []),
            }));
          }
        }
      })
      .on('broadcast', { event: 'host-status' }, ({ payload }) => {
        // Participants update their view of the host's current status
        if (!isOwner && payload?.status) {
          setState(prev => ({ ...prev, hostStatus: payload.status as HostStatus }));
        }
      });

    channel.subscribe(async (status) => {
      if (status === 'SUBSCRIBED') {
        const balanceCheck = await checkCanJoin();
        
        await channel.track({
          name: userName,
          photo: userPhoto,
          isOwner,
          balance: balanceCheck.balance,
        });
        
        setState(prev => ({ ...prev, isConnected: true }));

        // GRP-F-002 FIX: If participant, retry participant-ready until an offer is received
        if (!isOwner) {
          let readyRetries = 0;
          const maxReadyRetries = 5;
          const sendReady = () => {
            console.log(`[PrivateGroupCall] Participant sending ready signal (attempt ${readyRetries + 1})`);
            channel.send({
              type: 'broadcast',
              event: 'participant-ready',
              payload: { participantId: currentUserId },
            });
          };
          // Initial send after brief delay
          setTimeout(sendReady, 500);
          // Retry every 3s until we have a peer connection or max retries
          const readyInterval = setInterval(() => {
            readyRetries++;
            if (readyRetries >= maxReadyRetries || peerConnections.current.size > 0) {
              clearInterval(readyInterval);
              return;
            }
            sendReady();
          }, 3000);
        }
      }
    });

    channelRef.current = channel;
    return channel;
  }, [groupId, currentUserId, userName, userPhoto, isOwner, onParticipantJoin, onParticipantLeave, onSessionEnd, checkCanJoin, connectToParticipant, handleOffer, handleAnswer, handleIceCandidate]);

  // Heartbeat ref so we can clear from goLive / cleanup
  const heartbeatRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Go live (host only) — uses canonical RPC + heartbeat + cleanup-on-unload
  const goLive = useCallback(async () => {
    if (!isOwner) return false;

    setState(prev => ({ ...prev, isConnecting: true, error: null }));

    try {
      const stream = await initHostMedia();
      if (!stream) {
        setState(prev => ({ ...prev, isConnecting: false }));
        return false;
      }

      sessionEndedRef.current = false;
      const sessionId = (typeof crypto !== 'undefined' && crypto.randomUUID)
        ? crypto.randomUUID()
        : `${Date.now()}-${Math.random().toString(36).slice(2)}`;

      // Canonical host claim — atomic insert into group_active_hosts +
      // private_groups.is_live/current_host_id update under FOR UPDATE lock.
      const { data: rpcData, error: rpcErr } = await supabase.rpc('start_host_session', {
        p_group_id: groupId,
        p_host_name: userName,
        p_host_photo: userPhoto || null,
        p_host_language: hostLanguage || null,
        p_stream_id: sessionId,
      });

      if (rpcErr) {
        console.error('[GROUP] start_host_session RPC error:', rpcErr);
        toast.error('Unable to go live', { description: rpcErr.message });
        setState(prev => ({ ...prev, isConnecting: false, error: rpcErr.message }));
        stream.getTracks().forEach(t => t.stop());
        return false;
      }
      const result = rpcData as { success: boolean; error?: string } | null;
      if (!result?.success) {
        const msg = result?.error || 'Could not claim host slot';
        console.error('[GROUP] start_host_session failed:', msg);
        toast.error('Unable to go live', { description: msg });
        setState(prev => ({ ...prev, isConnecting: false, error: msg }));
        stream.getTracks().forEach(t => t.stop());
        return false;
      }

      console.log('[GROUP] starting host session', { groupId, sessionId });

      sessionRef.current = {
        sessionId,
        groupId,
        hostId: currentUserId,
        startTime: Date.now(),
        participants: new Map([[currentUserId, {
          id: currentUserId,
          name: userName,
          photo: userPhoto || undefined,
          isOwner: true,
          joinedAt: Date.now(),
          amountPaid: 0,
          balanceRemaining: 0,
          micEnabled: true,
        }]]),
        totalEarnings: 0,
      };

      await setupSignaling();
      startCountdownTimer();
      startBillingTimer();

      // Set host (woman) status to busy during live stream
      await supabase
        .from('user_status')
        .update({ status_text: 'busy', last_seen: new Date().toISOString() })
        .eq('user_id', currentUserId);

      await supabase
        .from('women_availability')
        .update({ is_available: false, is_available_for_calls: false })
        .eq('user_id', currentUserId);

      // ── Heartbeat: refresh every 5s for fast presence + server-side billing
      // (update_host_heartbeat also bills every active man on each tick;
      // bill_session_minute is idempotent on minute_index so 12 ticks/min = 1 row).
      // Server sweep marks host inactive after 90s of silence.
      if (heartbeatRef.current) clearInterval(heartbeatRef.current);
      heartbeatRef.current = setInterval(async () => {
        const { data: hbData, error: hbErr } = await supabase.rpc('update_host_heartbeat', { p_group_id: groupId });
        if (hbErr) {
          console.warn('[GROUP] heartbeat error', hbErr.message);
        } else if ((hbData as any)?.success === false) {
          console.warn('[GROUP] heartbeat lost session, stopping live');
          if (heartbeatRef.current) { clearInterval(heartbeatRef.current); heartbeatRef.current = null; }
        }
      }, 5000);

      // Send a stop signal if tab/window closes while live
      const onBeforeUnload = () => {
        try {
          // Best-effort sync stop — sendBeacon-style via fetch keepalive
          supabase.rpc('stop_host_session', { p_group_id: groupId });
        } catch { /* ignore */ }
      };
      window.addEventListener('beforeunload', onBeforeUnload);
      // Keep ref so cleanup can remove it
      (sessionRef.current as any)._onBeforeUnload = onBeforeUnload;

      setState(prev => ({
        ...prev,
        isConnecting: false,
        isLive: true,
        participants: Array.from(sessionRef.current!.participants.values()),
      }));

      return true;
    } catch (error) {
      console.error('Error going live:', error);
      toast.error('Unable to go live', { description: 'Unable to start the live stream. Please check your connection and try again.' });
      setState(prev => ({
        ...prev,
        isConnecting: false,
        error: 'Failed to start stream'
      }));
      return false;
    }
  }, [groupId, currentUserId, userName, userPhoto, hostLanguage, isOwner, initHostMedia, setupSignaling, startCountdownTimer, startBillingTimer]);

  // Join stream (participant only)
  const joinStream = useCallback(async () => {
    if (isOwner) return false;

    setState(prev => ({ ...prev, isConnecting: true, error: null }));

    try {
      // Check balance first
      const { canJoin, balance } = await checkCanJoin();
      if (!canJoin) {
        setState(prev => ({ 
          ...prev, 
          isConnecting: false, 
          error: `Insufficient balance. You need at least ₹${pricing.groupCallRatePerMinute * 5}` 
        }));
        return false;
      }

      const stream = await initParticipantMedia();
      if (!stream) {
        setState(prev => ({ ...prev, isConnecting: false }));
        return false;
      }

      if (sessionEndedRef.current) {
        stream.getTracks().forEach(t => t.stop());
        setState(prev => ({ ...prev, isConnecting: false }));
        return false;
      }

      let hostQuery = supabase
        .from('group_active_hosts')
        .select('stream_id, host_id, started_at')
        .eq('group_id', groupId)
        .eq('is_active', true);
      if (hostUserId) hostQuery = hostQuery.eq('host_id', hostUserId);
      const { data: gah } = await hostQuery
        .order('started_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (!gah?.stream_id || !gah?.host_id) {
        toast.info('Host ended the call.');
        setState(prev => ({ ...prev, isConnecting: false }));
        finishViewerSessionRef.current(false);
        return false;
      }

      sessionRef.current = {
        sessionId: gah.stream_id,
        groupId,
        hostId: gah.host_id,
        startTime: gah.started_at ? new Date(gah.started_at).getTime() : Date.now(),
        participants: new Map(),
        totalEarnings: 0,
      };

      await setupSignaling();
      startBillingTimer();

      setState(prev => ({
        ...prev,
        isConnecting: false,
        isConnected: true,
      }));

      return true;
    } catch (error) {
      console.error('Error joining stream:', error);
      toast.error('Unable to join stream', { description: 'Unable to join this stream. Please try again in a moment.' });
      setState(prev => ({ 
        ...prev, 
        isConnecting: false, 
        error: 'Failed to join stream' 
      }));
      return false;
    }
  }, [isOwner, checkCanJoin, initParticipantMedia, setupSignaling, startBillingTimer, pricing.groupCallRatePerMinute, groupId, hostUserId]);

  // Cleanup - stops media, peer connections, channel
  // Only revokes group_memberships access when participant explicitly leaves (manualLeave=true).
  // When the host ends the call, participants receive 'stream-ended' which calls cleanup(false)
  // so they retain group access and remain group members — only the live call ends.
  const cleanup = useCallback((manualLeave = false) => {
    // Stop timers
    if (timerRef.current) clearInterval(timerRef.current);
    if (billingRef.current) clearInterval(billingRef.current);

    // Stop heartbeat + remove unload listener (host only)
    if (heartbeatRef.current) {
      clearInterval(heartbeatRef.current);
      heartbeatRef.current = null;
    }
    const onBU = (sessionRef.current as any)?._onBeforeUnload;
    if (onBU) {
      window.removeEventListener('beforeunload', onBU);
    }

    // ── Final partial-minute settlement (e.g. 1m30s → 0.5 min row) ──
    // Host bills every active man for leftover seconds; viewer self-bills.
    const session = sessionRef.current;
    if (session) {
      const elapsedSec = Math.floor((Date.now() - session.startTime) / 1000);
      if (elapsedSec >= 1) {
        if (isOwner) {
          const activeMen = Array.from(session.participants.values()).filter(p => !p.isOwner);
          (async () => {
            try {
              const { data: hostProfile } = await supabase
                .from('profiles').select('id').eq('user_id', session.hostId).maybeSingle();
              if (!hostProfile?.id) return;
              await Promise.all(activeMen.map(async (man) => {
                const { data: manProfile } = await supabase
                  .from('profiles').select('id').eq('user_id', man.id).maybeSingle();
                if (!manProfile?.id) return;
                await billFinalPartialMinute(
                  session.sessionId, 'private_group_call',
                  elapsedSec, manProfile.id, hostProfile.id,
                );
              }));
            } catch (err) {
              console.warn('[GROUP] Final partial-minute billing failed:', err);
            }
          })();
        } else {
          (async () => {
            try {
              const [{ data: manProfile }, { data: hostProfile }] = await Promise.all([
                supabase.from('profiles').select('id').eq('user_id', currentUserId).maybeSingle(),
                supabase.from('profiles').select('id').eq('user_id', session.hostId).maybeSingle(),
              ]);
              if (manProfile?.id && hostProfile?.id) {
                await billFinalPartialMinute(
                  session.sessionId, 'private_group_call',
                  elapsedSec, manProfile.id, hostProfile.id,
                );
              }
            } catch (err) {
              console.warn('[GROUP] Viewer final partial-minute billing failed:', err);
            }
          })();
        }
      }
    }

    // Host: explicitly stop the host session in DB only if we actually started one.
    // Guards against unmount-effect re-runs (deps churn / StrictMode) killing a live
    // session that was never started by this hook instance.
    if (isOwner && groupId && sessionRef.current) {
      supabase.rpc('stop_host_session', { p_group_id: groupId })
        .then(({ error }) => {
          if (error) console.warn('[GROUP] stop_host_session failed on cleanup:', error.message);
        });
    }

    // Revoke own group access ONLY on explicit manual leave (not when host ends call)
    if (manualLeave && !isOwner && groupId && currentUserId) {
      supabase
        .from('group_memberships')
        .update({ has_access: false })
        .eq('group_id', groupId)
        .eq('user_id', currentUserId)
        .then(({ error }) => {
          if (error) console.warn('[GROUP] Failed to revoke own access on cleanup:', error);
        });
    }

    // Stop local tracks
    localStream.current?.getTracks().forEach(track => track.stop());
    localStream.current = null;

    // Close all peer connections
    peerConnections.current.forEach(pc => pc.close());
    peerConnections.current.clear();

    // Unsubscribe from channel
    if (channelRef.current) {
      supabase.removeChannel(channelRef.current);
      channelRef.current = null;
    }

    sessionRef.current = null;
    hostStreamRef.current = null;

    setState({
      isConnecting: false,
      isConnected: false,
      isLive: false,
      participants: [],
      viewerCount: 0,
      error: null,
      remainingTime: 0,
      totalEarnings: 0,
      isRefunding: false,
      hostStream: null,
      hostStatus: sessionEndedRef.current ? 'left' : 'live',
    });
  }, [isOwner, groupId, currentUserId]);

  cleanupRef.current = cleanup;

  // End stream (host only) - broadcasts to participants and cleans up WebRTC
  // DB cleanup is handled by the parent component's handleStopLive
  const endStream = useCallback(async (processRefundsFlag = true) => {
    // Broadcast stream-ended BEFORE cleanup so channel is still available
    try {
      if (channelRef.current) {
        // Send broadcast and wait long enough for participants to receive it
        await channelRef.current.send({
          type: 'broadcast',
          event: 'stream-ended',
          payload: { refunded: processRefundsFlag },
        }).catch(err => console.warn('[PrivateGroupCall] Broadcast failed:', err));
        // Wait 500ms for broadcast propagation on slow connections
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    } catch (err) {
      console.warn('[PrivateGroupCall] Broadcast send failed (channel may be closed):', err);
    }

    // Always cleanup regardless of broadcast success
    cleanup();
    onSessionEnd?.(processRefundsFlag);
  }, [cleanup, onSessionEnd]);
  // Broadcast host status to all participants (host only)
  const broadcastHostStatus = useCallback((status: HostStatus) => {
    if (!isOwner || !channelRef.current) return;
    setState(prev => ({ ...prev, hostStatus: status }));
    channelRef.current.send({
      type: 'broadcast',
      event: 'host-status',
      payload: { status },
    });
  }, [isOwner]);

  // Toggle video (host only)
  const toggleVideo = useCallback((enabled: boolean) => {
    if (localStream.current && isOwner) {
      localStream.current.getVideoTracks().forEach(track => {
        track.enabled = enabled;
      });
      broadcastHostStatus(enabled ? 'live' : 'camera-off');
    }
  }, [isOwner, broadcastHostStatus]);

  // Toggle audio (host can always toggle, participant only if host enabled their mic)
  const toggleAudio = useCallback((enabled: boolean) => {
    if (localStream.current) {
      localStream.current.getAudioTracks().forEach(track => {
        track.enabled = enabled;
      });
      if (isOwner) {
        broadcastHostStatus(enabled ? 'live' : 'muted');
      }
    }
  }, [isOwner, broadcastHostStatus]);

  // Host enables/disables a specific participant's mic
  const enableParticipantMic = useCallback((participantId: string, enabled: boolean) => {
    if (!isOwner || !channelRef.current) return;
    
    channelRef.current.send({
      type: 'broadcast',
      event: 'mic-control',
      payload: { participantId, enabled },
    });

    // Update local state immediately for host
    if (sessionRef.current) {
      const participant = sessionRef.current.participants.get(participantId);
      if (participant) {
        participant.micEnabled = enabled;
        setState(prev => ({
          ...prev,
          participants: Array.from(sessionRef.current?.participants.values() || []),
        }));
      }
    }
  }, [isOwner]);

  // Cleanup on unmount only (not on every cleanup-identity change, which would
  // wrongly tear down an active live session whenever deps churn).
  useEffect(() => {
    return () => {
      cleanupRef.current();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Viewers: leave immediately when this host row goes inactive (broadcast can be missed).
  useEffect(() => {
    if (isOwner) return;
    const hostId = hostUserId;
    if (!hostId || !groupId) return;

    const kickIfHostGone = async () => {
      if (sessionEndedRef.current) return;
      const { data, error } = await supabase
        .from('group_active_hosts')
        .select('id')
        .eq('group_id', groupId)
        .eq('host_id', hostId)
        .eq('is_active', true)
        .maybeSingle();
      if (error) return;
      if (!data) finishViewerSessionRef.current(true);
    };

    const channel = supabase
      .channel(`host-gone-${groupId}-${hostId}-${currentUserId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'group_active_hosts',
        filter: `host_id=eq.${hostId}`,
      }, () => { void kickIfHostGone(); })
      .subscribe();

    const poll = window.setInterval(() => { void kickIfHostGone(); }, 4000);
    void kickIfHostGone();

    return () => {
      window.clearInterval(poll);
      supabase.removeChannel(channel);
    };
  }, [isOwner, groupId, hostUserId, currentUserId]);

  // Host: broadcast 'away' / 'live' on tab visibility changes while live
  useEffect(() => {
    if (!isOwner || !state.isLive) return;
    const handleVisibility = () => {
      const isHidden = document.visibilityState === 'hidden';
      // When returning, restore status based on current track state
      if (!isHidden && localStream.current) {
        const audioOn = localStream.current.getAudioTracks().some(t => t.enabled);
        const videoOn = localStream.current.getVideoTracks().some(t => t.enabled);
        const next: HostStatus = !videoOn ? 'camera-off' : !audioOn ? 'muted' : 'live';
        broadcastHostStatus(next);
      } else if (isHidden) {
        broadcastHostStatus('away');
      }
    };
    document.addEventListener('visibilitychange', handleVisibility);
    return () => document.removeEventListener('visibilitychange', handleVisibility);
  }, [isOwner, state.isLive, broadcastHostStatus]);

  return {
    ...state,
    localVideoRef,
    remoteVideoRef,
    goLive,
    joinStream,
    endStream,
    toggleVideo,
    toggleAudio,
    enableParticipantMic,
    cleanup,
    maxParticipants: MAX_PARTICIPANTS,
    maxDuration: MAX_DURATION_MINUTES,
  };
}
