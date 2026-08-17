import { useState, useRef, useCallback, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useToast } from '@/hooks/use-toast';
import { ICE_SERVERS } from '@/lib/iceServers';
import { billMinute, billFinalPartialMinute } from '@/services/billing.service';

/**
 * P2P WebRTC Video Call Hook
 *
 * Uses peer-to-peer WebRTC with Supabase Realtime for signaling.
 * No external media server required - direct connection between peers.
 *
 * Benefits:
 * - Scalable: Uses peer resources, not server resources
 * - Low latency: Direct connection between users
 * - Only uses free open-source STUN servers (no paid services)
 */

interface P2PCallState {
  isConnecting: boolean;
  isConnected: boolean;
  callStatus: 'idle' | 'ringing' | 'connecting' | 'active' | 'ended';
  callDuration: number;
  totalCost: number;
  isVideoEnabled: boolean;
  isAudioEnabled: boolean;
}

interface UseP2PCallProps {
  callId: string;
  currentUserId: string;
  remoteUserId: string;
  isInitiator: boolean;
  ratePerMinute?: number;
  onCallEnded?: () => void;
  preAcquiredStream?: MediaStream | null;
  audioOnly?: boolean;
}

const OFFER_RETRY_INTERVAL_MS = 2000;
const CALL_SETUP_TIMEOUT_MS = 35000;
const MAX_OFFER_RETRIES = Math.ceil(CALL_SETUP_TIMEOUT_MS / OFFER_RETRY_INTERVAL_MS);
const ANSWER_RETRY_INTERVAL_MS = 2000;
const MAX_ANSWER_RETRIES = Math.ceil(CALL_SETUP_TIMEOUT_MS / ANSWER_RETRY_INTERVAL_MS);
const SIGNAL_SEND_MAX_RETRIES = 3;
const SIGNAL_SEND_RETRY_DELAY_MS = 250;

export const useP2PCall = ({
  callId,
  currentUserId,
  remoteUserId,
  isInitiator,
  ratePerMinute = 8,
  onCallEnded,
  preAcquiredStream = null,
  audioOnly = false,
}: UseP2PCallProps) => {
  const { toast } = useToast();
  
  const [state, setState] = useState<P2PCallState>({
    isConnecting: false,
    isConnected: false,
    callStatus: 'idle',
    callDuration: 0,
    totalCost: 0,
    isVideoEnabled: !audioOnly,
    isAudioEnabled: true,
  });
  const [remoteStream, setRemoteStream] = useState<MediaStream | null>(null);

  const localVideoRef = useRef<HTMLVideoElement | null>(null);
  const remoteVideoRef = useRef<HTMLVideoElement | null>(null);
  const localStreamRef = useRef<MediaStream | null>(null);
  const remoteStreamRef = useRef<MediaStream | null>(null);
  const callDurationRef = useRef(0);
  const peerConnectionRef = useRef<RTCPeerConnection | null>(null);
  const signalChannelRef = useRef<ReturnType<typeof supabase.channel> | null>(null);
  const callTimerRef = useRef<NodeJS.Timeout | null>(null);
  const billingTimerRef = useRef<NodeJS.Timeout | null>(null);
  const offerRetryTimerRef = useRef<NodeJS.Timeout | null>(null);
  const offerRetryAttemptsRef = useRef<number>(0);
  const answerRetryTimerRef = useRef<NodeJS.Timeout | null>(null);
  const answerRetryAttemptsRef = useRef<number>(0);
  const lastLocalAnswerRef = useRef<RTCSessionDescriptionInit | null>(null);
  const iceCandidateQueueRef = useRef<RTCIceCandidateInit[]>([]);
  const sessionIdRef = useRef<string | null>(null);
  const lastBilledMinuteRef = useRef<number>(0);
  const billingInProgressRef = useRef<boolean>(false);
  const callStatusRef = useRef<string>('idle');

  // Keep callStatusRef in sync with state
  useEffect(() => {
    callStatusRef.current = state.callStatus;
  }, [state.callStatus]);

  const wait = useCallback((ms: number) => new Promise((resolve) => setTimeout(resolve, ms)), []);

  const sendSignal = useCallback(async (
    event: string,
    payload: Record<string, unknown>,
    retries = SIGNAL_SEND_MAX_RETRIES
  ): Promise<boolean> => {
    const channel = signalChannelRef.current;
    if (!channel) {
      console.warn(`[P2P] Cannot send ${event}: signaling channel not ready`);
      return false;
    }

    for (let attempt = 1; attempt <= retries; attempt += 1) {
      try {
        const status = await channel.send({
          type: 'broadcast',
          event,
          payload,
        });

        if (status === 'ok') {
          return true;
        }

        console.warn(`[P2P] Signal send failed (${event}) attempt ${attempt}/${retries}:`, status);
      } catch (error) {
        console.error(`[P2P] Signal send error (${event}) attempt ${attempt}/${retries}:`, error);
      }

      if (attempt < retries) {
        await wait(SIGNAL_SEND_RETRY_DELAY_MS);
      }
    }

    return false;
  }, [wait]);

  // Get session ID for billing
  const getSessionId = async () => {
    if (sessionIdRef.current) return sessionIdRef.current;
    
    const { data } = await supabase
      .from('video_call_sessions')
      .select('id')
      .eq('call_id', callId)
      .single();
    
    if (data) {
      sessionIdRef.current = data.id;
    }
    return data?.id || null;
  };

  // Process call billing — fires every 60s; one tick = one statement row per minute.
  const processBilling = async () => {
    // VID-F-003 FIX: Use ref instead of stale state
    if (callStatusRef.current !== 'active' || !isInitiator) return;

    // Prevent concurrent billing calls (race condition guard)
    if (billingInProgressRef.current) {
      return;
    }
    billingInProgressRef.current = true;

    const sessionId = await getSessionId();
    if (!sessionId) {
      console.error('[P2P] No session ID for billing');
      billingInProgressRef.current = false;
      return;
    }

    try {
      // Resolve profile IDs (billing uses profile.id, not auth user_id)
      const [{ data: manProfile }, { data: womanProfile }] = await Promise.all([
        supabase.from('profiles').select('id').eq('user_id', currentUserId).maybeSingle(),
        supabase.from('profiles').select('id').eq('user_id', remoteUserId).maybeSingle(),
      ]);
      if (!manProfile?.id || !womanProfile?.id) {
        console.warn('[P2P] Cannot bill — profile lookup failed');
        return;
      }
      const sessionType = audioOnly ? 'audio_call' : 'video_call';
      const minuteIdx = Math.floor(callDurationRef.current / 60);
      const result = await billMinute(sessionId, sessionType, 1.0, manProfile.id, womanProfile.id, 1, minuteIdx);
      if (!result.success) {
        if (result.error?.includes('Insufficient balance')) {
          toast({ title: 'Insufficient balance', description: 'Call ending — please recharge.', variant: 'destructive' });
          setState(prev => ({ ...prev, callStatus: 'ended' }));
          onCallEnded?.();
        } else if (!result.duplicate_skipped) {
          console.error('[P2P] Billing error:', result.error);
        }
      }
    } catch (err) {
      console.error('[P2P] Billing failed:', err);
    } finally {
      billingInProgressRef.current = false;
    }
  };

  // Start call timer and billing when active — VID-H-01: use ref to avoid stale closure
  useEffect(() => {
    if (state.callStatus === 'active') {
      // Duration counter (every second)
      callTimerRef.current = setInterval(() => {
        setState(prev => {
          const newDuration = prev.callDuration + 1;
          callDurationRef.current = newDuration;
          return {
            ...prev,
            callDuration: newDuration,
            totalCost: Math.ceil(newDuration / 60) * ratePerMinute,
          };
        });
      }, 1000);

      // 60s billing heartbeat — minute 0 is billed by the DB trigger that fires
      // when video_call_sessions.status transitions to active/answered (audit Issue #2).
      // Subsequent minutes (1, 2, …) are billed here using callDuration-derived index.
      billingTimerRef.current = setInterval(() => {
        processBilling();
      }, 60000);


      return () => {
        if (callTimerRef.current) clearInterval(callTimerRef.current);
        if (billingTimerRef.current) clearInterval(billingTimerRef.current);
      };
    }

    return () => {
      if (callTimerRef.current) {
        clearInterval(callTimerRef.current);
      }
      if (billingTimerRef.current) {
        clearInterval(billingTimerRef.current);
      }
    };
  }, [state.callStatus, ratePerMinute]);

  // Initialize local media (camera + microphone)
  // If preAcquiredStream is available, use it directly instead of calling getUserMedia
  const initLocalMedia = useCallback(async () => {
    try {
      console.log('[P2P] Initializing local media...', audioOnly ? '(audio-only)' : '(video+audio)');
      
      // Use pre-acquired stream if available (acquired in user gesture context)
      let stream: MediaStream;
      if (preAcquiredStream && preAcquiredStream.active && preAcquiredStream.getTracks().length > 0) {
        console.log('[P2P] Using pre-acquired media stream');
        stream = preAcquiredStream;
      } else if (audioOnly) {
        stream = await navigator.mediaDevices.getUserMedia({
          video: false,
          audio: {
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          }
        });
      } else {
        stream = await navigator.mediaDevices.getUserMedia({
          video: { 
            width: { ideal: 640, max: 854 },
            height: { ideal: 480, max: 480 },
            frameRate: { ideal: 24, max: 24 }
          },
          audio: {
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          }
        });
      }
      
      localStreamRef.current = stream;
      
      if (localVideoRef.current) {
        localVideoRef.current.srcObject = stream;
      }

      console.log('[P2P] Local media initialized:', stream.getTracks().map(t => t.kind));
      return stream;
    } catch (error) {
      console.error('[P2P] Error getting local media:', error);
      toast({
        title: audioOnly ? "Microphone Error" : "Camera/Microphone Error",
        description: audioOnly ? "Please allow access to microphone" : "Please allow access to camera and microphone",
        variant: "destructive",
      });
      throw error;
    }
  }, [toast, preAcquiredStream, audioOnly]);

  // Process queued ICE candidates after remote description is set
  const processIceCandidateQueue = useCallback(async () => {
    if (!peerConnectionRef.current || !peerConnectionRef.current.remoteDescription) {
      return;
    }

    console.log(`[P2P] Processing ${iceCandidateQueueRef.current.length} queued ICE candidates`);
    
    for (const candidate of iceCandidateQueueRef.current) {
      try {
        await peerConnectionRef.current.addIceCandidate(new RTCIceCandidate(candidate));
        console.log('[P2P] Added queued ICE candidate');
      } catch (error) {
        console.error('[P2P] Error adding queued ICE candidate:', error);
      }
    }
    
    iceCandidateQueueRef.current = [];
  }, []);

  // Update user status when call starts/ends
  // NOTE: women_availability is handled by DB trigger on video_call_sessions changes
  // This function only handles user_status recalculation
  const syncCallStatus = useCallback(async (callActive: boolean) => {
    try {
      const now = new Date().toISOString();
      
      // Always recalculate status from actual DB counts for BOTH users
      for (const uid of [currentUserId, remoteUserId]) {
        const [{ count: chatCount }, { count: callCount }] = await Promise.all([
          supabase.from('active_chat_sessions').select('*', { count: 'exact', head: true }).or(`man_user_id.eq.${uid},woman_user_id.eq.${uid}`).eq('status', 'active'),
          supabase.from('video_call_sessions').select('*', { count: 'exact', head: true }).or(`man_user_id.eq.${uid},woman_user_id.eq.${uid}`).eq('status', 'active'),
        ]);
        
        const totalVideoCalls = callCount || 0;
        const totalChats = chatCount || 0;
        
        // Status rules: any video call = busy, 3+ chats = busy, else online
        let statusText = 'online';
        if (totalVideoCalls > 0) {
          statusText = 'busy';
        } else if (totalChats >= 3) {
          statusText = 'busy';
        }
        
        await supabase.from('user_status').update({
          status_text: statusText,
          last_seen: now,
        }).eq('user_id', uid);

        // Also update women_availability for accurate call/chat availability flags
        await supabase
          .from('women_availability')
          .update({
            current_call_count: totalVideoCalls,
            is_available: totalChats < 3 && totalVideoCalls === 0,
            is_available_for_calls: totalVideoCalls === 0,
          })
          .eq('user_id', uid);
      }
    } catch (err) {
      console.error('[P2P] Error syncing call status:', err);
    }
  }, [currentUserId, remoteUserId]);

  // Helper: safely assign stream to a video element and force play
  const bindStreamToVideo = useCallback((video: HTMLVideoElement | null, stream: MediaStream | null) => {
    if (!video || !stream) return;
    if (video.srcObject === stream) {
      // Already bound — just make sure it's playing
      if (video.paused) {
        video.play().catch(() => {});
      }
      return;
    }
    video.srcObject = stream;
    // Force play with muted-fallback for iOS Safari autoplay restrictions
    const attemptPlay = () => {
      video.play().catch(() => {
        // iOS blocks unmuted autoplay; try muted then unmute after play
        video.muted = true;
        video.play().then(() => {
          // Unmute after playback starts (user already interacted to accept call)
          setTimeout(() => { video.muted = false; }, 300);
        }).catch(err => {
          console.warn('[P2P] Video play failed even muted:', err);
        });
      });
    };
    // If metadata not ready yet, wait for it
    if (video.readyState >= 2) {
      attemptPlay();
    } else {
      video.addEventListener('loadedmetadata', attemptPlay, { once: true });
    }
  }, []);

  // Create peer connection with all event handlers
  const createPeerConnection = useCallback(async (localStream: MediaStream) => {
    console.log('[P2P] Creating peer connection...');
    const pc = new RTCPeerConnection(ICE_SERVERS);

    // AUD-F-001 FIX: Filter tracks by kind for audio-only calls
    localStream.getTracks()
      .filter(t => !audioOnly || t.kind === 'audio')
      .forEach(track => {
        console.log('[P2P] Adding local track:', track.kind);
        pc.addTrack(track, localStream);
      });

    // Handle incoming remote stream
    pc.ontrack = (event) => {
      console.log('[P2P] Received remote track:', event.track.kind);

      // Some browsers may provide empty event.streams on one side.
      // Build/fallback to a persistent remote MediaStream to avoid black screen.
      const incomingStream = event.streams?.[0] ?? remoteStreamRef.current ?? new MediaStream();

      if (!event.streams?.[0]) {
        incomingStream.addTrack(event.track);
      }

      remoteStreamRef.current = incomingStream;
      setRemoteStream(incomingStream);
      bindStreamToVideo(remoteVideoRef.current, incomingStream);
      setState(prev => ({ ...prev, callStatus: 'active', isConnected: true }));
      // Sync status to busy when call becomes active
      syncCallStatus(true);
    };

    // Handle ICE candidates - send to remote peer via signaling
    pc.onicecandidate = async (event) => {
      if (event.candidate) {
        console.log('[P2P] Sending ICE candidate');
        await sendSignal('ice-candidate', {
          candidate: event.candidate.toJSON(),
          senderId: currentUserId,
        });
      }
    };

    // Monitor connection state
    pc.onconnectionstatechange = () => {
      console.log('[P2P] Connection state:', pc.connectionState);
      if (pc.connectionState === 'connected') {
        setState(prev => ({ ...prev, callStatus: 'active', isConnected: true }));
        toast({
          title: "Connected",
          description: "Video call connected successfully",
        });
      } else if (pc.connectionState === 'disconnected') {
        toast({
          title: "Connection Lost",
          description: "Attempting to reconnect...",
        });
      } else if (pc.connectionState === 'failed') {
        toast({
          title: "Connection Failed",
          description: "Could not establish video connection",
          variant: "destructive",
        });
        setState(prev => ({ ...prev, callStatus: 'ended' }));
        onCallEnded?.();
      }
    };

    // VID-F-005 FIX: ICE restart on connection failure
    pc.oniceconnectionstatechange = () => {
      console.log('[P2P] ICE connection state:', pc.iceConnectionState);
      if (pc.iceConnectionState === 'failed') {
        console.log('[P2P] ICE failed — attempting ICE restart');
        try {
          pc.restartIce();
          // Re-create and send a new offer with iceRestart flag
          if (isInitiator) {
            pc.createOffer({ iceRestart: true }).then(async (offer) => {
              await pc.setLocalDescription(offer);
              await sendSignal('offer', { sdp: offer, senderId: currentUserId });
              console.log('[P2P] ICE restart offer sent');
            }).catch(err => {
              console.error('[P2P] ICE restart offer failed:', err);
              toast({
                title: 'Network Traversal Failed',
                description: 'Could not re-establish media path. Please retry or switch network.',
                variant: 'destructive',
              });
            });
          }
        } catch (err) {
          console.error('[P2P] ICE restart failed:', err);
          toast({
            title: 'Network Traversal Failed',
            description: 'Could not establish media path. Please retry or switch network.',
            variant: 'destructive',
          });
        }
      }
    };

    pc.onicecandidateerror = (event) => {
      console.warn('[P2P] ICE candidate error:', {
        errorCode: event.errorCode,
        errorText: event.errorText,
        url: event.url,
      });
    };

    peerConnectionRef.current = pc;
    return pc;
  }, [currentUserId, onCallEnded, toast, syncCallStatus, bindStreamToVideo, sendSignal, isInitiator, audioOnly]);

  // VID-F-008 FIX: Use ref for sendOffer so signaling channel always calls latest version
  const sendOfferRef = useRef<() => Promise<void>>(async () => {});

  // VID-F-009 FIX: Guard against concurrent createOffer calls
  const isCreatingOfferRef = useRef(false);

  // Send/re-send offer (used for initial dial + peer-ready handshake)
  const sendOffer = useCallback(async () => {
    const pc = peerConnectionRef.current;
    const channel = signalChannelRef.current;

    if (!pc || !channel) {
      console.warn('[P2P] Cannot send offer: peer connection or signaling channel not ready');
      return;
    }

    // VID-F-009 FIX: prevent concurrent createOffer
    if (isCreatingOfferRef.current) {
      console.log('[P2P] createOffer already in progress, re-sending existing description');
      if (pc.localDescription && pc.localDescription.type === 'offer') {
        await sendSignal('offer', { sdp: pc.localDescription.toJSON(), senderId: currentUserId });
      }
      return;
    }

    let offerSdp: RTCSessionDescriptionInit | null = pc.localDescription?.toJSON() ?? null;

    if (!offerSdp || offerSdp.type !== 'offer') {
      console.log('[P2P] Creating fresh offer...');
      isCreatingOfferRef.current = true;
      try {
        const offer = await pc.createOffer({
          offerToReceiveAudio: true,
          offerToReceiveVideo: true,
        });
        await pc.setLocalDescription(offer);
        offerSdp = offer;
        console.log('[P2P] Set local description (offer)');
      } finally {
        isCreatingOfferRef.current = false;
      }
    } else {
      console.log('[P2P] Re-sending existing local offer');
    }

    await sendSignal('offer', { sdp: offerSdp, senderId: currentUserId });

    setState(prev => ({
      ...prev,
      isConnecting: false,
      callStatus: prev.callStatus === 'active' ? prev.callStatus : 'ringing'
    }));
  }, [currentUserId]);

  // Keep sendOfferRef in sync
  useEffect(() => {
    sendOfferRef.current = sendOffer;
  }, [sendOffer]);

  const stopOfferRetry = useCallback(() => {
    if (offerRetryTimerRef.current) {
      clearInterval(offerRetryTimerRef.current);
      offerRetryTimerRef.current = null;
    }
    offerRetryAttemptsRef.current = 0;
  }, []);

  const stopAnswerRetry = useCallback(() => {
    if (answerRetryTimerRef.current) {
      clearInterval(answerRetryTimerRef.current);
      answerRetryTimerRef.current = null;
    }
    answerRetryAttemptsRef.current = 0;
  }, []);

  const sendAnswer = useCallback(async (answer?: RTCSessionDescriptionInit) => {
    const channel = signalChannelRef.current;
    const pc = peerConnectionRef.current;

    const answerSdp =
      answer ??
      lastLocalAnswerRef.current ??
      pc?.localDescription?.toJSON() ??
      null;

    if (!channel || !answerSdp || answerSdp.type !== 'answer') {
      return;
    }

    await sendSignal('answer', { sdp: answerSdp, senderId: currentUserId });
  }, [currentUserId]);

  const startOfferRetry = useCallback(() => {
    if (!isInitiator || offerRetryTimerRef.current) {
      return;
    }

    offerRetryAttemptsRef.current = 0;
    offerRetryTimerRef.current = setInterval(async () => {
      const pc = peerConnectionRef.current;
      if (!pc) return;

      if (pc.remoteDescription || pc.connectionState === 'connected') {
        stopOfferRetry();
        return;
      }

      offerRetryAttemptsRef.current += 1;
      console.log(`[P2P] Offer retry ${offerRetryAttemptsRef.current}/${MAX_OFFER_RETRIES}`);

      try {
        await sendOffer();
      } catch (error) {
        console.error('[P2P] Offer retry failed:', error);
      }

      if (offerRetryAttemptsRef.current >= MAX_OFFER_RETRIES) {
        stopOfferRetry();
        console.warn('[P2P] Offer retries exhausted after full incoming-call window; ending call setup');
        setState(prev => ({ ...prev, isConnecting: false, callStatus: 'ended' }));
        toast({
          title: 'Connection Timeout',
          description: 'The other user did not answer the call in time.',
          variant: 'destructive',
        });
        onCallEnded?.();
      }
    }, OFFER_RETRY_INTERVAL_MS);
  }, [isInitiator, onCallEnded, sendOffer, stopOfferRetry, toast]);

  const startAnswerRetry = useCallback(() => {
    if (isInitiator || answerRetryTimerRef.current) {
      return;
    }

    answerRetryAttemptsRef.current = 0;
    answerRetryTimerRef.current = setInterval(async () => {
      const pc = peerConnectionRef.current;
      if (!pc) return;

      if (pc.connectionState === 'connected') {
        stopAnswerRetry();
        return;
      }

      answerRetryAttemptsRef.current += 1;
      console.log(`[P2P] Answer retry ${answerRetryAttemptsRef.current}/${MAX_ANSWER_RETRIES}`);

      try {
        await sendAnswer();
      } catch (error) {
        console.error('[P2P] Answer retry failed:', error);
      }

      if (answerRetryAttemptsRef.current >= MAX_ANSWER_RETRIES) {
        stopAnswerRetry();
        console.warn('[P2P] Answer retries exhausted; waiting for new offer');
      }
    }, ANSWER_RETRY_INTERVAL_MS);
  }, [isInitiator, sendAnswer, stopAnswerRetry]);

  // Setup signaling channel via Supabase Realtime
  const setupSignaling = useCallback(async () => {
    console.log('[P2P] Setting up signaling channel:', callId);

    const channel = supabase.channel(`p2p-signal-${callId}`, {
      config: { broadcast: { self: false } }
    });

    channel
      // Handle incoming SDP offer (for receiver)
      .on('broadcast', { event: 'offer' }, async ({ payload }) => {
        console.log('[P2P] Received offer from:', payload.senderId);
        if (peerConnectionRef.current && payload.senderId !== currentUserId) {
          try {
            if (peerConnectionRef.current.remoteDescription) {
              console.log('[P2P] Ignoring duplicate offer (remote description already set)');
              return;
            }

            await peerConnectionRef.current.setRemoteDescription(
              new RTCSessionDescription(payload.sdp)
            );
            console.log('[P2P] Set remote description (offer)');

            // Process any queued ICE candidates
            await processIceCandidateQueue();

            // Create and send answer
            const answer = await peerConnectionRef.current.createAnswer();
            await peerConnectionRef.current.setLocalDescription(answer);
            lastLocalAnswerRef.current = answer;
            console.log('[P2P] Created and set local description (answer)');

            await sendAnswer(answer);
            startAnswerRetry();
          } catch (error) {
            console.error('[P2P] Error handling offer:', error);
          }
        }
      })
      // Handle incoming SDP answer (for initiator)
      .on('broadcast', { event: 'answer' }, async ({ payload }) => {
        console.log('[P2P] Received answer from:', payload.senderId);
        if (peerConnectionRef.current && payload.senderId !== currentUserId) {
          try {
            if (peerConnectionRef.current.remoteDescription) {
              console.log('[P2P] Ignoring duplicate answer (remote description already set)');
              return;
            }

            await peerConnectionRef.current.setRemoteDescription(
              new RTCSessionDescription(payload.sdp)
            );
            console.log('[P2P] Set remote description (answer)');
            stopOfferRetry();

            await sendSignal('answer-ack', { senderId: currentUserId });

            // Process any queued ICE candidates
            await processIceCandidateQueue();
          } catch (error) {
            console.error('[P2P] Error handling answer:', error);
          }
        }
      })
      // Receiver notifies initiator it is ready; initiator re-sends offer safely
      // VID-F-008 FIX: Use ref to always call latest sendOffer
      .on('broadcast', { event: 'peer-ready' }, async ({ payload }) => {
        if (payload.senderId !== currentUserId && isInitiator) {
          console.log('[P2P] Peer is ready, sending/re-sending offer');
          try {
            await sendOfferRef.current();
          } catch (error) {
            console.error('[P2P] Error sending offer on peer-ready:', error);
          }
        }
      })
      .on('broadcast', { event: 'answer-ack' }, ({ payload }) => {
        if (payload.senderId !== currentUserId && !isInitiator) {
          console.log('[P2P] Answer acknowledged by initiator');
          stopAnswerRetry();
        }
      })
      // Handle incoming ICE candidates
      .on('broadcast', { event: 'ice-candidate' }, async ({ payload }) => {
        if (payload.senderId !== currentUserId) {
          console.log('[P2P] Received ICE candidate');

          if (peerConnectionRef.current?.remoteDescription) {
            try {
              await peerConnectionRef.current.addIceCandidate(
                new RTCIceCandidate(payload.candidate)
              );
              console.log('[P2P] Added ICE candidate');
            } catch (error) {
              console.error('[P2P] Error adding ICE candidate:', error);
            }
          } else {
            // Queue candidate if remote description not set yet
            console.log('[P2P] Queuing ICE candidate (remote description not set)');
            iceCandidateQueueRef.current.push(payload.candidate);
          }
        }
      })
      // Handle call ended signal
      .on('broadcast', { event: 'call-ended' }, ({ payload }) => {
        if (payload.senderId !== currentUserId) {
          console.log('[P2P] Remote peer ended call');
          toast({
            title: "Call Ended",
            description: "The other user ended the call",
          });
          setState(prev => ({ ...prev, callStatus: 'ended' }));
          onCallEnded?.();
        }
      });

    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('Signaling subscribe timeout'));
      }, 10000);

      channel.subscribe((status) => {
        console.log('[P2P] Signaling channel status:', status);

        if (status === 'SUBSCRIBED') {
          clearTimeout(timeout);
          resolve();
          return;
        }

        if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT' || status === 'CLOSED') {
          clearTimeout(timeout);
          reject(new Error(`Signaling subscribe failed: ${status}`));
        }
      });
    });

    signalChannelRef.current = channel;
    return channel;
  }, [callId, currentUserId, processIceCandidateQueue, onCallEnded, toast, isInitiator, sendOffer, stopOfferRetry, sendAnswer, startAnswerRetry, stopAnswerRetry]);

  // Start call (initiator creates offer)
  const startCall = useCallback(async () => {
    try {
      console.log('[P2P] Starting call as initiator...');
      setState(prev => ({ ...prev, isConnecting: true, callStatus: 'connecting' }));

      // NOTE: Do NOT update DB status to 'connecting' here.
      // The session must remain 'ringing' in the DB so the receiver's
      // useIncomingCalls INSERT listener sees status='ringing' and shows the popup.
      // The status will transition to 'active' when the receiver accepts.

      // Initialize media and signaling
      const localStream = await initLocalMedia();
      await setupSignaling();
      await createPeerConnection(localStream);

      // Initial offer send; if receiver subscribes late, peer-ready handler and retry loop will re-send
      await sendOffer();
      startOfferRetry();
    } catch (error) {
      console.error('[P2P] Error starting call:', error);
      // VID-F-006 FIX: cleanup media tracks on signaling failure
      if (localStreamRef.current) {
        localStreamRef.current.getTracks().forEach(t => t.stop());
        localStreamRef.current = null;
      }
      if (peerConnectionRef.current) { peerConnectionRef.current.close(); peerConnectionRef.current = null; }
      if (signalChannelRef.current) { supabase.removeChannel(signalChannelRef.current); signalChannelRef.current = null; }
      setState(prev => ({ ...prev, isConnecting: false, callStatus: 'ended' }));
      toast({
        title: "Error",
        description: "Failed to start video call",
        variant: "destructive",
      });
    }
  }, [callId, initLocalMedia, setupSignaling, createPeerConnection, sendOffer, startOfferRetry, toast]);

  // Join call (receiver waits for offer)
  const joinCall = useCallback(async () => {
    try {
      console.log('[P2P] Joining call as receiver...');
      setState(prev => ({ ...prev, isConnecting: true, callStatus: 'connecting' }));

      // IMPORTANT: do not downgrade DB status back to "connecting" on receiver side.
      // The women-side accept flow already marks session as "active" before this hook mounts.
      // Overwriting it here causes active -> connecting flicker and can collapse call UI state.

      // Initialize media and signaling
      const localStream = await initLocalMedia();
      await setupSignaling();
      await createPeerConnection(localStream);

      // Tell initiator we're ready (safe point to (re)send offer)
      await sendSignal('peer-ready', { senderId: currentUserId });

      setState(prev => ({ ...prev, isConnecting: false }));
      console.log('[P2P] Ready to receive offer');
    } catch (error) {
      console.error('[P2P] Error joining call:', error);
      // VID-F-006 FIX: cleanup media tracks on signaling failure
      if (localStreamRef.current) {
        localStreamRef.current.getTracks().forEach(t => t.stop());
        localStreamRef.current = null;
      }
      if (peerConnectionRef.current) { peerConnectionRef.current.close(); peerConnectionRef.current = null; }
      if (signalChannelRef.current) { supabase.removeChannel(signalChannelRef.current); signalChannelRef.current = null; }
      setState(prev => ({ ...prev, isConnecting: false, callStatus: 'ended' }));
      toast({
        title: "Error",
        description: "Failed to join video call",
        variant: "destructive",
      });
    }
  }, [initLocalMedia, setupSignaling, createPeerConnection, currentUserId, toast]);

  // End call and cleanup — VID-H-02: idempotency guard prevents double-update
  const endCall = useCallback(async () => {
    // VID-F-002 FIX: Use ref for idempotency guard instead of stale state
    if (callStatusRef.current === 'ended') {
      console.log('[P2P] endCall already called, skipping');
      return;
    }
    callStatusRef.current = 'ended';
    
    console.log('[P2P] Ending call...');
    setState(prev => ({ ...prev, callStatus: 'ended' }));
    
    stopOfferRetry();

    // Notify remote peer
    void sendSignal('call-ended', { senderId: currentUserId });

    // Use ref for latest duration to avoid stale closure
    const elapsedSec = callDurationRef.current;
    const durationMinutes = elapsedSec / 60;

    // Final partial-minute settlement (e.g. 1m30s → 0.5 min row).
    // Only the initiator (man's side) drives billing.
    if (isInitiator && elapsedSec >= 1) {
      try {
        const sessionId = await getSessionId();
        const [{ data: manProfile }, { data: womanProfile }] = await Promise.all([
          supabase.from('profiles').select('id').eq('user_id', currentUserId).maybeSingle(),
          supabase.from('profiles').select('id').eq('user_id', remoteUserId).maybeSingle(),
        ]);
        if (sessionId && manProfile?.id && womanProfile?.id) {
          const sType = audioOnly ? 'audio_call' : 'video_call';
          await billFinalPartialMinute(sessionId, sType, elapsedSec, manProfile.id, womanProfile.id);
        }
      } catch (err) {
        console.warn('[P2P] Final partial-minute billing failed:', err);
      }
    }

    // Update database - VID-H-02: WHERE status != 'ended' prevents overwriting ended_at
    const { data: currentSession } = await supabase
      .from('video_call_sessions')
      .select('id, status, total_minutes')
      .eq('call_id', callId)
      .neq('status', 'ended')  // VID-H-02: Only fetch if not already ended
      .maybeSingle();

    if (currentSession) {
      // Final billing removed — duration is recorded on the session row only.

      // Read back session totals (will be 0 with billing disabled)
      const { data: updatedSession } = await supabase
        .from('video_call_sessions')
        .select('total_minutes, total_earned')
        .eq('call_id', callId)
        .single();

      // VID-H-02: status != 'ended' guard ensures this is a no-op if already ended
      await supabase
        .from('video_call_sessions')
        .update({
          status: 'ended',
          ended_at: new Date().toISOString(),
          end_reason: 'user_ended',
          total_minutes: updatedSession?.total_minutes ?? durationMinutes,
          total_earned: updatedSession?.total_earned ?? 0,
        })
        .eq('call_id', callId)
        .neq('status', 'ended');  // VID-H-02: prevent overwriting if already ended
    }

    // Sync status for both users
    await syncCallStatus(false);

    cleanup();
    setState(prev => ({ ...prev, callStatus: 'ended' }));
    onCallEnded?.();
  }, [callId, currentUserId, remoteUserId, ratePerMinute, onCallEnded, syncCallStatus, stopOfferRetry, isInitiator, audioOnly, sendSignal]);

  // Toggle video on/off
  const toggleVideo = useCallback(() => {
    if (localStreamRef.current) {
      const videoTrack = localStreamRef.current.getVideoTracks()[0];
      if (videoTrack) {
        videoTrack.enabled = !videoTrack.enabled;
        setState(prev => ({ ...prev, isVideoEnabled: videoTrack.enabled }));
        console.log('[P2P] Video:', videoTrack.enabled ? 'enabled' : 'disabled');
      }
    }
  }, []);

  // Toggle audio on/off
  const toggleAudio = useCallback(() => {
    if (localStreamRef.current) {
      const audioTrack = localStreamRef.current.getAudioTracks()[0];
      if (audioTrack) {
        audioTrack.enabled = !audioTrack.enabled;
        setState(prev => ({ ...prev, isAudioEnabled: audioTrack.enabled }));
        console.log('[P2P] Audio:', audioTrack.enabled ? 'enabled' : 'disabled');
      }
    }
  }, []);

  // Cleanup all resources
  const cleanup = useCallback(() => {
    console.log('[P2P] Cleaning up...');
    
    if (callTimerRef.current) {
      clearInterval(callTimerRef.current);
      callTimerRef.current = null;
    }

    if (billingTimerRef.current) {
      clearInterval(billingTimerRef.current);
      billingTimerRef.current = null;
    }

    stopOfferRetry();
    stopAnswerRetry();

    if (localStreamRef.current) {
      localStreamRef.current.getTracks().forEach(track => {
        track.stop();
        console.log('[P2P] Stopped track:', track.kind);
      });
      localStreamRef.current = null;
    }

    if (peerConnectionRef.current) {
      peerConnectionRef.current.close();
      peerConnectionRef.current = null;
    }

    if (signalChannelRef.current) {
      supabase.removeChannel(signalChannelRef.current);
      signalChannelRef.current = null;
    }

    lastLocalAnswerRef.current = null;
    iceCandidateQueueRef.current = [];
    remoteStreamRef.current = null;
    setRemoteStream(null);
  }, [stopOfferRetry, stopAnswerRetry]);

  // Ensure streams bind even if video refs mount after media events
  useEffect(() => {
    bindStreamToVideo(localVideoRef.current, localStreamRef.current);
    bindStreamToVideo(remoteVideoRef.current, remoteStream);
  }, [remoteStream, state.callStatus, state.isConnecting, bindStreamToVideo]);

  // Auto-start based on role (initiator vs receiver)
  useEffect(() => {
    if (isInitiator) {
      startCall();
    } else {
      joinCall();
    }

    return cleanup;
  }, []);

  // Subscribe to call status updates from database
  useEffect(() => {
    const channel = supabase
      .channel(`p2p-call-status-${callId}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'video_call_sessions',
          filter: `call_id=eq.${callId}`
        },
        (payload) => {
          const status = payload.new.status;
          console.log('[P2P] Call status update from DB:', status);
          
          if (['declined', 'missed', 'ended', 'timeout_cleanup'].includes(status)) {
            // Use ref to avoid stale closure — ensures we always check latest status
            if (callStatusRef.current !== 'ended') {
              console.log('[P2P] Remote party ended/declined call, closing locally');
              toast({
                title: "Call Ended",
                description: status === 'declined' ? 'Call was declined' : status === 'missed' ? 'Call was missed' : 'The other user ended the call',
              });
              cleanup();
              callStatusRef.current = 'ended';
              setState(prev => ({ ...prev, callStatus: 'ended' }));
              onCallEnded?.();
            }
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [callId, cleanup, onCallEnded, toast]);

  return {
    ...state,
    localVideoRef,
    remoteVideoRef,
    localStream: localStreamRef.current,
    remoteStream,
    bindStreamToVideo,
    startCall,
    joinCall,
    endCall,
    toggleVideo,
    toggleAudio,
    cleanup,
  };
};

export default useP2PCall;
