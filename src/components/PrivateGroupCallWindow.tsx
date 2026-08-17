import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
/**
 * PrivateGroupCallWindow
 * 
 * Live-stream style private group call UI with:
 * - Full-screen host video
 * - Floating danmu/bullet chat comments overlaying the video
 * - Emoji/like reactions bubbling up
 * - Animated gift overlays on screen
 * - Elapsed time display (no hard time limit — sessions end when host stops or at midnight IST)
 * - 100 participant limit
 * - Refund handling when host ends early
 * - One extension per month with reason
 */

import { useState, useEffect, useRef, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { registerSession, unregisterSession } from '@/hooks/useSessionPriority';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { toast } from 'sonner';
import { 
  Video, VideoOff, Mic, MicOff, PhoneOff, Users, Radio, Loader2,
  X, Send, Maximize2, Minimize2, Clock, Gift, DollarSign, Heart, ArrowUpDown, Circle
} from 'lucide-react';
import { usePrivateGroupCall, MAX_PARTICIPANTS } from '@/hooks/usePrivateGroupCall';
import { cn } from '@/lib/utils';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';

// ─── Types ───────────────────────────────────────────────────────

interface GiftItem {
  id: string;
  name: string;
  emoji: string;
  price: number;
}

interface ChatMessage {
  id: string;
  senderName: string;
  text: string;
  createdAt: number;
  isSelf: boolean;
}

interface FloatingReaction {
  id: string;
  emoji: string;
  left: number; // percentage from left
  createdAt: number;
}

interface AnimatedGift {
  id: string;
  senderName: string;
  emoji: string;
  name: string;
  price: number;
  createdAt: number;
}

// ExtensionRecord is now stored in DB table group_session_extensions

interface PrivateGroupCallWindowProps {
  group: {
    id: string;
    name: string;
    participant_count: number;
    is_live: boolean;
    stream_id: string | null;
    access_type: string;
    min_gift_amount: number;
    owner_id: string;
    owner_language?: string | null;
  };
  currentUserId: string;
  userName: string;
  userPhoto: string | null;
  onClose: () => void;
  isOwner: boolean;
  preAcquiredStream?: MediaStream | null;
}

// ─── Quick Emoji Reactions ───────────────────────────────────────
const QUICK_EMOJIS = ['❤️', '🔥', '😂', '👏', '😍', '🎉'];

// ─── Component ───────────────────────────────────────────────────

export function PrivateGroupCallWindow({
  group,
  currentUserId,
  userName,
  userPhoto,
  onClose,
  isOwner,
  preAcquiredStream = null,
}: PrivateGroupCallWindowProps) {
  // Comment input — invisible, captures keystrokes directly
  const [commentText, setCommentText] = useState('');
  const hiddenInputRef = useRef<HTMLInputElement>(null);

  // Chat messages & overlays
  const [chatMessages, setChatMessages] = useState<ChatMessage[]>([]);
  const [floatingReactions, setFloatingReactions] = useState<FloatingReaction[]>([]);
  const [animatedGifts, setAnimatedGifts] = useState<AnimatedGift[]>([]);
  const chatScrollRef = useRef<HTMLDivElement>(null);

  // UI state
  const [isVideoEnabled, setIsVideoEnabled] = useState(true);
  const [isAudioEnabled, setIsAudioEnabled] = useState(isOwner); // Only host mic enabled by default
  const isStoppingRef = useRef(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [showGiftDialog, setShowGiftDialog] = useState(false);
  const [gifts, setGifts] = useState<GiftItem[]>([]);
  const [showEmojiBar, setShowEmojiBar] = useState(false);
  // GRP-F-007 FIX: Removed unused isScreenSharing (was misleadingly named)
  const [isScrollEnabled, setIsScrollEnabled] = useState(true);
  const [showParticipantList, setShowParticipantList] = useState(false);

  // Extension state
  const [canExtendThisMonth, setCanExtendThisMonth] = useState(true);
  const [liveSeconds, setLiveSeconds] = useState(0);

  const hasVideo = group.access_type === 'video' || group.access_type === 'both';

  // Enhanced group call hook
  const {
    isConnecting,
    isConnected,
    isLive,
    participants,
    viewerCount,
    error,
    remainingTime,
    totalEarnings,
    isRefunding,
    localVideoRef,
    remoteVideoRef,
    hostStream,
    hostStatus,
    goLive,
    joinStream,
    endStream,
    toggleVideo,
    toggleAudio,
    enableParticipantMic,
    cleanup,
  } = usePrivateGroupCall({
    groupId: group.id,
    groupName: group.name,
    currentUserId,
    userName,
    userPhoto,
    hostLanguage: group.owner_language || null,
    isOwner,
    giftAmountRequired: group.min_gift_amount,
    preAcquiredStream,
    onParticipantJoin: (participant) => {
      toast.success(`${participant.name} joined`);
    },
    onParticipantLeave: (participantId, reason) => {
      if (reason === 'insufficient_balance') {
        toast.info('A participant was removed (insufficient balance)');
      } else {
        toast.info('A participant left');
      }
    },
    onSessionEnd: (refunded) => {
      if (refunded && !isOwner) {
        toast.success('Call ended by host. Unused balance has been refunded.');
      }
    },
  });

  // Use ref to avoid stale closure in realtime listener
  const participantsRef = useRef(participants);
  participantsRef.current = participants;

  // Cache for sender names fetched from profiles (for users not in active media participants list)
  const nameCacheRef = useRef<Map<string, string>>(new Map());

  const getParticipantName = useCallback((userId: string): string => {
    if (userId === currentUserId) return userName;
    if (userId === group.owner_id) {
      const host = participantsRef.current.find(p => p.isOwner);
      return host?.name || nameCacheRef.current.get(userId) || 'Host';
    }
    const participant = participantsRef.current.find(p => p.id === userId);
    return participant?.name || nameCacheRef.current.get(userId) || '';
  }, [currentUserId, group.owner_id, userName]);

  // Fetch a sender's display name from profile tables and cache it
  const fetchSenderName = useCallback(async (userId: string): Promise<string> => {
    if (nameCacheRef.current.has(userId)) return nameCacheRef.current.get(userId)!;
    // Try female first, then male
    const [{ data: f }, { data: m }] = await Promise.all([
      supabase.from('female_profiles').select('full_name').eq('user_id', userId).maybeSingle(),
      supabase.from('male_profiles').select('full_name').eq('user_id', userId).maybeSingle(),
    ]);
    const name = (f?.full_name || m?.full_name || 'User').trim();
    nameCacheRef.current.set(userId, name);
    return name;
  }, []);

  // Format elapsed time as MM:SS — 60 seconds = 1 minute
  const formatTime = (seconds: number) => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  // Live ticker: counts seconds while session is live (used for live billing display)
  useEffect(() => {
    if (!isLive) { setLiveSeconds(0); return; }
    const t = setInterval(() => setLiveSeconds(s => s + 1), 1000);
    return () => clearInterval(t);
  }, [isLive]);

  // ─── Add Chat Message ─────────────────────────────────────────

  const addChatMessage = useCallback((senderName: string, text: string, isSelf: boolean) => {
    const id = `msg-${Date.now()}-${Math.random()}`;
    setChatMessages(prev => [...prev.slice(-100), { id, senderName, text, createdAt: Date.now(), isSelf }]);
    // Auto-scroll to bottom
    setTimeout(() => {
      chatScrollRef.current?.scrollTo({ top: chatScrollRef.current.scrollHeight, behavior: 'smooth' });
    }, 50);
  }, []);

  // ─── Floating Emoji Reaction ─────────────────────────────────────

  const addFloatingReaction = useCallback((emoji: string) => {
    const id = `reaction-${Date.now()}-${Math.random()}`;
    const left = 75 + Math.random() * 20; // cluster on the right side
    setFloatingReactions(prev => [...prev.slice(-20), { id, emoji, left, createdAt: Date.now() }]);
    setTimeout(() => {
      setFloatingReactions(prev => prev.filter(r => r.id !== id));
    }, 3000);
  }, []);

  // ─── Animated Gift Overlay ──────────────────────────────────────

  const addAnimatedGift = useCallback((senderName: string, gift: GiftItem) => {
    const id = `gift-${Date.now()}`;
    setAnimatedGifts(prev => [...prev.slice(-5), { id, senderName, emoji: gift.emoji, name: gift.name, price: gift.price, createdAt: Date.now() }]);
    // Gift animation lasts longer for expensive gifts
    const duration = Math.min(8000, 3000 + gift.price * 30);
    setTimeout(() => {
      setAnimatedGifts(prev => prev.filter(g => g.id !== id));
    }, duration);
  }, []);

  // ─── Realtime: Listen for group_messages as floating comments ───
  // IMPORTANT: We pin all helper functions to refs so this subscription's deps
  // are STABLE (only [group.id, currentUserId]). Otherwise the channel would
  // unsubscribe + resubscribe on every render and drop messages mid-flight —
  // which is exactly why the host previously didn't see member messages.

  const handlersRef = useRef({
    addChatMessage,
    addAnimatedGift,
    addFloatingReaction,
    getParticipantName,
    fetchSenderName,
    userName,
  });
  handlersRef.current = {
    addChatMessage,
    addAnimatedGift,
    addFloatingReaction,
    getParticipantName,
    fetchSenderName,
    userName,
  };

  useEffect(() => {
    const channel = supabase
      .channel(`danmu-${group.id}-${currentUserId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'group_messages',
        filter: `group_id=eq.${group.id}`
      }, async (payload) => {
        const msg = payload.new as any;
        let text: string = msg.message || '';
        let embeddedName: string | null = null;
        const h = handlersRef.current;

        // Strip embedded sender-name prefix from text messages: __MSG__::name::body
        if (text.startsWith('__MSG__::')) {
          const idx = text.indexOf('::', 9);
          if (idx > 9) {
            embeddedName = text.slice(9, idx);
            text = text.slice(idx + 2);
            if (embeddedName) nameCacheRef.current.set(msg.sender_id, embeddedName);
          }
        }

        // Check if this is a gift broadcast message
        if (text.startsWith('__GIFT__::')) {
          const parts = text.split('::');
          const emoji = parts[1] || '🎁';
          const giftName = parts[2] || 'Gift';
          const price = parseFloat(parts[3]) || 0;
          const senderName = parts[4] || embeddedName || (msg.sender_id === currentUserId ? h.userName : h.getParticipantName(msg.sender_id)) || await h.fetchSenderName(msg.sender_id);

          if (msg.sender_id !== currentUserId) {
            h.addAnimatedGift(senderName, { id: msg.id, emoji, name: giftName, price });
          }
          h.addChatMessage(senderName, `🎁 sent ${emoji} ${giftName}`, msg.sender_id === currentUserId);
          return;
        }

        // Quick emoji reaction → floating bubble (still also show in chat for everyone except sender)
        if (msg.sender_id !== currentUserId && QUICK_EMOJIS.includes(text)) {
          h.addFloatingReaction(text);
          return;
        }

        // Regular text message — show for EVERYONE except the sender (sender sees optimistic copy)
        if (msg.sender_id !== currentUserId) {
          let name = embeddedName || h.getParticipantName(msg.sender_id);
          if (!name) name = await h.fetchSenderName(msg.sender_id);
          h.addChatMessage(name, text, false);
        }
      })
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          console.log('[GroupChat] Subscribed to messages for group', group.id);
        } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
          console.warn('[GroupChat] Channel issue:', status);
        }
      });

    return () => { supabase.removeChannel(channel); };
  }, [group.id, currentUserId]);


  // Extension check — query DB instead of localStorage
  // NOTE: getMonth() is 0-indexed; DB stores 1-indexed months
  useEffect(() => {
    const now = new Date();
    const checkExtension = async () => {
      const { data } = await supabase
        .from('group_session_extensions')
        .select('id')
        .eq('user_id', currentUserId)
        .eq('group_id', group.id)
        .eq('extension_month', now.getMonth() + 1) // 1-indexed for DB
        .eq('extension_year', now.getFullYear())
        .maybeSingle();
      if (data) {
        setCanExtendThisMonth(false);
      }
    };
    checkExtension();
  }, [currentUserId, group.id]);

  // Register/unregister P3 session for priority management
  useEffect(() => {
    if (isConnected || isLive) {
      registerSession('private_group_call', group.id);
    }
    return () => {
      unregisterSession('private_group_call', group.id);
    };
  }, [isConnected, isLive, group.id]);

  // Auto-start
  const hasAutoStarted = useRef(false);
  useEffect(() => {
    if (hasAutoStarted.current) return;
    if (isOwner && !isConnected && !isConnecting && !isLive) {
      hasAutoStarted.current = true;
      goLive().then(success => {
        if (!success) {
          toast.error('Failed to go live. Please try again.');
          onClose();
        }
      }).catch(() => {
        toast.error('Failed to go live. Please try again.');
        onClose();
      });
    } else if (hasVideo && !isOwner && group.is_live && !isConnected && !isConnecting) {
      hasAutoStarted.current = true;
      joinStream();
    }
  }, [isOwner, group.is_live, isConnected, isConnecting, joinStream, hasVideo, goLive, isLive]);

  // Attach host stream
  useEffect(() => {
    if (hostStream && remoteVideoRef.current) {
      remoteVideoRef.current.srcObject = hostStream;
      remoteVideoRef.current.play().catch(() => {});
    }
  }, [hostStream]);

  useEffect(() => {
    if (error) toast.error(error);
  }, [error]);

  // Notify participants of host status changes
  const prevHostStatusRef = useRef(hostStatus);
  useEffect(() => {
    if (isOwner) return;
    const prev = prevHostStatusRef.current;
    if (prev === hostStatus) return;
    prevHostStatusRef.current = hostStatus;
    if (hostStatus === 'away') toast.info('Host stepped away');
    else if (hostStatus === 'muted') toast.info('Host muted their mic');
    else if (hostStatus === 'camera-off') toast.info('Host turned off camera');
    else if (hostStatus === 'live' && prev !== 'live') toast.success('Host is back');
  }, [hostStatus, isOwner]);

  // Fetch gifts
  useEffect(() => {
    const fetchGifts = async () => {
      const { data } = await supabase
        .from('gifts')
        .select('id, name, emoji, price')
        .eq('is_active', true)
        .order('price', { ascending: true });
      if (data) setGifts(data);
    };
    fetchGifts();
  }, []);

  // ─── Handlers ──────────────────────────────────────────────────

  const handleSendComment = async () => {
    if (!commentText.trim()) return;

    const { moderateMessage } = await import('@/lib/content-moderation');
    const moderationResult = moderateMessage(commentText.trim());
    if (moderationResult.isBlocked) {
      toast.error(moderationResult.reason || 'This message contains prohibited content.');
      return;
    }

    const text = commentText.trim();
    setCommentText('');

    // Optimistic: show own message immediately
    addChatMessage(userName, text, true);

    // Persist to DB with embedded sender name (so all recipients see real name even
    // if the sender hasn't joined the WebRTC media stream yet)
    const wireText = `__MSG__::${userName}::${text}`;
    supabase
      .from('group_messages')
      .insert({ group_id: group.id, sender_id: currentUserId, message: wireText })
      .then(({ error }) => { if (error) console.error('Failed to send comment', error); });
  };

  const handleSendReaction = (emoji: string) => {
    addFloatingReaction(emoji);
    // Persist as a group message so others see it
    supabase
      .from('group_messages')
      .insert({ group_id: group.id, sender_id: currentUserId, message: emoji })
      .then(({ error }) => { if (error) console.error('Failed to send reaction', error); });
  };

  const handleSendGift = async (gift: GiftItem) => {
    try {
      // Resolve sender (man) profile id; host is resolved server-side from private_groups.current_host_id
      const { data: manProf } = await supabase
        .from('profiles').select('id').eq('user_id', currentUserId).maybeSingle();
      if (!manProf?.id) throw new Error('Profile not found');

      // Reference ID must be unique per send to avoid idempotency dedup (catalog gift.id is reused)
      const uniqueRef = (typeof crypto !== 'undefined' && crypto.randomUUID)
        ? `gift_${group.id}_${gift.id}_${crypto.randomUUID()}`
        : `gift_${group.id}_${gift.id}_${Date.now()}_${Math.random().toString(36).slice(2)}`;
      const { data, error } = await supabase.rpc('bill_group_gift_or_tip', {
        p_group_id: group.id,
        p_man_id: manProf.id,
        p_amount: gift.price ?? 0,
        p_type: 'gift',
        p_description: `Group gift: ${gift.name ?? gift.emoji}`,
        p_reference_id: uniqueRef,
      });

      if (error) throw error;
      const result = data as { success: boolean; error?: string };

      if (result.success) {
        // Show gift locally for sender immediately
        addAnimatedGift(userName, gift);
        toast.success(`${gift.emoji} Gift sent!`);
        setShowGiftDialog(false);

        // Broadcast gift to all participants via group_messages with a special prefix
        // Include sender's actual name so all recipients display it correctly
        const { error: msgErr } = await supabase
          .from('group_messages')
          .insert({
            group_id: group.id,
            sender_id: currentUserId,
            message: `__GIFT__::${gift.emoji}::${gift.name}::${gift.price}::${userName}`,
          });
        if (msgErr) console.error('Failed to broadcast gift message:', msgErr);
      } else {
        toast.error(result.error || 'Failed to send gift');
      }
    } catch (error: any) {
      toast.error('Gift not sent', { description: classifyError(error, 'send the gift').message });
    }
  };

  const handleGoLive = async () => {
    const success = await goLive();
    if (success) toast.success('You are now live!');
  };

  const confirmEndWithMembers = (): boolean => {
    if (!isOwner || !isLive) return true;
    const memberCount = participants.filter(p => !p.isOwner).length;
    if (memberCount === 0) return true;
    return window.confirm(
      `${memberCount} member${memberCount === 1 ? ' is' : 's are'} currently in your group call. ` +
      `Ending the call will disconnect everyone. Continue?`
    );
  };

  const handleEndStream = async () => {
    if (isStoppingRef.current) return;
    if (!confirmEndWithMembers()) return;
    isStoppingRef.current = true;
    try { await endStream(true); } catch (err) { console.error(err); }
    toast.success('Stream ended');
    onClose();
  };

  const handleToggleVideo = () => {
    if (!isOwner) return;
    const newState = !isVideoEnabled;
    setIsVideoEnabled(newState);
    toggleVideo(newState);
  };

  const handleToggleAudio = () => {
    const newState = !isAudioEnabled;
    setIsAudioEnabled(newState);
    toggleAudio(newState);
  };

  const handleClose = async () => {
    if (isStoppingRef.current) return;
    if (isOwner && isLive && !confirmEndWithMembers()) return;
    isStoppingRef.current = true;
    try {
      // Participant clicking close = manual leave → revoke group access
      if (isOwner && isLive) { await endStream(true); } else { cleanup(true); }
    } catch (err) {
      console.error(err);
    }
    onClose();
  };

  // ─── Render ────────────────────────────────────────────────────

  return (
    <div className={cn(
      "fixed inset-0 z-[130] flex flex-col overflow-hidden select-none bg-black",
    )}>
      {/* ─── Video Layer (Full Background) ───────────────────────── */}
      <div className="absolute inset-0">
        {isOwner ? (
          <div className="relative w-full h-full">
            <video
              ref={localVideoRef}
              autoPlay muted playsInline
              className="w-full h-full object-cover"
            />
            {!isVideoEnabled && (
              <div className="absolute inset-0 flex items-center justify-center bg-gray-900">
                <Avatar className="h-28 w-28 ring-4 ring-white/20">
                  <AvatarImage src={userPhoto || undefined} />
                  <AvatarFallback className="text-4xl bg-gradient-to-br from-primary to-accent">{userName[0]}</AvatarFallback>
                </Avatar>
              </div>
            )}
          </div>
        ) : (
          <div className="relative w-full h-full">
            {isConnected && hostStream ? (
              <video
                ref={(el) => {
                  if (el) {
                    if (remoteVideoRef && 'current' in remoteVideoRef) {
                      (remoteVideoRef as React.MutableRefObject<HTMLVideoElement | null>).current = el;
                    }
                    if (hostStream && el.srcObject !== hostStream) {
                      el.srcObject = hostStream;
                      el.play().catch(() => {});
                    }
                  }
                }}
                autoPlay playsInline muted={false}
                className="w-full h-full object-cover"
              />
            ) : (
              <div className="w-full h-full flex items-center justify-center bg-gray-900">
                <div className="text-center text-white">
                  <Avatar className="h-28 w-28 mx-auto mb-4 ring-4 ring-white/20">
                    <AvatarImage src={participants.find(p => p.isOwner)?.photo} />
                    <AvatarFallback className="text-4xl">{participants.find(p => p.isOwner)?.name?.[0] || 'H'}</AvatarFallback>
                  </Avatar>
                  <Loader2 className="h-8 w-8 mx-auto animate-spin text-primary" />
                  <p className="text-sm text-gray-400 mt-3">Connecting to host...</p>
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* ─── Gradient Overlays for Readability ────────────────────── */}
      <div className="absolute inset-x-0 top-0 h-20 bg-gradient-to-b from-black/50 to-transparent pointer-events-none z-10" />
      <div className="absolute inset-x-0 bottom-0 h-32 bg-gradient-to-t from-black/40 to-transparent pointer-events-none z-10" />

      {/* ─── Top Bar (WhatsApp-style) ─────────────────────────────── */}
      <div className="relative z-20 flex items-center justify-between px-4 py-2.5 bg-gradient-to-b from-black/70 to-transparent">
        <div className="flex items-center gap-2">
          <Avatar className="h-9 w-9 ring-2 ring-accent">
            <AvatarImage src={isOwner ? (userPhoto || undefined) : participants.find(p => p.isOwner)?.photo} />
            <AvatarFallback className="text-xs bg-primary text-primary-foreground">
              {isOwner ? userName[0] : (participants.find(p => p.isOwner)?.name?.[0] || 'H')}
            </AvatarFallback>
          </Avatar>
          <div>
            <p className="text-white text-sm font-semibold leading-tight">{group.name}</p>
            <div className="flex items-center gap-1.5 mt-0.5">
              {isLive && (
                <Badge className="bg-accent text-accent-foreground text-[10px] px-1.5 py-0 h-4 gap-0.5 border-0">
                  <Radio className="h-2.5 w-2.5 animate-pulse" /> LIVE
                </Badge>
              )}
              {hostStatus && hostStatus !== 'live' && (
                <Badge
                  className={`text-[10px] px-1.5 py-0 h-4 gap-0.5 border-0 ${
                    hostStatus === 'away' ? 'bg-amber-500 text-black' :
                    hostStatus === 'muted' ? 'bg-slate-600 text-white' :
                    hostStatus === 'camera-off' ? 'bg-slate-700 text-white' :
                    'bg-red-600 text-white'
                  }`}
                  title={`Host is ${hostStatus.replace('-', ' ')}`}
                >
                  {hostStatus === 'away' && 'Host away'}
                  {hostStatus === 'muted' && 'Host muted'}
                  {hostStatus === 'camera-off' && 'Camera off'}
                  {hostStatus === 'left' && 'Host left'}
                </Badge>
              )}
              <span className="text-white/70 text-[11px] flex items-center gap-0.5">
                <Users className="h-3 w-3" /> {viewerCount}
              </span>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {isLive && (() => {
            const elapsedMinFloat = liveSeconds / 60;
            const memberCost = elapsedMinFloat * 4;
            const hostEarnings = elapsedMinFloat * 0.5 * Math.max(0, viewerCount);
            return (
              <Badge variant="outline" className="text-white/90 border-accent/50 bg-black/40 text-[11px] gap-1">
                <Circle className="h-2 w-2 fill-accent text-accent animate-pulse" />
                {isOwner ? `Earned ₹${hostEarnings.toFixed(2)}` : `Spent ₹${memberCost.toFixed(2)}`}
                {' · '}{formatTime(liveSeconds)}
              </Badge>
            );
          })()}
          <Button variant="ghost" size="icon" className="text-white hover:bg-white/20 h-8 w-8" onClick={handleClose}>
            <X className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* ─── Floating Emoji Reactions ─────────────────────────────── */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none z-20">
        {floatingReactions.map((reaction) => (
          <div
            key={reaction.id}
            className="absolute animate-float-up"
            style={{ left: `${reaction.left}%`, bottom: '15%' }}
          >
            <span className="text-3xl drop-shadow-lg">{reaction.emoji}</span>
          </div>
        ))}
      </div>

      {/* ─── Animated Gift Overlay (Center Screen) ────────────────── */}
      {animatedGifts.map((gift) => (
        <div
          key={gift.id}
          className="absolute inset-0 flex items-center justify-center z-30 pointer-events-none animate-gift-entrance"
        >
          <div className="flex flex-col items-center gap-2 animate-gift-pulse">
            <span className="text-8xl drop-shadow-2xl">{gift.emoji}</span>
            <div className="bg-black/60 backdrop-blur-md rounded-2xl px-5 py-2 text-center">
              <p className="text-white font-bold text-lg">{gift.senderName}</p>
              <p className="text-amber-400 text-sm font-medium">sent {gift.name}</p>
            </div>
          </div>
        </div>
      ))}

      {/* ─── Chat Messages Panel (Bottom-Left, full height) ─────────── */}
      <div className="absolute top-16 bottom-28 left-3 z-20 w-[55%] flex flex-col">
        {/* Participant badges for host */}
        {isOwner && participants.filter(p => !p.isOwner).length > 0 && (
          <div className="flex flex-wrap gap-1 mb-1.5 shrink-0">
            {participants.filter(p => !p.isOwner).map((p) => (
              <Badge key={p.id} className="text-[9px] bg-black/30 text-white/80 border-0 backdrop-blur-sm gap-0.5 h-4">
                <div className="w-1.5 h-1.5 rounded-full bg-green-400" />
                {p.name}
              </Badge>
            ))}
          </div>
        )}
        {/* Scrollable chat — transparent scrollbar */}
        <div
          ref={chatScrollRef}
          className={cn("flex-1 space-y-0.5 pr-1", isScrollEnabled ? "overflow-y-auto" : "overflow-hidden")}
          style={{
            scrollbarWidth: 'thin',
            scrollbarColor: 'rgba(255,255,255,0.15) transparent',
          }}
        >
          {chatMessages.length === 0 && (
            <p className="text-white/40 text-xs px-2 py-1">No messages yet. Say something!</p>
          )}
          {chatMessages.map((msg) => (
            <div key={msg.id} className="px-1 py-0.5">
              <span className={cn(
                "font-bold text-xs mr-1 drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]",
                msg.isSelf ? "text-accent" : "text-amber-400"
              )}>
                {msg.senderName}:
              </span>
              <span className="text-white text-xs break-words drop-shadow-[0_1px_2px_rgba(0,0,0,0.8)]">{msg.text}</span>
            </div>
          ))}
        </div>
      </div>

      {/* ─── Bottom Controls (Over Video) ─────────────────────────── */}
      <div className="relative z-20 mt-auto">
        {/* Media Controls Bar */}
        <div className="flex items-center justify-center gap-3 px-4 py-2">
          {isConnecting && (
            <div className="flex items-center gap-2 text-white/70 text-sm">
              <Loader2 className="h-4 w-4 animate-spin" />
              Connecting...
            </div>
          )}

          {isRefunding && (
            <div className="flex items-center gap-2 text-yellow-400 text-sm">
              <Loader2 className="h-4 w-4 animate-spin" />
              Processing refunds...
            </div>
          )}

          {isOwner && (
            <Button
              variant={isVideoEnabled ? 'secondary' : 'destructive'}
              size="sm"
              onClick={handleToggleVideo}
              disabled={isConnecting}
              className="rounded-full h-10 w-10 p-0"
            >
              {isVideoEnabled ? <Video className="h-4 w-4" /> : <VideoOff className="h-4 w-4" />}
            </Button>
          )}

          {/* Scroll enable/disable toggle */}
          <Button
            variant={isScrollEnabled ? 'secondary' : 'destructive'}
            size="sm"
            onClick={() => setIsScrollEnabled(prev => !prev)}
            className="rounded-full h-10 w-10 p-0"
            title={isScrollEnabled ? 'Disable chat scroll' : 'Enable chat scroll'}
          >
            <ArrowUpDown className="h-4 w-4" />
          </Button>

          {/* Mic button — only shown for host. Participants' mics are host-controlled */}
          {isOwner && (
            <Button
              variant={isAudioEnabled ? 'secondary' : 'destructive'}
              size="sm"
              onClick={handleToggleAudio}
              disabled={isConnecting}
              className="rounded-full h-10 w-10 p-0"
              title="Toggle your mic"
            >
              {isAudioEnabled ? <Mic className="h-4 w-4" /> : <MicOff className="h-4 w-4" />}
            </Button>
          )}

          {/* Participant mic status indicator (read-only for participants) */}
          {!isOwner && (
            <div
              className={cn(
                "rounded-full h-10 w-10 p-0 flex items-center justify-center",
                isAudioEnabled ? "bg-secondary" : "bg-destructive/20"
              )}
              title={isAudioEnabled ? "Mic enabled by host" : "Mic disabled by host"}
            >
              {isAudioEnabled ? <Mic className="h-4 w-4 text-foreground" /> : <MicOff className="h-4 w-4 text-destructive" />}
            </div>
          )}

          {/* Participant list button — host only, to manage participant mics */}
          {isOwner && isConnected && participants.length > 1 && (
            <Button
              variant={showParticipantList ? 'default' : 'secondary'}
              size="sm"
              onClick={() => setShowParticipantList(prev => !prev)}
              className="rounded-full h-10 w-10 p-0"
              title="Manage participant mics"
            >
              <Users className="h-4 w-4" />
            </Button>
          )}

          {isOwner && (
            <>
              {!isLive && !isConnected ? (
                <Button
                  size="sm"
                  onClick={handleGoLive}
                  className="gap-1.5 rounded-full px-5 bg-accent hover:bg-accent/80 text-accent-foreground"
                  disabled={isConnecting}
                >
                  {isConnecting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Radio className="h-4 w-4" />}
                  Go Live
                </Button>
              ) : (
                <Button
                  variant="destructive"
                  size="sm"
                  onClick={(e) => { e.stopPropagation(); handleEndStream(); }}
                  className="gap-1.5 rounded-full px-5"
                  disabled={isRefunding}
                >
                  <PhoneOff className="h-4 w-4" /> End
                </Button>
              )}
            </>
          )}

          {!isOwner && isConnected && (
            <Button
              variant="destructive"
              size="sm"
              onClick={(e) => { e.stopPropagation(); handleClose(); }}
              className="gap-1.5 rounded-full px-5"
            >
              <PhoneOff className="h-4 w-4" /> Leave
            </Button>
          )}
        </div>

        {/* Participant List Panel — Host can enable/disable participant mics */}
        {isOwner && showParticipantList && (
          <div className="mx-4 mb-2 bg-black/60 backdrop-blur-md rounded-xl border border-white/10 p-3 max-h-48 overflow-y-auto">
            <h4 className="text-white/80 text-xs font-semibold mb-2 flex items-center gap-1.5">
              <Users className="h-3.5 w-3.5" /> Participants ({participants.filter(p => !p.isOwner).length})
            </h4>
            <div className="space-y-1.5">
              {participants.filter(p => !p.isOwner).map(p => (
                <div key={p.id} className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2 min-w-0">
                    <Avatar className="h-6 w-6 flex-shrink-0">
                      <AvatarImage src={p.photo} />
                      <AvatarFallback className="text-[9px] bg-primary/20 text-primary">
                        {p.name.charAt(0).toUpperCase()}
                      </AvatarFallback>
                    </Avatar>
                    <span className="text-white/90 text-xs truncate">{p.name}</span>
                  </div>
                  <Button
                    variant={p.micEnabled ? 'secondary' : 'ghost'}
                    size="sm"
                    className={cn(
                      "h-7 w-7 p-0 rounded-full flex-shrink-0",
                      p.micEnabled
                        ? "bg-emerald-500/20 hover:bg-emerald-500/30"
                        : "bg-white/10 hover:bg-white/20"
                    )}
                    onClick={() => enableParticipantMic(p.id, !p.micEnabled)}
                    title={p.micEnabled ? `Mute ${p.name}` : `Unmute ${p.name}`}
                  >
                    {p.micEnabled
                      ? <Mic className="h-3.5 w-3.5 text-emerald-400" />
                      : <MicOff className="h-3.5 w-3.5 text-white/50" />
                    }
                  </Button>
                </div>
              ))}
              {participants.filter(p => !p.isOwner).length === 0 && (
                <p className="text-white/40 text-xs text-center py-2">No participants yet</p>
              )}
            </div>
          </div>
        )}

        {/* Chat Input Bar — below media controls */}
        <div className="flex items-center gap-2 px-4 py-2">
          <div className="flex-1 flex items-center gap-2 bg-white/15 backdrop-blur-md rounded-full px-4 py-2 border border-white/10">
            <Input
              value={commentText}
              onChange={(e) => setCommentText(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && !e.shiftKey && handleSendComment()}
              placeholder="Say something..."
              className="border-0 bg-transparent text-white placeholder:text-white/50 focus-visible:ring-0 focus-visible:ring-offset-0 h-7 px-0 text-sm"
            />
            {commentText.trim() && (
              <Button
                size="icon"
                variant="ghost"
                className="h-7 w-7 text-accent hover:bg-white/10 shrink-0"
                onClick={handleSendComment}
              >
                <Send className="h-4 w-4" />
              </Button>
            )}
          </div>

          {/* Emoji reaction button — available to all participants */}
          <button
            onClick={() => setShowEmojiBar(prev => !prev)}
            className="h-10 w-10 rounded-full bg-white/15 backdrop-blur-md border border-white/10 flex items-center justify-center hover:bg-white/25 active:scale-90 transition-all shrink-0"
          >
            <Heart className="h-5 w-5 text-red-400 fill-red-400" />
          </button>

          {showEmojiBar && (
            <div className="absolute bottom-14 right-4 flex items-center gap-1.5 bg-black/60 backdrop-blur-md rounded-full px-2 py-1.5 border border-white/10 animate-in fade-in slide-in-from-bottom-2 duration-200">
              {QUICK_EMOJIS.map((emoji) => (
                <button
                  key={emoji}
                  onClick={() => { handleSendReaction(emoji); setShowEmojiBar(false); }}
                  className="text-xl hover:scale-125 active:scale-90 transition-transform w-8 h-8 flex items-center justify-center"
                >
                  {emoji}
                </button>
              ))}
            </div>
          )}

          {/* Gift button — men (non-owner) only */}
          {!isOwner && (isConnected || isLive) && (
            <button
              onClick={() => setShowGiftDialog(true)}
              className="h-10 w-10 rounded-full bg-gradient-to-br from-amber-500/80 to-orange-600/80 backdrop-blur-md border border-white/20 flex items-center justify-center hover:scale-105 active:scale-90 transition-all shadow-lg shadow-orange-500/30 shrink-0"
            >
              <Gift className="h-5 w-5 text-white" />
            </button>
          )}
        </div>
      </div>

      {/* ─── Gift Dialog ──────────────────────────────────────────── */}
      <Dialog open={showGiftDialog} onOpenChange={setShowGiftDialog}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Gift className="h-5 w-5 text-amber-500" /> Send a Gift to Host
            </DialogTitle>
            <DialogDescription>
              Choose a gift to send to the host.
            </DialogDescription>
          </DialogHeader>

          <div className="grid grid-cols-3 gap-3 py-4">
            {gifts.slice(0, 12).map((gift) => (
              <button
                key={gift.id}
                onClick={() => handleSendGift(gift)}
                className="flex flex-col items-center gap-1.5 p-3 rounded-xl border border-border/50 bg-card hover:bg-accent hover:border-primary/50 transition-all hover:scale-105 active:scale-95"
              >
                <span className="text-3xl">{gift.emoji}</span>
                <span className="text-xs font-medium text-foreground">{gift.name}</span>
                <span className="text-[10px] text-muted-foreground font-semibold">₹{gift.price}</span>
              </button>
            ))}
            {gifts.length === 0 && (
              <div className="col-span-3 text-center py-6 text-muted-foreground">
                <p>No gifts available</p>
              </div>
            )}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default PrivateGroupCallWindow;
