/**
 * ChatScreen.tsx
 * 
 * PURPOSE: Real-time messaging interface between two matched users.
 * 
 * KEY FEATURES:
 * - Real-time message updates via Supabase Realtime subscriptions
 * - Read receipts and message status indicators
 * - Date-grouped message display
 * - Online/offline status indicators
 * 
 * NOTE: Multilingual translation via Lingva (Google Translate scraper) for all 130+ languages.
 * 
 * DATABASE TABLES USED:
 * - chat_messages: Stores all chat messages
 * - profiles: User profile information
 * - user_status: Online/offline tracking
 */

// ============= IMPORTS SECTION =============
// React hooks for state, effects, and refs
import { useState, useEffect, useRef, useCallback, useMemo } from "react";
// React Router hooks for navigation and URL parameters
import { useNavigate, useParams } from "react-router-dom";
// UI Components
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import MeowLogo from "@/components/MeowLogo";
import { moderateMessage, moderateMessage1to1 } from '@/lib/content-moderation';
// Toast notifications hook
import { useToast } from "@/hooks/use-toast";
// Lucide icons for UI elements
import { 
  ArrowLeft,
  Send,
  Circle,
  Loader2,
  MoreVertical,
  Check,
  CheckCheck,
  Paperclip,
  Image,
  FileText,
  Camera,
  X,
  UserPlus,
  UserMinus,
  Ban,
  Shield,
  Heart,
  AlertTriangle,
  PhoneOff,
  LogOut,
  Home,
  Phone,
  Video,
  Trash2,
  Pin
} from "lucide-react";
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuSeparator,
  ContextMenuTrigger,
} from "@/components/ui/context-menu";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
// Supabase client for database and realtime operations
import { supabase } from "@/integrations/supabase/client";
// Activity status tracking hook
import { useActivityStatus } from "@/hooks/useActivityStatus";
import VoiceMessagePlayer from "@/components/VoiceMessagePlayer";
import { ChatMessageInput } from "@/components/chat/ChatMessageInput";
import { classifyError, ERROR_MESSAGES } from "@/lib/errors";
import { useMessageSound } from "@/hooks/useMessageSound";
import { MessageActions } from "@/components/chat/MessageActions";
import { ReplyPreview } from "@/components/chat/ReplyPreview";
import { ForwardDialog } from "@/components/chat/ForwardDialog";
import { PinnedMessages } from "@/components/chat/PinnedMessages";
import { MessageReactions } from "@/components/chat/MessageReactions";
import { VoiceRecorder } from "@/components/chat/VoiceRecorder";
import { useIncomingCallListener } from "@/hooks/useIncomingCallListener";
import { useAppCall } from "@/hooks/useAppCall";
import { CallScreen } from "@/components/CallScreen";
import { IncomingCallBanner } from "@/components/IncomingCallBanner";
import { useMiniChatBilling } from "@/hooks/useMiniChatBilling";
import { useChatPresence, type PartnerPresenceState } from "@/hooks/useChatPresence";
import { PartnerStatusLine } from "@/components/chat/PartnerStatusLine";
import { extractVoiceUrl, isTranslatableChatText, normalizeChatAttachmentUrl, storagePathFromAttachmentUrl } from "@/lib/chat-attachments";
import { translateForViewer, isEnglishLanguage, languagesMatch } from "@/lib/translation-service";
import { canCallEachOther, fetchCallLanguage, pickCallLanguage } from "@/lib/call-languages";
import { useAppSettings } from "@/hooks/useAppSettings";

// MAX_PARALLEL_CHATS is now loaded dynamically from app_settings
// Default fallback only used if database is unavailable
const DEFAULT_MAX_PARALLEL_CHATS = 3;

// ============= WHATSAPP COLOR TOKENS =============
const WA = {
  headerBg      : '#075E54',
  headerText    : '#FFFFFF',
  headerSub     : '#B2DFDB',
  chatBg        : '#E5DDD5',
  sentBubble    : '#DCF8C6',
  sentText      : '#111111',
  recvBubble    : '#FFFFFF',
  recvText      : '#111111',
  subtitleColor : '#888888',
  metaColor     : '#999999',
  tickRead      : '#4FC3F7',
  tickSent      : '#B0BEC5',
  inputBg       : '#F0F0F0',
  inputBarBg    : '#FFFFFF',
  dateSepBg     : 'rgba(255,255,255,0.75)',
  dateSepText   : '#555555',
  attachSheet   : '#FFFFFF',
  previewBarBg  : '#F0FBF8',
  previewBorder : '#075E54',
  onlineDot     : '#4CAF50',
  offlineDot    : '#9E9E9E',
};

/**
 * Message Interface
 * 
 * Defines the structure of a chat message object.
 */
interface Message {
  id: string;                    // UUID of the message
  senderId: string;              // UUID of sender
  message: string;               // Original message text
  translatedMessage?: string;    // Translated message for display
  englishText?: string;          // English translation shown below every bubble
  isTranslated?: boolean;        // Whether translation was applied
  isTranslating?: boolean;       // Whether translation is in progress
  isRead: boolean;               // Read receipt status
  createdAt: string;             // ISO timestamp of creation
  attachmentUrl?: string;        // URL of attached file/image
  attachmentType?: "image" | "file"; // Type of attachment
  sendFailed?: boolean;          // Whether send failed (for retry UI)
  replyToId?: string;            // Message this is replying to
  replyToText?: string;          // Text of replied message (for display)
  replyToSender?: string;        // Sender name of replied message
  isForwarded?: boolean;         // Whether message was forwarded
  isEdited?: boolean;            // Whether message was edited
  isPinned?: boolean;            // Whether message is pinned
  reactions?: { emoji: string; count: number; userReacted: boolean }[];
  isSystem?: boolean;            // Join/leave notice shown in the thread
}

/**
 * ChatPartner Interface
 * 
 * Information about the other user in the chat.
 */
interface ChatPartner {
  userId: string;            // UUID of chat partner
  fullName: string;          // Display name
  avatar: string;            // Profile photo URL
  isOnline: boolean;         // Current online status
  preferredLanguage: string; // Language for translation target
}

/**
 * ChatScreen Component
 * 
 * Main chat interface component that handles:
 * - Message display and sending
 * - Real-time updates
 * - Automatic translation
 */
/** Renders chat attachment with signed URL resolution for private bucket */
const ChatAttachment = ({ url, isMine, resolveUrl }: { url: string; isMine: boolean; resolveUrl: (u: string) => Promise<string> }) => {
  const [resolvedUrl, setResolvedUrl] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    resolveUrl(url).then((u) => {
      if (!cancelled) {
        if (u === '') {
          setFailed(true);
        } else {
          setResolvedUrl(u);
        }
      }
    });
    return () => { cancelled = true; };
  }, [url, resolveUrl]);

  // BUG-IMG-01 FIX: Show error state when signed URL fails
  if (failed) {
    return <div className={`rounded-2xl overflow-hidden px-4 py-3 ${isMine ? "bg-primary/80" : "bg-muted"}`}>
      <span className="text-sm text-destructive">Attachment unavailable</span>
    </div>;
  }

  if (!resolvedUrl) {
    return <div className={`rounded-2xl overflow-hidden px-4 py-3 ${isMine ? "bg-primary/80" : "bg-muted"}`}>
      <span className="text-sm text-muted-foreground">Loading attachment…</span>
    </div>;
  }

  // BUG-IMG-02 FIX: Detect image and video extensions
  const ext = url.split('.').pop()?.toLowerCase() || '';
  const isImage = /^(jpg|jpeg|png|gif|webp|heic|heif|bmp|avif)$/.test(ext);
  const isVideo = /^(mp4|webm|mov|avi|3gp|mkv)$/.test(ext);

  return (
    <div className={`rounded-2xl overflow-hidden ${isMine ? "rounded-br-md" : "rounded-bl-md"}`}>
      {isImage ? (
        <img
          src={resolvedUrl}
          alt="Attachment"
          className="max-w-[280px] max-h-[300px] object-cover cursor-pointer hover:opacity-90 transition-opacity"
          onClick={() => window.open(resolvedUrl, "_blank")}
        />
      ) : isVideo ? (
        <video
          src={resolvedUrl}
          controls
          playsInline
          className="max-w-[280px] max-h-[300px] rounded-xl"
        />
      ) : (
        <a
          href={resolvedUrl}
          target="_blank"
          rel="noopener noreferrer"
          className={`flex items-center gap-2 px-4 py-3 ${isMine ? "bg-primary/80" : "bg-muted"}`}
        >
          <FileText className="w-5 h-5" />
          <span className="text-sm underline">Download File</span>
        </a>
      )}
    </div>
  );
};

/** Resolves voice URL via signed URL before rendering player */
const ResolvedVoicePlayer = ({ voiceUrl, isMine, resolveUrl }: { voiceUrl: string; isMine: boolean; resolveUrl: (u: string) => Promise<string> }) => {
  const [resolved, setResolved] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    let cancelled = false;
    setFailed(false);
    setResolved(null);
    resolveUrl(voiceUrl).then((u) => {
      if (cancelled) return;
      if (!u) setFailed(true);
      else setResolved(u);
    }).catch(() => {
      if (!cancelled) setFailed(true);
    });
    return () => { cancelled = true; };
  }, [voiceUrl, resolveUrl]);
  if (failed) return <div className="text-xs text-muted-foreground px-2 py-1">Voice unavailable</div>;
  if (!resolved) return <div className="flex items-center gap-1.5 px-2 py-1"><Loader2 className="h-3.5 w-3.5 animate-spin text-muted-foreground" /><span className="text-xs text-muted-foreground">Loading voice...</span></div>;
  return <VoiceMessagePlayer audioUrl={resolved} isMine={isMine} />;
};

const ChatScreen = () => {
    const [recording, setRecording] = useState(false);
  const [recordSecs, setRecordSecs] = useState(0);
  const recRef = useRef<MediaRecorder | null>(null);
  const recChunks = useRef<Blob[]>([]);
  const recTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mr = new MediaRecorder(stream);
      recChunks.current = [];
      mr.ondataavailable = (e) => e.data.size && recChunks.current.push(e.data);
      mr.onstop = async () => {
        stream.getTracks().forEach(t => t.stop());
        const blob = new Blob(recChunks.current, { type: "audio/webm" });
        const file = new File([blob], `voice-${Date.now()}.webm`, { type: "audio/webm" });
        const voiceUrl = await uploadFile(file);
        if (voiceUrl) {
            await supabase
            .from("chat_messages")
            .insert({
                chat_id: chatId.current,
                sender_id: currentUserId,
                receiver_id: chatPartner!.userId,
                message: `🎤[VOICE:${voiceUrl}]`,
            });
        }
        setRecordSecs(0);
      };
      mr.start();
      recRef.current = mr;
      setRecording(true);
      recTimer.current = setInterval(() => setRecordSecs((s) => s + 1), 1000);
    } catch (e: any) {
      toast({ title: "Mic error", description: e?.message ?? "Cannot access microphone", variant: "destructive" });
    }
  };

  const stopRecording = () => {
    if (recTimer.current) { clearInterval(recTimer.current); recTimer.current = null; }
    recRef.current?.stop();
    recRef.current = null;
    setRecording(false);
  };
  
  // Toast notifications hook
  const { toast } = useToast();
  const { playMessageSound } = useMessageSound();
  const navigate = useNavigate();
  const { partnerId } = useParams<{ partnerId: string }>();
  
  // ============= STATE DECLARATIONS =============
  
  // Loading state during initial data fetch
  const [isLoading, setIsLoading] = useState(true);
  
  // Array of chat messages
  const [messages, setMessages] = useState<Message[]>([]);
  
  // Current message being typed
  const [newMessage, setNewMessage] = useState("");
  
  // True while message is being sent
  const [isSending, setIsSending] = useState(false);
  
  // True when partner is typing (future feature)
  const [isTyping, setIsTyping] = useState(false);
  
  // Chat partner profile information
  const [chatPartner, setChatPartner] = useState<ChatPartner | null>(null);
  
  // Current authenticated user's ID
  const [currentUserId, setCurrentUserId] = useState<string>("");
  
  // Current user's preferred language (used for matching display)
  const [currentUserLanguage, setCurrentUserLanguage] = useState<string>("");
  const [canPlaceCall, setCanPlaceCall] = useState(false);
  
  // Current user's gender for billing/earnings display
  const [currentUserGender, setCurrentUserGender] = useState<"male" | "female">("male");
  const [currentUserProfile, setCurrentUserProfile] = useState<{ fullName: string; avatar: string }>({
    fullName: "You",
    avatar: "",
  });
  
  // Attachment states
  const [isAttachmentOpen, setIsAttachmentOpen] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [isCameraOpen, setIsCameraOpen] = useState(false);
  
  // Friend and block states
  const [isFriend, setIsFriend] = useState(false);
  const [isBlocked, setIsBlocked] = useState(false);
  const [isBlockedByPartner, setIsBlockedByPartner] = useState(false);
  const [friendshipId, setFriendshipId] = useState<string | null>(null);
  const [blockId, setBlockId] = useState<string | null>(null);
  const [showBlockDialog, setShowBlockDialog] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  
  // Session and reconnection states
  const [sessionChatId, setSessionChatId] = useState<string | null>(null);
  const [isSessionActive, setIsSessionActive] = useState(true);
  const [showStopChatDialog, setShowStopChatDialog] = useState(false);
  const [isStoppingChat, setIsStoppingChat] = useState(false);
  const [walletBalance, setWalletBalance] = useState(0);
  
  // Billing state
  const [billingSessionId, setBillingSessionId] = useState<string | null>(null);
  const [billingManId, setBillingManId] = useState<string>("");
  const [billingWomanId, setBillingWomanId] = useState<string>("");
  const [billingSessionStartedAt, setBillingSessionStartedAt] = useState<string | null>(null);
  
  const sendingLockRef = useRef(false);
  const prevPartnerStateRef = useRef<PartnerPresenceState | null>(null);

  // Reply, Forward, Edit state
  const [replyTo, setReplyTo] = useState<{ id: string; text: string; senderName: string } | null>(null);
  const [forwardMsg, setForwardMsg] = useState<{ id: string; text: string } | null>(null);
  const [editingMsg, setEditingMsg] = useState<{ id: string; text: string } | null>(null);
  
  // ============= REFS =============
  
  // Reference to bottom of messages for auto-scroll
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const messagesScrollRef = useRef<HTMLDivElement>(null);
  
  // Store chat ID for realtime subscription (consistent format)
  const chatId = useRef<string>("");
  // Reactive state to trigger subscription re-run when chatId is set
  const [activeChatId, setActiveChatId] = useState<string>("");

  // ============= LIVE PRESENCE (per-chat) =============
  // Track whether THIS chat window is currently visible/focused for the local user
  const [isWindowActive, setIsWindowActive] = useState<boolean>(
    typeof document === "undefined" ? true : document.visibilityState === "visible"
  );
  useEffect(() => {
    const onVis = () => setIsWindowActive(document.visibilityState === "visible" && document.hasFocus());
    const onFocus = () => setIsWindowActive(true);
    const onBlur = () => setIsWindowActive(false);
    document.addEventListener("visibilitychange", onVis);
    window.addEventListener("focus", onFocus);
    window.addEventListener("blur", onBlur);
    return () => {
      document.removeEventListener("visibilitychange", onVis);
      window.removeEventListener("focus", onFocus);
      window.removeEventListener("blur", onBlur);
    };
  }, []);

  const { partnerState, partnerLastSeen, sendTyping } = useChatPresence({
    chatId: activeChatId,
    currentUserId,
    partnerId: chatPartner?.userId || "",
    isWindowActive,
  });

  // Mirror "typing" presence state into the existing typing-bubble indicator
  useEffect(() => {
    setIsTyping(partnerState === "typing");
  }, [partnerState]);

  const applyBackgroundTranslation = useCallback((messageId: string, text: string, senderLang?: string) => {
    if (!isTranslatableChatText(text)) return;
    void (async () => {
      let viewerLang = currentUserLanguageRef.current || "English";
      try {
        const uid = currentUserIdRef.current;
        if (uid) {
          const { data } = await supabase
            .from("profiles")
            .select("preferred_language, primary_language")
            .eq("user_id", uid)
            .maybeSingle();
          const live = data?.preferred_language || data?.primary_language;
          if (live) {
            viewerLang = live;
            currentUserLanguageRef.current = live;
          }
        }
      } catch {
        /* keep cached language */
      }
      if (languagesMatch(viewerLang, senderLang)) return;
      const result = await translateForViewer(text, viewerLang, senderLang);
      setMessages((prev) =>
        prev.map((m) => {
          const realId = tempToRealIdRef.current.get(messageId);
          if (m.id !== messageId && m.id !== realId) return m;
          return {
            ...m,
            translatedMessage: result.nativeText,
            englishText: isEnglishLanguage(viewerLang) ? undefined : result.englishText,
            isTranslated: result.nativeText !== text,
            isTranslating: false,
          };
        })
      );
    })().catch(() => {
      setMessages((prev) =>
        prev.map((m) => (m.id === messageId ? { ...m, isTranslating: false } : m))
      );
    });
  }, []);

  useEffect(() => {
    if (!chatPartner?.fullName) return;
    const prev = prevPartnerStateRef.current;
    if (prev === partnerState) return;
    prevPartnerStateRef.current = partnerState;

    const pushSystem = (text: string) => {
      setMessages((msgs) => [
        ...msgs,
        {
          id: `sys-${Date.now()}`,
          senderId: "system",
          message: text,
          isRead: true,
          isSystem: true,
          createdAt: new Date().toISOString(),
        },
      ]);
    };

    if (partnerState === "in_chat" && prev === "left_chat") {
      pushSystem(`${chatPartner.fullName} joined the chat`);
    }
    if (partnerState === "left_chat" && (prev === "in_chat" || prev === "typing")) {
      pushSystem(`${chatPartner.fullName} left the chat`);
    }
  }, [partnerState, chatPartner?.fullName]);
  
  // CHT-01 FIX: Ref to avoid stale closures in realtime subscription
  const chatPartnerRef = useRef<ChatPartner | null>(null);
  const currentUserLanguageRef = useRef<string>("");
  const currentUserIdRef = useRef<string>("");
  
  // Refs for file inputs and camera
  const imageInputRef = useRef<HTMLInputElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  
  // Map temp message IDs to real DB IDs for translation resolution
  const tempToRealIdRef = useRef<Map<string, string>>(new Map());
  const walletChannelRef = useRef<any>(null);

  // ============= CHAT BILLING =============
  const handleInsufficientBalance = useCallback(() => {
    toast({
      title: "Insufficient Balance",
      description: "Your wallet balance is low. Please recharge to continue chatting.",
      variant: "destructive",
    });
  }, [toast]);

  // ============= INCOMING CALLS + 1:1 CALL BILLING =============
  const { settings } = useAppSettings();
  const { incomingCall, clearIncomingCall } = useIncomingCallListener(currentUserId || null, currentUserGender as 'male' | 'female', currentUserLanguage);
  const { status: callStatus, activeCall, isMuted, isCameraOff, initiateCall, acceptCall, declineCall, endCall, toggleMute, toggleCamera } = useAppCall(currentUserId || null, currentUserGender as 'male' | 'female', walletBalance);

  useEffect(() => {
    if (currentUserGender !== "male" || !currentUserId || !chatPartner?.userId) {
      setCanPlaceCall(false);
      return;
    }
    let cancelled = false;
    Promise.all([
      fetchCallLanguage(currentUserId),
      fetchCallLanguage(chatPartner.userId),
    ]).then(([selfLang, partnerLang]) => {
      if (!cancelled) setCanPlaceCall(canCallEachOther(selfLang, partnerLang));
    }).catch(() => {
      if (!cancelled) setCanPlaceCall(false);
    });
    return () => { cancelled = true; };
  }, [currentUserGender, currentUserId, chatPartner?.userId]);

  const refreshManWallet = useCallback(() => {
    if (!currentUserId || currentUserGender !== "male") return;
    void supabase.rpc("get_men_wallet_balance", { p_user_id: currentUserId }).then(({ data }) => {
      if (!data) return;
      const wd = data as Record<string, number>;
      setWalletBalance(Number(wd.balance) || 0);
    });
  }, [currentUserId, currentUserGender]);

  // Only the man's client may call bill_session_minute (auth gate).
  // Billing starts after both people have sent a real (non-system) message in this thread.
  const isBillingDriver = !!currentUserId && !!billingManId && currentUserId === billingManId;
  const bothReplied = useMemo(() => {
    if (!billingManId || !billingWomanId || !billingSessionStartedAt) return false;
    const since = new Date(billingSessionStartedAt).getTime();
    if (!Number.isFinite(since)) return false;
    const manSent = messages.some((m) => !m.isSystem && m.senderId === billingManId && new Date(m.createdAt).getTime() >= since);
    const womanSent = messages.some((m) => !m.isSystem && m.senderId === billingWomanId && new Date(m.createdAt).getTime() >= since);
    return manSent && womanSent;
  }, [messages, billingManId, billingWomanId, billingSessionStartedAt]);
  const { minutesBilled, totalCharged, elapsedSeconds, isBilling, skipReason, stopBillingTimers } = useMiniChatBilling({
    chatId: activeChatId,
    isActive: isSessionActive && !!billingSessionId && isBillingDriver && bothReplied,
    paused: callStatus === "active" || callStatus === "connecting",
    sessionId: billingSessionId,
    manId: billingManId,
    womanId: billingWomanId,
    userId: currentUserId,
    activitySignal: messages.length ? `${messages.length}:${messages[messages.length - 1]?.createdAt}` : messages.length,
    onInsufficientBalance: handleInsufficientBalance,
    onCharged: refreshManWallet,
    onSettled: (result, elapsed) => {
      if (currentUserGender !== "male") return;
      if (elapsed < 1) return;
      const charged = Number(result?.charged);
      const landed = !!result?.success && charged > 0 && !result.duplicate_skipped && !result.skipped && !result.super_user_skip;
      if (landed) {
        toast({
          title: "Chat billed",
          description: `₹${charged} charged for ${elapsed}s`,
        });
        refreshManWallet();
        return;
      }
      const why = result?.duplicate_skipped
        ? "Server treated this minute as already billed (no new debit)."
        : result?.skipped
          ? `Skipped: ${result.skipped}`
          : result?.super_user_skip
            ? "Server skipped this account (super_user_skip)."
            : result?.error
              || (result?.success ? `RPC success but charged ₹${Number.isFinite(charged) ? charged : 0}` : "Charge did not land.");
      toast({
        title: "Chat not billed",
        description: why,
        variant: "destructive",
      });
    },
  });

  useEffect(() => {
    if (!isBillingDriver) return;
    if (!billingSessionId) {
      console.warn("[billing] waiting for session id");
      return;
    }
    if (!bothReplied) {
      console.warn("[billing] waiting until both people have sent a message");
      return;
    }
    console.info("[billing] timers can start", { billingSessionId, billingManId, billingWomanId });
  }, [isBillingDriver, billingSessionId, bothReplied, billingManId, billingWomanId]);

  useEffect(() => {
    refreshManWallet();
  }, [minutesBilled, refreshManWallet]);

  useEffect(() => {
    if (callStatus === "idle") refreshManWallet();
  }, [callStatus, refreshManWallet]);

  // Cleanup camera stream and wallet channel on unmount
  useEffect(() => {
    return () => {
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(track => track.stop());
        streamRef.current = null;
      }
      if (walletChannelRef.current) {
        supabase.removeChannel(walletChannelRef.current);
        walletChannelRef.current = null;
      }
    };
  }, []);
  
  // CHT-01 FIX: Keep refs in sync with state
  useEffect(() => { chatPartnerRef.current = chatPartner; }, [chatPartner]);
  useEffect(() => { currentUserLanguageRef.current = currentUserLanguage; }, [currentUserLanguage]);
  useEffect(() => { currentUserIdRef.current = currentUserId; }, [currentUserId]);
  
  // ============= ACTIVITY STATUS TRACKING =============
  
  // Track user activity and update online status
  const { setOnlineStatus } = useActivityStatus(currentUserId || null);

  /**
   * useEffect: Initialize Chat
   * 
   * Runs when component mounts or partner ID changes.
   * Loads chat partner info and message history.
   */
  useEffect(() => {
    if (partnerId) {
      // Reset guard so a new partner triggers fresh initialization
      initializingRef.current = false;
      initializeChat(partnerId);
    }
  }, [partnerId]); // Re-run if partner ID changes

  /**
   * Jump to the latest message after history paints, and again when a new
   * message arrives. Last-id (not the whole messages array) so translation
   * updates do not yank the viewport. isLoading is required: messages are set
   * while the spinner is still up, so the list is not in the DOM yet.
   */
  useEffect(() => {
    if (isLoading) return;
    const jumpToLatest = () => {
      const scroller = messagesScrollRef.current;
      if (scroller) {
        scroller.scrollTop = scroller.scrollHeight;
        return;
      }
      messagesEndRef.current?.scrollIntoView({ behavior: "auto", block: "end" });
    };
    jumpToLatest();
    const frame = window.requestAnimationFrame(jumpToLatest);
    return () => window.cancelAnimationFrame(frame);
  }, [isLoading, messages[messages.length - 1]?.id]);

  /**
   * useEffect: Real-time Message Subscription
   * 
   * Sets up Supabase Realtime subscription to listen for new messages.
   * Automatically translates incoming messages from partner.
   * 
   * IMPORTANT: Cleans up subscription on component unmount.
   */
  useEffect(() => {
    // Don't subscribe until chat ID is set
    if (!chatId.current) return;

    // Create realtime channel for this chat
    const channel = supabase
      .channel(`chat-${chatId.current}`)
      .on(
        'postgres_changes',  // Listen to database changes
        {
          event: 'INSERT',   // Only new messages
          schema: 'public',
          table: 'chat_messages',
          filter: `chat_id=eq.${chatId.current}` // Only this chat
        },
        async (payload: any) => {
          // Extract new message from payload
          const newMsg = payload.new;
          
          // CHT-01 FIX: Use refs to avoid stale closures
          const userId = currentUserIdRef.current;
          const partner = chatPartnerRef.current;
          
          // Show the original immediately. Translation runs in the background
          // and never blocks the thread or the input.
          setMessages(prev => {
            // Skip if already in state (exact ID match)
            if (prev.some(m => m.id === newMsg.id)) return prev;
            
            // For own messages, preserve optimistic translation data
            if (newMsg.sender_id === userId) {
              const tempIdx = prev.findIndex(m =>
                m.id.startsWith('temp-') && m.senderId === newMsg.sender_id &&
                Math.abs(new Date(m.createdAt).getTime() - new Date(newMsg.created_at).getTime()) < 10000
              );
              if (tempIdx !== -1) {
                const tempMsg = prev[tempIdx];
                tempToRealIdRef.current.set(tempMsg.id, newMsg.id);
                const updated = [...prev];
                updated[tempIdx] = {
                  id: newMsg.id,
                  senderId: newMsg.sender_id,
                  message: newMsg.message,
                  translatedMessage: tempMsg.translatedMessage,
                  englishText: tempMsg.englishText,
                  isTranslated: tempMsg.isTranslated,
                  isTranslating: tempMsg.isTranslating,
                  isRead: newMsg.is_read,
                  createdAt: newMsg.created_at,
                };
                return updated;
              }
            }
            
            // Remove any remaining temp message from same sender within 10s window
            const filtered = prev.filter(m =>
              !(m.id.startsWith('temp-') && m.senderId === newMsg.sender_id &&
                Math.abs(new Date(m.createdAt).getTime() - new Date(newMsg.created_at).getTime()) < 10000)
            );
            return [...filtered, {
              id: newMsg.id,
              senderId: newMsg.sender_id,
              message: newMsg.message,
              isRead: newMsg.is_read,
              createdAt: newMsg.created_at,
            }];
          });

          if (newMsg.sender_id !== userId && isTranslatableChatText(newMsg.message)) {
            applyBackgroundTranslation(newMsg.id, newMsg.message, partner?.preferredLanguage);
          }

          // Mark received messages as read automatically & play sound
          if (newMsg.sender_id !== userId) {
            markAsRead(newMsg.id);
            playMessageSound();
          }
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'chat_messages',
          filter: `chat_id=eq.${chatId.current}`
        },
        (payload: any) => {
          const updated = payload.new;
          const userId = currentUserIdRef.current;
          // Handle delete for everyone
          if (updated.deleted_for_everyone) {
            setMessages(prev => prev.filter(m => m.id !== updated.id));
            return;
          }
          // Handle delete for me
          if (updated.sender_id === userId && updated.deleted_for_sender) {
            setMessages(prev => prev.filter(m => m.id !== updated.id));
            return;
          }
          if (updated.receiver_id === userId && updated.deleted_for_receiver) {
            setMessages(prev => prev.filter(m => m.id !== updated.id));
            return;
          }
          // Read receipts: partner marked our message as read
          if (typeof updated.is_read === "boolean") {
            setMessages(prev => prev.map(m =>
              m.id === updated.id ? { ...m, isRead: updated.is_read } : m
            ));
          }
        }
      )
      .subscribe();

    // Cleanup function: remove channel on unmount
    return () => {
      supabase.removeChannel(channel);
    };
  }, [activeChatId, applyBackgroundTranslation]); // CHT-01 FIX: Only depend on activeChatId, use refs for everything else

  // Issue 2.2: Re-translate history when language loads late — still one paint
  useEffect(() => {
    const langToUse = currentUserLanguage || 'English';
    if (!langToUse || messages.length === 0) return;
    const untranslated = messages.filter(m =>
      !m.isTranslated && !m.translatedMessage && m.senderId !== currentUserId && !m.isSystem
    );
    if (untranslated.length === 0) return;
    let cancelled = false;
    void translateHistoryMessages(messages, langToUse).then((ready) => {
      if (!cancelled) setMessages(ready);
    });
    return () => { cancelled = true; };
  }, [currentUserLanguage]);

  /**
   * useEffect: Monitor Partner Online Status and Session
   * 
   * Detects when partner goes offline or closes chat.
   * Triggers auto-reconnect for men when partner disconnects.
   */
  useEffect(() => {
    if (!chatPartner?.userId || !currentUserId) return;
    if (!chatId.current) return; // BUG-CHT-RT-01 FIX: guard against empty chatId
    // 15-second debounce timer for partner offline detection
    // Prevents brief network flickers from ending active chats
    let offlineDebounceTimer: NodeJS.Timeout | null = null;

    // Monitor partner's online status
    const statusChannel = supabase
      .channel(`partner-status-${chatPartner.userId}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'user_status',
          filter: `user_id=eq.${chatPartner.userId}`
        },
        async (payload: any) => {
          const newStatus = payload.new;
          
          // Partner went offline - debounce for 15 seconds before acting
          if (!newStatus.is_online && isSessionActive) {
            setChatPartner(prev => prev ? { ...prev, isOnline: false } : null);
            
            // Clear any existing timer
            if (offlineDebounceTimer) clearTimeout(offlineDebounceTimer);
            
            offlineDebounceTimer = setTimeout(async () => {
              // Re-check partner status before disconnecting
              const { data: currentStatus } = await supabase
                .from("user_status")
                .select("is_online")
                .eq("user_id", chatPartner.userId)
                .maybeSingle();

              // Only disconnect if partner is still truly offline after 15s
              if (currentStatus && currentStatus.is_online === false) {
                setChatPartner(prev => prev ? { ...prev, isOnline: false } : null);
              } else {
                // Partner came back online within the debounce window
                setChatPartner(prev => prev ? { ...prev, isOnline: true } : null);
              }
            }, 15000); // 15-second debounce
          } else if (newStatus.is_online) {
            // Partner came back online - cancel any pending offline timer
            if (offlineDebounceTimer) {
              clearTimeout(offlineDebounceTimer);
              offlineDebounceTimer = null;
            }
            setChatPartner(prev => prev ? { ...prev, isOnline: true } : null);
          }
        }
      )
      .subscribe();

    // BUG-CHT-RT-01 FIX: Guard against empty chatId to prevent subscribing to ALL sessions
    if (!chatId.current) {
      console.warn('[ChatScreen] session-monitor skipped: chatId.current is empty');
      return;
    }

    // Monitor active_chat_sessions for this conversation
    const sessionChannel = supabase
      .channel(`session-monitor-${chatId.current}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'active_chat_sessions',
          filter: `chat_id=eq.${chatId.current}`
        },
        (payload: any) => {
          const session = payload.new;
          if (session && (session.status === 'active' || session.status === 'pending')) {
            setBillingSessionId(session.id);
            setBillingManId(session.man_user_id);
            setBillingWomanId(session.woman_user_id);
            setBillingSessionStartedAt(session.started_at || session.created_at || new Date().toISOString());
            setIsSessionActive(true);
            console.log("[Chat] Billing session detected via INSERT:", session.id);
          }
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'active_chat_sessions',
          filter: `chat_id=eq.${chatId.current}`
        },
        (payload: any) => {
          const session = payload.new;
          if (!session) return;

          // BUG-BILL-05 FIX: Wire billing IDs on UPDATE → active/pending too
          // (recycled sessions transition pending→active without an INSERT event).
          if ((session.status === 'active' || session.status === 'pending') &&
              (session.man_user_id === currentUserId || session.woman_user_id === currentUserId)) {
            setBillingSessionId(session.id);
            setBillingManId(session.man_user_id);
            setBillingWomanId(session.woman_user_id);
            setBillingSessionStartedAt(session.started_at || session.created_at || new Date().toISOString());
            setIsSessionActive(true);
            console.log("[Chat] Billing session detected via UPDATE:", session.id, session.status);
          }

          // Session ended — keep the thread open (WhatsApp-style). Billing stops; no reconnect.
          if (session.status === 'ended' &&
              (session.man_user_id === currentUserId || session.woman_user_id === currentUserId)) {
            setIsSessionActive(false);
            setBillingSessionId(null);
            setBillingSessionStartedAt(null);
          }
        }
      )
      .subscribe();

    return () => {
      if (offlineDebounceTimer) clearTimeout(offlineDebounceTimer);
      supabase.removeChannel(statusChannel);
      supabase.removeChannel(sessionChannel);
    };
  }, [chatPartner?.userId, currentUserId, currentUserGender, isSessionActive]);

  /**
   * Translate history once, then return the full list so the thread can render in one paint.
   */
  const translateHistoryMessages = useCallback(async (msgs: Message[], viewerLanguage: string): Promise<Message[]> => {
    const translated = await Promise.all(msgs.map(async (msg) => {
      try {
        if (!isTranslatableChatText(msg.message) || msg.isSystem) return msg;
        if (msg.senderId === currentUserIdRef.current) return msg;
        const msgSenderLang = chatPartnerRef.current?.preferredLanguage;
        if (languagesMatch(viewerLanguage, msgSenderLang)) return msg;
        const result = await translateForViewer(msg.message, viewerLanguage, msgSenderLang);
        return {
          ...msg,
          translatedMessage: result.nativeText,
          englishText: isEnglishLanguage(viewerLanguage) ? undefined : result.englishText,
          isTranslated: result.nativeText !== msg.message,
        };
      } catch {
        return msg;
      }
    }));
    return translated;
  }, []);

  /**
   * initializeChat Function
   * 
   * Sets up the chat session:
   * 1. Gets current user info
   * 2. Generates consistent chat ID
   * 3. Fetches partner profile
   * 4. Loads message history
   * 5. Marks unread messages as read
   * 
   * @param partnerId - UUID of chat partner from URL
   */
  const initializingRef = useRef(false);
  const initializeChat = async (partnerId: string) => {
    if (initializingRef.current) return;
    initializingRef.current = true;
    try {
      setIsLoading(true);

      // ============= GET CURRENT USER =============
      
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) {
        // Not logged in - redirect to auth
        navigate("/");
        return;
      }
      const user = session.user;
      setCurrentUserId(user.id);

      const { data: myProfile } = await supabase
        .from("profiles")
        .select("full_name, photo_url")
        .eq("user_id", user.id)
        .maybeSingle();
      setCurrentUserProfile({
        fullName: myProfile?.full_name || "You",
        avatar: myProfile?.photo_url || "",
      });

      // ============= GENERATE CHAT ID =============
      
      // Create consistent chat ID by sorting user IDs alphabetically
      // This ensures same chat ID regardless of who initiates
      const ids = [user.id, partnerId].sort();
      chatId.current = `${ids[0]}_${ids[1]}`;
      setActiveChatId(chatId.current);

      // ============= GET USER'S LANGUAGE PREFERENCE AND GENDER =============
      
      const { data: currentProfile } = await supabase
        .from("profiles")
        .select("preferred_language, primary_language, gender")
        .eq("user_id", user.id)
        .maybeSingle();
      
      // Also check user_languages for mother tongue
      const { data: userLanguages } = await supabase
        .from("user_languages")
        .select("language_name")
        .eq("user_id", user.id)
        .limit(1);
      
      const motherTongue = pickCallLanguage(
        currentProfile?.primary_language,
        userLanguages?.[0]?.language_name,
        currentProfile?.preferred_language,
      ) || "English";
      
      setCurrentUserLanguage(motherTongue);
      const userGender = currentProfile?.gender === "female" || currentProfile?.gender === "Female" ? "female" : "male";
      setCurrentUserGender(userGender);

      // Fetch wallet balance for call buttons
      if (userGender === "male") {
        try {
          const { data: walletRpc } = await supabase.rpc('get_men_wallet_balance', {
            p_user_id: user.id
          });
          if (walletRpc) {
            const wd = walletRpc as Record<string, number>;
            setWalletBalance(Number(wd.balance) || 0);
          }
        } catch {
          console.warn('[Chat] Wallet balance fetch failed');
        }

        // Subscribe to wallet balance changes in realtime
        const walletChannel = supabase
          .channel(`wallet-balance-${user.id}`)
          .on('postgres_changes', {
            event: 'UPDATE',
            schema: 'public',
            table: 'wallets',
            filter: `user_id=eq.${user.id}`,
          }, (payload: any) => {
            if (payload.new?.balance !== undefined) {
              setWalletBalance(Number(payload.new.balance) || 0);
            }
          })
          .subscribe();

        // Store channel ref for cleanup (do NOT return here — it would abort initializeChat)
        walletChannelRef.current = walletChannel;
      }

      // ============= FETCH ACTIVE SESSION FOR BILLING =============
      // BUG-BILL-05 FIX: Race-resilient — retry up to 5x (250ms apart) because
      // start_chat may still be writing the row when initializeChat runs.
      try {
        let activeSession: { id: string; man_user_id: string; woman_user_id: string; status: string; started_at?: string; created_at?: string } | null = null;
        for (let attempt = 0; attempt < 5 && !activeSession; attempt++) {
          const { data } = await supabase
            .from("active_chat_sessions")
            .select("id, man_user_id, woman_user_id, status, started_at, created_at")
            .eq("chat_id", chatId.current)
            .in("status", ["active", "pending", "billing_paused"])
            .order("created_at", { ascending: false })
            .limit(1)
            .maybeSingle();
          if (data) { activeSession = data; break; }
          await new Promise(r => setTimeout(r, 250));
        }

        if (!activeSession) {
          const manUserId = userGender === "male" ? user.id : partnerId;
          const womanUserId = userGender === "female" ? user.id : partnerId;
          const { data: started, error: startError } = await supabase.functions.invoke("chat-manager", {
            body: {
              action: "start_chat",
              man_user_id: manUserId,
              woman_user_id: womanUserId,
            },
          });
          if (startError || !(started as any)?.success) {
            console.warn("[Chat] Failed to create billing session:", startError || (started as any)?.message);
          } else if ((started as any)?.session) {
            activeSession = (started as any).session;
          }
        }

        if (activeSession) {
          setBillingSessionId(activeSession.id);
          setBillingManId(activeSession.man_user_id);
          setBillingWomanId(activeSession.woman_user_id);
          setBillingSessionStartedAt(activeSession.started_at || activeSession.created_at || new Date().toISOString());
          setIsSessionActive(true);
          console.log("[Chat] Billing wired for session:", activeSession.id);
        } else {
          console.log("[Chat] No active session after retries — realtime UPDATE will wire billing");
        }
      } catch (e) {
        console.warn("[Chat] Failed to fetch billing session:", e);
      }

      // ============= FETCH PARTNER PROFILE =============
      
      // Use secure RPC for partner profile (excludes sensitive fields)
      const { fetchPublicProfile } = await import("@/lib/profile-queries");
      let partnerProfile = await fetchPublicProfile(partnerId);

      // Note: Only real authenticated users from database - no sample/mock data fallbacks
      
      // Fetch partner's online status
      const { data: partnerStatus } = await supabase
        .from("user_status")
        .select("is_online")
        .eq("user_id", partnerId)
        .maybeSingle();

      // Fetch partner's mother tongue
      const { data: partnerLanguages } = await supabase
        .from("user_languages")
        .select("language_name")
        .eq("user_id", partnerId)
        .limit(1);

      // Determine partner info from profile
      if (partnerProfile) {
        const partnerMotherTongue = pickCallLanguage(
          partnerProfile.primary_language,
          partnerLanguages?.[0]?.language_name,
          partnerProfile.preferred_language,
        ) || "English";
        const partnerName = partnerProfile.full_name || "Anonymous";
        const partnerAvatar = partnerProfile.photo_url || "";
        const isPartnerOnline = partnerStatus?.is_online || false;

        setChatPartner({
          userId: partnerProfile.user_id,
          fullName: partnerName,
          avatar: partnerAvatar,
          isOnline: isPartnerOnline,
          preferredLanguage: partnerMotherTongue,
        });
      } else {
        // No partner found - show error
        toast({
          title: "Error",
          description: "Chat partner not found",
          variant: "destructive",
        });
        navigate(currentUserGender === "female" ? "/women-dashboard" : "/dashboard");
        return;
      }

      // ============= FETCH MESSAGE HISTORY =============
      
      // CHT-02 FIX: Limit to last 100 messages to avoid hitting Supabase 1000-row cap
      const { data: existingMessages } = await supabase
        .from("chat_messages")
        .select("*")
        .eq("chat_id", chatId.current)
        .order("created_at", { ascending: false })
        .limit(100);
      
      // Reverse to get chronological order
      existingMessages?.reverse();

      // Transform database records to Message interface
      if (existingMessages) {
        // Filter out messages deleted for the current user
        const filteredMessages = existingMessages.filter(msg => {
          if ((msg as any).deleted_for_everyone) return false;
          if (msg.sender_id === user.id && (msg as any).deleted_for_sender) return false;
          if (msg.receiver_id === user.id && (msg as any).deleted_for_receiver) return false;
          return true;
        });
        const loadedMessages: Message[] = filteredMessages.map(msg => ({
          id: msg.id,
          senderId: msg.sender_id,
          message: msg.message,
          isRead: msg.is_read || false,
          createdAt: msg.created_at,
        }));

        // Translate the whole history first, then paint once so the thread does not jump.
        let readyMessages = loadedMessages;
        if (motherTongue) {
          const translationTimeout = new Promise<Message[]>((resolve) => {
            window.setTimeout(() => resolve(loadedMessages), 8000);
          });
          readyMessages = await Promise.race([
            translateHistoryMessages(loadedMessages, motherTongue),
            translationTimeout,
          ]);
        }
        setMessages(readyMessages);

        // ============= MARK UNREAD MESSAGES AS READ =============
        
        // Find messages sent to current user that are unread
        const unreadIds = existingMessages
          .filter(m => m.receiver_id === user.id && !m.is_read)
          .map(m => m.id);
        
        // Batch update if there are unread messages
        if (unreadIds.length > 0) {
          const { error: readError } = await supabase
            .from("chat_messages")
            .update({ is_read: true })
            .in("id", unreadIds);
          if (readError) {
            console.warn("[Chat] Failed to mark messages read:", readError.message);
          }
        }
      }

      // ============= CHECK FRIEND/BLOCK STATUS =============
      await checkFriendshipStatus(user.id, partnerId);
      await checkBlockStatus(user.id, partnerId);

    } catch (error) {
      console.error("Error initializing chat:", error);
      toast({ title: "Chat unavailable", description: ERROR_MESSAGES.chat.initFailed, variant: "destructive" });
    } finally {
      setIsLoading(false);
      initializingRef.current = false;
    }
  };

  /**
   * Check if users are friends
   */
  const checkFriendshipStatus = async (userId: string, partnerId: string) => {
    const { data } = await supabase
      .from("user_friends")
      .select("id, status")
      .or(`and(user_id.eq.${userId},friend_id.eq.${partnerId}),and(user_id.eq.${partnerId},friend_id.eq.${userId})`)
      .eq("status", "accepted")
      .maybeSingle();
    
    if (data) {
      setIsFriend(true);
      setFriendshipId(data.id);
    } else {
      setIsFriend(false);
      setFriendshipId(null);
    }
  };

  /**
   * Check if user is blocked or blocking
   */
  const checkBlockStatus = async (userId: string, partnerId: string) => {
    // Check if current user blocked the partner
    const { data: blockedByMe } = await supabase
      .from("user_blocks")
      .select("id")
      .eq("blocked_by", userId)
      .eq("blocked_user_id", partnerId)
      .maybeSingle();
    
    if (blockedByMe) {
      setIsBlocked(true);
      setBlockId(blockedByMe.id);
    } else {
      setIsBlocked(false);
      setBlockId(null);
    }

    // Check if partner blocked current user
    const { data: blockedByPartner } = await supabase
      .from("user_blocks")
      .select("id")
      .eq("blocked_by", partnerId)
      .eq("blocked_user_id", userId)
      .maybeSingle();
    
    setIsBlockedByPartner(!!blockedByPartner);
  };

  /**
   * Add friend
   */
  const handleAddFriend = async () => {
    if (!chatPartner || actionLoading) return;
    setActionLoading(true);

    try {
      const { data, error } = await supabase.rpc('send_friend_request', {
        p_target_user_id: chatPartner.userId,
      });

      if (error) throw error;

      toast({
        title: "Friend Request Sent",
        description: `A friend request has been sent to ${chatPartner.fullName}.`,
      });
    } catch (error: any) {
      console.error("Error sending friend request:", error);
      const msg = error?.message?.includes('already')
        ? "A friend request already exists."
        : "Failed to send friend request";
      toast({
        title: "Error",
        description: msg,
        variant: "destructive",
      });
    } finally {
      setActionLoading(false);
    }
  };

  /**
   * Remove friend
   */
  const handleRemoveFriend = async () => {
    if (!chatPartner || actionLoading) return;
    setActionLoading(true);

    try {
      const { error } = await supabase
        .from("user_friends")
        .delete()
        .or(`and(user_id.eq.${currentUserId},friend_id.eq.${chatPartner.userId}),and(user_id.eq.${chatPartner.userId},friend_id.eq.${currentUserId})`);

      if (error) throw error;

      setIsFriend(false);
      setFriendshipId(null);
      toast({
        title: "Friend Removed",
        description: `${chatPartner.fullName} has been removed from your friends.`,
      });
    } catch (error: any) {
      console.error("Error removing friend:", error);
      toast({
        title: "Error",
        description: "Failed to remove friend",
        variant: "destructive",
      });
    } finally {
      setActionLoading(false);
    }
  };

  /**
   * Block user
   */
  const handleBlockUser = async () => {
    if (!chatPartner || actionLoading) return;
    setActionLoading(true);
    setShowBlockDialog(false);

    try {
      const { data, error } = await supabase
        .from("user_blocks")
        .insert({
          blocked_by: currentUserId,
          blocked_user_id: chatPartner.userId,
          block_type: "permanent",
          reason: "Blocked by user"
        })
        .select()
        .single();

      if (error) throw error;

      setIsBlocked(true);
      setBlockId(data.id);
      
      // Also remove friendship if exists
      if (isFriend) {
        await supabase
          .from("user_friends")
          .delete()
          .or(`and(user_id.eq.${currentUserId},friend_id.eq.${chatPartner.userId}),and(user_id.eq.${chatPartner.userId},friend_id.eq.${currentUserId})`);
        setIsFriend(false);
        setFriendshipId(null);
      }

      toast({
        title: "User Blocked",
        description: `${chatPartner.fullName} has been blocked. You won't receive messages from them.`,
      });
    } catch (error: any) {
      console.error("Error blocking user:", error);
      toast({ title: "Could not block user", description: "Unable to block this user right now. Please try again.", variant: "destructive" });
    } finally {
      setActionLoading(false);
    }
  };

  /**
   * Unblock user
   */
  const handleUnblockUser = async () => {
    if (!chatPartner || actionLoading || !blockId) return;
    setActionLoading(true);

    try {
      const { error } = await supabase
        .from("user_blocks")
        .delete()
        .eq("id", blockId);

      if (error) throw error;

      setIsBlocked(false);
      setBlockId(null);
      toast({
        title: "User Unblocked",
        description: `${chatPartner.fullName} has been unblocked.`,
      });
    } catch (error: any) {
      console.error("Error unblocking user:", error);
      toast({ title: "Could not unblock user", description: "Unable to unblock this user right now. Please try again.", variant: "destructive" });
    } finally {
      setActionLoading(false);
    }
  };

  /**
   * Stop/End Chat
   * 
   * Allows user (especially men) to manually stop the chat.
   * This ends the billing session and closes the chat.
   */
  const handleStopChat = async () => {
    if (!chatPartner || isStoppingChat) return;
    setIsStoppingChat(true);
    setShowStopChatDialog(false);

    try {
      await stopBillingTimers();

      // End the chat session via chat-manager
      const { error } = await supabase.functions.invoke("chat-manager", {
        body: {
          action: "end_chat",
          chat_id: chatId.current,
          end_reason: currentUserGender === "male" ? "man_closed" : "woman_closed"
        }
      });

      if (error) throw error;

      setIsSessionActive(false);
      setBillingSessionId(null);
      setBillingSessionStartedAt(null);
      
      toast({
        title: "Chat Ended",
        description: "You have ended this chat session."
      });

      // Navigate back to dashboard
      navigate(currentUserGender === "female" ? "/women-dashboard" : "/dashboard");
      
    } catch (error: any) {
      console.error("Error stopping chat:", error);
      toast({
        title: "Error",
        description: "Failed to end chat session",
        variant: "destructive"
      });
    } finally {
      setIsStoppingChat(false);
    }
  };

  /**
   * Handle going offline manually
   */
  const handleGoOffline = async () => {
    // End the active chat session before going offline
    if (chatId.current && isSessionActive) {
      try {
        await stopBillingTimers();
        await supabase.functions.invoke("chat-manager", {
          body: {
            action: "end_chat",
            chat_id: chatId.current,
            end_reason: "user_went_offline"
          }
        });
        setIsSessionActive(false);
        setBillingSessionId(null);
        setBillingSessionStartedAt(null);
      } catch (error) {
        console.error("[OFFLINE] Failed to end chat session:", error);
      }
    }

    await setOnlineStatus(false);
    toast({
      title: "You're now offline",
      description: "You won't receive new chat requests."
    });
    navigate(currentUserGender === "female" ? "/women-dashboard" : "/dashboard");
  };

  /**
   * markAsRead Function
   * 
   * Updates a message's is_read status to true.
   * Called when receiving messages from partner.
   * 
   * @param messageId - UUID of message to mark
   */
  const markAsRead = async (messageId: string) => {
    const { error } = await supabase
      .from("chat_messages")
      .update({ is_read: true })
      .eq("id", messageId)
      .eq("is_read", false);
    if (error) {
      console.warn("[Chat] markAsRead failed:", error.message);
    }
  };

  /**
   * Delete message for me or for everyone (WhatsApp-style)
   */
  const handleDeleteMessage = async (messageId: string, deleteType: 'for_me' | 'for_everyone') => {
    try {
      if (deleteType === 'for_everyone') {
        const { error } = await supabase
          .from('chat_messages')
          .update({
            deleted_for_everyone: true,
            deleted_for_sender: true,
            deleted_for_receiver: true,
            deleted_at: new Date().toISOString(),
          } as any)
          .eq('id', messageId);
        if (error) throw error;
        setMessages(prev => prev.filter(m => m.id !== messageId));
        toast({ title: 'Message deleted for everyone' });
      } else {
        const msg = messages.find(m => m.id === messageId);
        const isMsgSender = msg?.senderId === currentUserId;
        const updateField = isMsgSender ? 'deleted_for_sender' : 'deleted_for_receiver';
        const { error } = await supabase
          .from('chat_messages')
          .update({ [updateField]: true, deleted_at: new Date().toISOString() } as any)
          .eq('id', messageId);
        if (error) throw error;
        setMessages(prev => prev.filter(m => m.id !== messageId));
        toast({ title: 'Message deleted' });
      }
    } catch (err) {
      console.error('Delete message error:', err);
      toast({ title: 'Error', description: 'Failed to delete message', variant: 'destructive' });
    }
  };

  /**
   * Delete ALL messages in this chat for me only (other person still sees them)
   */
  const handleDeleteAllForMe = async () => {
    if (!chatId.current || !currentUserId) return;
    if (!confirm('Delete all messages in this chat for you? The other person will still see them.')) return;
    try {
      // Mark all messages I sent as deleted_for_sender
      const { error: e1 } = await supabase
        .from('chat_messages')
        .update({ deleted_for_sender: true, deleted_at: new Date().toISOString() } as any)
        .eq('chat_id', chatId.current)
        .eq('sender_id', currentUserId);
      if (e1) throw e1;
      // Mark all messages I received as deleted_for_receiver
      const { error: e2 } = await supabase
        .from('chat_messages')
        .update({ deleted_for_receiver: true, deleted_at: new Date().toISOString() } as any)
        .eq('chat_id', chatId.current)
        .eq('receiver_id', currentUserId);
      if (e2) throw e2;
      setMessages([]);
      toast({ title: 'Messages deleted', description: 'All messages cleared from your view.' });
    } catch (err) {
      console.error('Delete all for me error:', err);
      toast({ title: 'Error', description: 'Failed to delete messages', variant: 'destructive' });
    }
  };

  /**
   * Delete ALL messages in this chat for everyone (permanently for both users)
   */
  const handleDeleteAllForEveryone = async () => {
    if (!chatId.current || !currentUserId) return;
    if (!confirm('Permanently delete all messages in this chat for BOTH you and the other person? This cannot be undone.')) return;
    try {
      const { error } = await supabase
        .from('chat_messages')
        .update({
          deleted_for_everyone: true,
          deleted_for_sender: true,
          deleted_for_receiver: true,
          deleted_at: new Date().toISOString(),
        } as any)
        .eq('chat_id', chatId.current);
      if (error) throw error;
      setMessages([]);
      toast({ title: 'Messages deleted for everyone' });
    } catch (err) {
      console.error('Delete all for everyone error:', err);
      toast({ title: 'Error', description: 'Failed to delete messages', variant: 'destructive' });
    }
  };

  // === Reaction handler ===
  const handleReaction = async (messageId: string, emoji: string) => {
    try {
      const { data: existing } = await supabase
        .from('message_reactions')
        .select('id')
        .eq('message_id', messageId)
        .eq('user_id', currentUserId)
        .eq('emoji', emoji)
        .maybeSingle();
      if (existing) {
        await supabase.from('message_reactions').delete().eq('id', existing.id);
      } else {
        await supabase.from('message_reactions').insert({ message_id: messageId, user_id: currentUserId, emoji } as any);
      }
    } catch (err) { console.error('Reaction error:', err); }
  };

  // === Reply handler ===
  const handleReply = (messageId: string, text: string, senderName: string) => {
    setReplyTo({ id: messageId, text, senderName });
  };

  // === Forward handler ===
  const handleForward = (messageId: string, text: string) => {
    setForwardMsg({ id: messageId, text });
  };

  // === Edit handler ===
  const handleStartEdit = (messageId: string, currentText: string) => {
    setEditingMsg({ id: messageId, text: currentText });
  };

  const handleSaveEdit = async (newText: string) => {
    if (!editingMsg) return;
    try {
      await supabase.from('chat_messages').update({
        message: newText,
        is_edited: true,
        edited_at: new Date().toISOString(),
        original_message: editingMsg.text,
      } as any).eq('id', editingMsg.id);
      setMessages(prev => prev.map(m => m.id === editingMsg.id ? { ...m, message: newText, isEdited: true } : m));
      setEditingMsg(null);
      toast({ title: 'Message edited' });
    } catch (err) {
      console.error('Edit error:', err);
      toast({ title: 'Error', description: 'Failed to edit message', variant: 'destructive' });
    }
  };

  // === Pin handler ===
  const handlePinToggle = async (messageId: string, isPinned: boolean) => {
    try {
      await supabase.from('chat_messages').update({
        is_pinned: !isPinned,
        pinned_at: !isPinned ? new Date().toISOString() : null,
        pinned_by: !isPinned ? currentUserId : null,
      } as any).eq('id', messageId);
      setMessages(prev => prev.map(m => m.id === messageId ? { ...m, isPinned: !isPinned } : m));
      toast({ title: isPinned ? 'Message unpinned' : 'Message pinned' });
    } catch (err) {
      console.error('Pin error:', err);
    }
  };


  /**
   * handleSendMessage Function
   * 
   * Sends a new message to the chat partner.
   * Messages are sent as plain text; translation happens via realtime subscription.
   */
  const handleSendMessage = async (messageText: string) => {
    const text = messageText.trim();
    if (!text || sendingLockRef.current) return;
    if (!chatPartner) {
      toast({
        title: "Not ready",
        description: "Chat is still loading. Please wait.",
        variant: "destructive",
      });
      return;
    }

    // Check if blocked
    if (isBlocked || isBlockedByPartner) {
      toast({
        title: "Cannot Send Message",
        description: isBlocked 
          ? "You have blocked this user. Unblock to send messages."
          : "You cannot send messages to this user.",
        variant: "destructive",
      });
      return;
    }

    // Content moderation - block phone numbers, emails, social media (excluding sexual content for 1:1 chat)
    const moderationResult = moderateMessage1to1(text);
    if (moderationResult.isBlocked) {
      toast({
        title: "Message Blocked",
        description: moderationResult.reason,
        variant: "destructive",
      });
      return;
    }

    sendingLockRef.current = true;
    setNewMessage("");
    sendTyping(false);

    const tempId = `temp-${Date.now()}`;

    setMessages((prev) => [...prev, {
      id: tempId,
      senderId: currentUserId,
      message: text,
      isTranslated: false,
      isRead: false,
      isTranslating: false,
      createdAt: new Date().toISOString(),
    }]);

    try {
      const insertData: any = {
        chat_id: chatId.current,
        sender_id: currentUserId,
        receiver_id: chatPartner.userId,
        message: text,
      };
      if (replyTo) {
        insertData.reply_to_id = replyTo.id;
        setReplyTo(null);
      }
      const { error } = await supabase
        .from("chat_messages")
        .insert(insertData);

      if (error) {
        setMessages((prev) => prev.filter((m) => m.id !== tempId));
        throw error;
      }
    } catch (error) {
      console.error("Error sending message:", error);
      setMessages((prev) => prev.map((m) =>
        m.id === tempId ? { ...m, sendFailed: true } : m
      ));
      toast({ title: "Message not sent", description: "Tap the message to retry.", variant: "destructive" });
    } finally {
      sendingLockRef.current = false;
    }
  };

  /**
   * Handle Image Selection
   */
   const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      // Accept by MIME type OR by common image extension (some devices report empty/wrong MIME)
      const ext = file.name.split(".").pop()?.toLowerCase() || "";
      const mediaExts = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tiff", "avif", "svg",
                          "mp4", "webm", "mov", "avi", "mkv", "3gp"];
      const isMedia = file.type.startsWith("image/") || file.type.startsWith("video/") || mediaExts.includes(ext);
      if (!isMedia) {
        toast({
          title: "Invalid file",
          description: "Please select an image or video file",
          variant: "destructive",
        });
        return;
      }
      if (file.size > 50 * 1024 * 1024) { // 50MB limit
        toast({
          title: "File too large",
          description: "Maximum image size is 50MB",
          variant: "destructive",
        });
        return;
      }
      setSelectedFile(file);
      setPreviewUrl(file.type.startsWith("video/") ? null : URL.createObjectURL(file));
      setIsAttachmentOpen(false);
    }
  };

  /**
   * Handle File Selection
   */
  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      if (file.size > 50 * 1024 * 1024) { // 50MB limit
        toast({
          title: "File too large",
          description: "Maximum file size is 50MB",
          variant: "destructive",
        });
        return;
      }
      setSelectedFile(file);
      setPreviewUrl(null);
      setIsAttachmentOpen(false);
    }
  };

  /**
   * Open Camera for Selfie
   */
  const openCamera = async () => {
    try {
      // BUG-SELFIE-01 FIX: Acquire stream BEFORE setting state (iOS Safari)
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { facingMode: "user" },
        audio: false 
      });
      streamRef.current = stream;
      setIsAttachmentOpen(false);
      setIsCameraOpen(true);
      // Stream will be assigned to video ref via useEffect below
    } catch (error) {
      console.error("Camera error:", error);
      const camErr = classifyError(error);
      toast({ title: camErr.title, description: camErr.message, variant: "destructive" });
    }
  };

  // BUG-SELFIE-01 FIX: Assign stream to video element after render
  useEffect(() => {
    if (isCameraOpen && videoRef.current && streamRef.current) {
      videoRef.current.srcObject = streamRef.current;
    }
  }, [isCameraOpen]);

  /**
   * Capture Selfie
   */
  const captureSelfie = () => {
    const video = videoRef.current;
    const canvas = canvasRef.current;
    if (!video || !canvas) return;
    
    // BUG-SELFIE-03 FIX: Check video is actually playing before capture
    const doCapture = () => {
      if (video.videoWidth === 0) {
        requestAnimationFrame(doCapture);
        return;
      }
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      const ctx = canvas.getContext("2d");
      if (ctx) {
        ctx.drawImage(video, 0, 0);
        canvas.toBlob((blob) => {
          if (blob) {
            const file = new File([blob], `selfie_${Date.now()}.jpg`, { type: "image/jpeg" });
            setSelectedFile(file);
            setPreviewUrl(URL.createObjectURL(blob));
            closeCamera();
          }
        }, "image/jpeg", 0.8);
      }
    };
    doCapture();
  };

  /**
   * Close Camera
   */
  const closeCamera = () => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }
    setIsCameraOpen(false);
  };

  /**
   * Cancel Selected File
   */
  const cancelSelectedFile = () => {
    setSelectedFile(null);
    setPreviewUrl(null);
    if (imageInputRef.current) imageInputRef.current.value = "";
    if (fileInputRef.current) fileInputRef.current.value = "";
  };

  /**
   * Upload File to Supabase Storage
   */
  const uploadFile = async (file: File): Promise<string | null> => {
    try {
      const fileExt = file.name.split(".").pop();
      const randomSuffix = crypto.randomUUID().slice(0, 8);
      // Physical host path when self-hosted Storage is bind-mounted:
      //   /meowmeow/app/attachment/<userId>/<chatId>/<file>
      const storagePath = `meowmeow/app/attachment/${currentUserId}/${chatId.current}/${Date.now()}-${randomSuffix}.${fileExt}`;

      const mimeMap: Record<string, string> = {
        jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", gif: "image/gif",
        webp: "image/webp", heic: "image/heic", heif: "image/heif", bmp: "image/bmp",
        tiff: "image/tiff", avif: "image/avif", svg: "image/svg+xml",
        mp4: "video/mp4", webm: "video/webm", mov: "video/quicktime", avi: "video/x-msvideo",
        mp3: "audio/mpeg", wav: "audio/wav", ogg: "audio/ogg", m4a: "audio/x-m4a",
        pdf: "application/pdf", doc: "application/msword",
        docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        xls: "application/vnd.ms-excel",
        xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        ppt: "application/vnd.ms-powerpoint",
        pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        txt: "text/plain", csv: "text/csv", rtf: "application/rtf",
        zip: "application/zip",
      };
      const extLower = (fileExt || "").toLowerCase();
      const contentType = file.type || mimeMap[extLower] || "application/octet-stream";

      const { data, error } = await supabase.storage
        .from("meowmeow-app-attachment")
        .upload(storagePath, file, { cacheControl: "3600", upsert: false, contentType });

      if (error) throw error;

      return `chat-attachment://${storagePath}`;
    } catch (error) {
      console.error("Upload error:", error);
      const classified = classifyError(error);
      toast({ title: classified.title, description: classified.message, variant: "destructive" });
      return null;
    }
  };

  /**
   * Send Message with Attachment
   */
  const handleSendWithAttachment = async () => {
    if (!selectedFile || !chatPartner || isSending) return;

    setIsSending(true);
    setIsUploading(true);

    try {
      const attachmentUrl = await uploadFile(selectedFile);
      if (!attachmentUrl) {
        throw new Error("Failed to upload file");
      }

      const attachmentType = selectedFile.type.startsWith("image/") ? "image" : "file";
      const videoExts = ["mp4", "webm", "mov", "avi", "mkv", "3gp"];
      const isVideo = selectedFile.type.startsWith("video/") || videoExts.includes((selectedFile.name.split(".").pop() || "").toLowerCase());
      const messageText = newMessage.trim() || (attachmentType === "image" ? "📷 Image" : isVideo ? "🎬 Video" : `📎 ${selectedFile.name}`);

      const { error } = await supabase
        .from("chat_messages")
        .insert({
          chat_id: chatId.current,
          sender_id: currentUserId,
          receiver_id: chatPartner.userId,
          message: `${messageText}\n[attachment:${attachmentUrl}]`,
        });

      if (error) throw error;

      setNewMessage("");
      cancelSelectedFile();
      toast({
        title: "Sent",
        description: attachmentType === "image" ? "Image sent successfully" : "File sent successfully",
      });
    } catch (error) {
      console.error("Error sending attachment:", error);
      toast({ title: "Attachment not sent", description: ERROR_MESSAGES.chat.attachmentFailed, variant: "destructive" });
    } finally {
      setIsSending(false);
      setIsUploading(false);
    }
  };

  /**
   * Extract Attachment from Message
   */
  const extractAttachment = (message: string): { text: string; attachmentUrl?: string; voiceUrl?: string } => {
    const voiceUrl = extractVoiceUrl(message);
    if (voiceUrl) {
      return { text: '', voiceUrl };
    }
    
    // Check for regular attachment
    const attachmentMatch = message.match(/\[attachment:(.*?)\]/);
    if (attachmentMatch) {
      const text = message.replace(/\n?\[attachment:.*?\]/, "").trim();
      return { text, attachmentUrl: attachmentMatch[1] };
    }
    return { text: message };
  };

  // Signed URL cache for chat attachments
  const signedUrlCache = useRef<Map<string, string>>(new Map());

  /**
   * Resolve attachment URL — generates signed URL for private bucket paths,
   * passes through legacy public URLs unchanged.
   */
  const resolveAttachmentUrl = useCallback(async (url: string): Promise<string> => {
    // Only resolve if it's a storage attachment
    const normalized = normalizeChatAttachmentUrl(url) || url;
    if (!normalized.includes('chat-attachment://')) return normalized;

    const cached = signedUrlCache.current.get(normalized);
    if (cached) return cached;

    // Remove the prefix to get the actual storage path
    let cleanStoragePath = storagePathFromAttachmentUrl(normalized);
    
    // Explicitly remove bucket name if it's prepended to the path
    cleanStoragePath = cleanStoragePath.replace(/^meowmeow-app-attachment\//, '').replace(/^chat-attachments\//, '');
    
    console.log('[Chat] Resolving attachment URL:', { original: url, clean: cleanStoragePath });

    // Determine the bucket (same logic as used during upload)
    const primaryBucket = cleanStoragePath.startsWith('meowmeow/app/attachment/')
      ? 'meowmeow-app-attachment'
      : 'chat-attachments';
    
    let { data, error } = await supabase.storage.from(primaryBucket).createSignedUrl(cleanStoragePath, 3600);
    
    // Fallback if not found in primary
    if ((error || !data?.signedUrl) && primaryBucket === 'meowmeow-app-attachment') {
        ({ data, error } = await supabase.storage.from('chat-attachments').createSignedUrl(cleanStoragePath, 3600));
    }
    
    if (error || !data?.signedUrl) {
      console.error('[Chat] Failed to generate signed URL for path:', cleanStoragePath, error?.message);
      return '';
    }
    signedUrlCache.current.set(normalized, data.signedUrl);
    return data.signedUrl;
  }, []);

  /**
   * formatTime Function
   * 
   * Formats timestamp to local time string (HH:MM format).
   * 
   * @param dateString - ISO date string
   * @returns Formatted time string
   */
  const formatTime = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  };

  /**
   * formatDate Function
   * 
   * Formats date for message grouping headers.
   * Returns "Today", "Yesterday", or date string.
   * 
   * @param dateString - ISO date string
   * @returns Human-readable date label
   */
  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    if (date.toDateString() === today.toDateString()) {
      return "Today";
    } else if (date.toDateString() === yesterday.toDateString()) {
      return "Yesterday";
    } else {
      return date.toLocaleDateString([], { month: "short", day: "numeric" });
    }
  };

  /**
   * groupedMessages
   * 
   * Groups messages by date for section headers.
   * Uses reduce to create object with date keys and message arrays.
   */
  const groupedMessages = messages.reduce((groups, message) => {
    const date = formatDate(message.createdAt);
    if (!groups[date]) {
      groups[date] = [];
    }
    groups[date].push(message);
    return groups;
  }, {} as Record<string, Message[]>);

  // ============= LOADING STATE RENDER =============
  
  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: WA.chatBg }}>
        <div className="text-center space-y-4">
          <Loader2 className="w-12 h-12 animate-spin mx-auto" style={{ color: WA.headerBg }} />
          <p style={{ color: WA.metaColor }}>Loading chat...</p>
        </div>
      </div>
    );
  }

  // ============= MAIN RENDER =============
  
  return (
    <div className="min-h-screen flex flex-col" style={{ background: WA.chatBg }}>
      {/* ============= INCOMING CALL BANNER ============= */}
      {incomingCall && callStatus === 'idle' && (
        <IncomingCallBanner
          callerName={incomingCall.callerName}
          callerPhoto={incomingCall.callerPhoto}
          callType={incomingCall.callType}
          onAccept={() => {
            acceptCall(incomingCall.callId, incomingCall.callType, incomingCall.callerUserId, incomingCall.callerName, incomingCall.callerPhoto);
            clearIncomingCall();
          }}
          onDecline={() => {
            declineCall(incomingCall.callId);
            clearIncomingCall();
          }}
        />
      )}
      {/* ============= WHATSAPP CALL SCREEN ============= */}
      {(callStatus === 'calling' || callStatus === 'connecting' || callStatus === 'active') && (
        <CallScreen
          status={callStatus}
          activeCall={activeCall}
          isMuted={isMuted}
          isCameraOff={isCameraOff}
          onEnd={endCall}
          onToggleMute={toggleMute}
          onToggleCamera={toggleCamera}
          userGender={currentUserGender as 'male' | 'female'}
        />
      )}
      {/* ============= HEADER SECTION ============= */}
      <header className="sticky top-0 z-50 pt-[env(safe-area-inset-top)]" style={{ background: WA.headerBg }}>
        <div className="px-3 py-2.5 flex items-center gap-3">
          {/* Back button */}
          <button 
            onClick={async () => {
              await stopBillingTimers();
              const dashboardPath = currentUserGender === "female" ? "/women-dashboard" : "/dashboard";
              window.history.length > 1 ? navigate(-1) : navigate(dashboardPath);
            }}
            className="p-1.5 rounded-full transition-colors"
            style={{ color: WA.headerText }}
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          
          {/* Chat partner info - clickable to view profile */}
          {chatPartner && (
            <div 
              className="flex items-center gap-2.5 flex-1 cursor-pointer"
              onClick={() => navigate(`/profile/${chatPartner.userId}`)}
            >
              {/* Partner avatar with online indicator */}
              <div className="relative">
                {chatPartner.avatar ? (
                  <img 
                    src={chatPartner.avatar} 
                    alt={chatPartner.fullName}
                    className="w-10 h-10 rounded-full object-cover"
                    style={{ border: '2px solid rgba(255,255,255,0.2)' }}
                  />
                ) : (
                  <div className="w-10 h-10 rounded-full flex items-center justify-center" style={{ background: 'rgba(255,255,255,0.2)' }}>
                    <span className="text-lg font-bold" style={{ color: WA.headerText }}>
                      {chatPartner.fullName.charAt(0).toUpperCase()}
                    </span>
                  </div>
                )}
                <div
                  className="absolute -bottom-0.5 -right-0.5 w-[10px] h-[10px] rounded-full"
                  style={{
                    background: chatPartner.isOnline ? WA.onlineDot : WA.offlineDot,
                    border: `2px solid ${WA.headerBg}`,
                  }}
                />
              </div>

              <div className="flex-1 min-w-0">
                <p className="truncate" style={{ fontSize: 15, fontWeight: 500, color: WA.headerText }}>{chatPartner.fullName}</p>
                <div className="flex items-center gap-1" style={{ color: WA.headerSub }}>
                  <PartnerStatusLine
                    state={partnerState}
                    partnerName={chatPartner.fullName}
                    lastSeen={partnerLastSeen}
                    fallbackOnline={chatPartner.isOnline}
                  />
                  {chatPartner.preferredLanguage !== currentUserLanguage && (
                    <>
                      <span style={{ fontSize: 12 }}>•</span>
                      <span style={{ fontSize: 12 }}>{chatPartner.preferredLanguage}</span>
                    </>
                  )}
                  {isSessionActive && isBillingDriver && bothReplied && (
                    <>
                      <span style={{ fontSize: 12 }}>•</span>
                      <span style={{ fontSize: 12 }}>
                        {skipReason === "admin"
                          ? "Not charged"
                          : minutesBilled > 0
                            ? (currentUserGender === "male"
                              ? `Spent ₹${totalCharged.toFixed(2)}`
                              : `Earned ₹${(minutesBilled * 2).toFixed(2)}`)
                            : isBilling
                              ? `Billing ₹${Math.max(4, Math.ceil(Math.max(elapsedSeconds, 1) / 60) * 4)} · ${elapsedSeconds}s`
                              : ""}
                        {minutesBilled > 0 ? ` · ${minutesBilled}m` : ""}
                      </span>
                    </>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* Audio & Video Call Buttons — hidden unless this pair is allowed to call */}
          {(() => {
            const showAudioCall = currentUserGender === "male" && chatPartner && canPlaceCall && settings.audioCallEnabled !== false;
            const showVideoCall = currentUserGender === "male" && chatPartner && canPlaceCall && settings.videoCallEnabled !== false;
            if (!showAudioCall && !showVideoCall) return null;
            return (
          <div className="flex items-center gap-0.5">
            {showAudioCall && (
            <button
              className="p-1.5 rounded-full transition-colors"
              style={{ color: WA.headerText }}
              onClick={() => initiateCall(chatPartner.userId, chatPartner.fullName, chatPartner.avatar, 'audio')}
            >
              <Phone className="w-5 h-5" />
            </button>
            )}
            {showVideoCall && (
            <button
              className="p-1.5 rounded-full transition-colors"
              style={{ color: WA.headerText }}
              onClick={() => initiateCall(chatPartner.userId, chatPartner.fullName, chatPartner.avatar, 'video')}
            >
              <Video className="w-5 h-5" />
            </button>
            )}
          </div>
            );
          })()}
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <button className="p-1.5 rounded-full transition-colors" style={{ color: WA.headerText }}>
                <MoreVertical className="w-5 h-5" />
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-48">
              {/* Friend Status Indicator */}
              {isFriend && (
                <div className="px-2 py-1.5 text-xs text-success flex items-center gap-1">
                  <Heart className="w-3 h-3 fill-current" />
                  Friends
                </div>
              )}
              
              {/* Friend/Unfriend - Available for both genders */}
              {isFriend ? (
                <DropdownMenuItem 
                  onClick={handleRemoveFriend}
                  disabled={actionLoading}
                  className="text-destructive focus:text-destructive"
                >
                  <UserMinus className="w-4 h-4 mr-2" />
                  Unfriend
                </DropdownMenuItem>
              ) : (
                <DropdownMenuItem 
                  onClick={handleAddFriend}
                  disabled={actionLoading || isBlocked}
                >
                  <UserPlus className="w-4 h-4 mr-2" />
                  Send Friend Request
                </DropdownMenuItem>
              )}
              
              <DropdownMenuSeparator />
              
              {/* Block/Unblock - Available for both genders */}
              {isBlocked ? (
                <DropdownMenuItem 
                  onClick={handleUnblockUser}
                  disabled={actionLoading}
                >
                  <Shield className="w-4 h-4 mr-2" />
                  Unblock User
                </DropdownMenuItem>
              ) : (
                <DropdownMenuItem 
                  onClick={() => setShowBlockDialog(true)}
                  disabled={actionLoading}
                  className="text-destructive focus:text-destructive"
                >
                  <Ban className="w-4 h-4 mr-2" />
                  Block User
                </DropdownMenuItem>
              )}
              
              <DropdownMenuSeparator />
              
              {/* View Profile - Available for both genders */}
              <DropdownMenuItem 
                onClick={() => chatPartner && navigate(`/profile/${chatPartner.userId}`)}
              >
                <Circle className="w-4 h-4 mr-2" />
                View Profile
              </DropdownMenuItem>
              
              {/* CHT-11 FIX: Stop Chat - Available for both genders */}
              {(
                <>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem 
                    onClick={() => setShowStopChatDialog(true)}
                    disabled={isStoppingChat}
                    className="text-destructive focus:text-destructive"
                  >
                    <PhoneOff className="w-4 h-4 mr-2" />
                    Stop Chat
                  </DropdownMenuItem>
                </>
              )}
              
              <DropdownMenuSeparator />

              {/* Delete messages for me */}
              <DropdownMenuItem onClick={handleDeleteAllForMe}>
                <Trash2 className="w-4 h-4 mr-2" />
                Delete messages for me
              </DropdownMenuItem>

              {/* Delete messages for everyone */}
              <DropdownMenuItem
                onClick={handleDeleteAllForEveryone}
                className="text-destructive focus:text-destructive"
              >
                <Trash2 className="w-4 h-4 mr-2" />
                Delete messages for everyone
              </DropdownMenuItem>

              <DropdownMenuSeparator />

              {/* Go Offline - Available for both genders */}
              <DropdownMenuItem 
                onClick={handleGoOffline}
                className="text-warning focus:text-warning"
              >
                <LogOut className="w-4 h-4 mr-2" />
                Go Offline
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </header>

      {/* Block Confirmation Dialog */}
      <AlertDialog open={showBlockDialog} onOpenChange={setShowBlockDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle className="flex items-center gap-2">
              <AlertTriangle className="w-5 h-5 text-destructive" />
              Block {chatPartner?.fullName}?
            </AlertDialogTitle>
            <AlertDialogDescription>
              This will prevent you from receiving messages from this user. 
              They won't be notified that you blocked them.
              {isFriend && " This will also remove them from your friends list."}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction 
              onClick={handleBlockUser}
              className="bg-destructive hover:bg-destructive/90"
            >
              Block User
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Stop Chat Confirmation Dialog - Both genders */}
      {(
        <AlertDialog open={showStopChatDialog} onOpenChange={setShowStopChatDialog}>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle className="flex items-center gap-2">
                <PhoneOff className="w-5 h-5 text-destructive" />
                Stop Chat?
              </AlertDialogTitle>
              <AlertDialogDescription>
                This will end the current chat session.{currentUserGender === "male" ? " Billing will stop and you'll be disconnected from this conversation." : " You'll be disconnected from this conversation."}
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction 
                onClick={handleStopChat}
                className="bg-destructive hover:bg-destructive/90"
                disabled={isStoppingChat}
              >
                {isStoppingChat ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Stopping...
                  </>
                ) : (
                  "Stop Chat"
                )}
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      )}

      {/* Blocked by partner warning */}
      {isBlockedByPartner && (
        <div className="px-4 py-2" style={{ background: 'rgba(198,40,40,0.08)' }}>
          <p style={{ fontSize: 12, color: '#C62828', textAlign: 'center' }}>
            You cannot send messages to this user.
          </p>
        </div>
      )}

      {/* Your own block warning */}
      {isBlocked && (
        <div className="px-4 py-2" style={{ background: 'rgba(198,40,40,0.08)' }}>
          <p style={{ fontSize: 12, color: '#C62828', textAlign: 'center' }}>
            You have blocked this user. Unblock to send messages.
          </p>
        </div>
      )}

      {/* Translation happens automatically via realtime subscription */}

      {/* ============= MESSAGES AREA ============= */}
      <main ref={messagesScrollRef} className="flex-1 overflow-y-auto wa-chat-scroll px-3 py-2" style={{ background: WA.chatBg }}>
        <div className="space-y-1">
          {/* Iterate through date groups */}
          {Object.entries(groupedMessages).map(([date, dateMessages]) => (
            <div key={date} className="space-y-1">
              {/* Date separator label */}
              <div className="flex justify-center my-2">
                <div
                  className="px-3 py-1 rounded-lg shadow-sm"
                  style={{ background: WA.dateSepBg, color: WA.dateSepText, fontSize: 11, fontWeight: 500 }}
                >
                  {date}
                </div>
              </div>

              {/* Messages for this date */}
              {dateMessages.map((message) => {
                if (message.isSystem) {
                  return (
                    <div key={message.id} className="flex justify-center my-2">
                      <div
                        className="px-3 py-1 rounded-full shadow-sm"
                        style={{ background: WA.dateSepBg, color: WA.dateSepText, fontSize: 11, fontWeight: 500 }}
                      >
                        {message.message}
                      </div>
                    </div>
                  );
                }

                // Determine if message is from current user
                const isMine = message.senderId === currentUserId;
                const { text: messageText, attachmentUrl, voiceUrl } = extractAttachment(message.message);
                const ownerName = isMine ? currentUserProfile.fullName : (chatPartner?.fullName || "User");
                const ownerAvatar = isMine ? currentUserProfile.avatar : (chatPartner?.avatar || "");
                const ownerInitial = (ownerName || "U").charAt(0).toUpperCase();
                
                // Display: translated native text if available, otherwise original
                // Per spec: both sender AND receiver see native script of their own language
                const displayText = messageText;
                const translationLine = !isMine
                  && message.translatedMessage
                  && message.translatedMessage.trim().toLowerCase() !== messageText.trim().toLowerCase()
                    ? message.translatedMessage
                    : undefined;
                
                // Skip empty voice message placeholders
                if (message.message === '🎤 Voice message') {
                  return null;
                }

                return (
                  <MessageActions
                    key={message.id}
                    messageId={message.id}
                    messageText={displayText || message.message}
                    senderId={message.senderId}
                    currentUserId={currentUserId}
                    chatId={activeChatId}
                    createdAt={message.createdAt}
                    isPinned={message.isPinned}
                    senderName={ownerName}
                    onReply={handleReply}
                    onForward={handleForward}
                    onEdit={handleStartEdit}
                    onDelete={handleDeleteMessage}
                    onReaction={handleReaction}
                    onPinToggle={handlePinToggle}
                  >
                    <div
                      className={`flex ${isMine ? "justify-end" : "justify-start"} mb-[2px]`}
                    >
                      <div className={`flex items-end gap-1 ${isMine ? "flex-row-reverse" : ""}`} style={{ maxWidth: '85%' }}>
                        <div className="w-8 flex-shrink-0">
                          {ownerAvatar ? (
                            <img src={ownerAvatar} alt={ownerName} className="w-8 h-8 rounded-full object-cover" />
                          ) : (
                            <div className="w-8 h-8 rounded-full flex items-center justify-center" style={{ background: isMine ? '#DCF8C6' : '#DDD' }}>
                              <span className="text-xs font-bold" style={{ color: '#555' }}>{ownerInitial}</span>
                            </div>
                          )}
                        </div>
                        <div className={`flex flex-col ${isMine ? "items-end" : "items-start"} min-w-0`}>
                          <span
                            className="px-1 mb-0.5 truncate max-w-full"
                            style={{ fontSize: 11, fontWeight: 600, color: isMine ? '#075E54' : '#128C7E' }}
                          >
                            {ownerName}
                          </span>
                          {message.isForwarded && (
                            <span style={{ fontSize: 11, color: WA.metaColor, fontStyle: 'italic' }} className="block mb-0.5 px-1">↗ Forwarded</span>
                          )}

                          {/* Reply quote */}
                          {message.replyToText && (
                            <ReplyPreview replyToText={message.replyToText} replyToSender={message.replyToSender || ''} isOwn={isMine} compact />
                          )}

                          {voiceUrl && (
                            <div style={{
                              background: isMine ? WA.sentBubble : WA.recvBubble,
                              borderRadius: isMine ? '8px 8px 2px 8px' : '8px 8px 8px 2px',
                              padding: '6px 10px 4px 10px',
                              boxShadow: '0 1px 0.5px rgba(0,0,0,0.13)',
                            }}>
                              <ResolvedVoicePlayer voiceUrl={voiceUrl} isMine={isMine} resolveUrl={resolveAttachmentUrl} />
                            </div>
                          )}
                          {attachmentUrl && (
                            <div style={{
                              borderRadius: isMine ? '8px 8px 2px 8px' : '8px 8px 8px 2px',
                              overflow: 'hidden',
                              boxShadow: '0 1px 0.5px rgba(0,0,0,0.13)',
                            }}>
                              <ChatAttachment url={attachmentUrl} isMine={isMine} resolveUrl={resolveAttachmentUrl} />
                            </div>
                          )}
                          
                          {displayText && !displayText.startsWith("📷") && !displayText.startsWith("📎") && !voiceUrl && (
                            <div style={{
                              background: isMine ? WA.sentBubble : WA.recvBubble,
                              borderRadius: isMine ? '8px 8px 2px 8px' : '8px 8px 8px 2px',
                              padding: '6px 10px 4px 10px',
                              boxShadow: '0 1px 0.5px rgba(0,0,0,0.13)',
                            }}>
                              {message.isTranslating ? (
                                <>
                                  <p className="whitespace-pre-wrap break-words unicode-text" style={{ fontSize: 14, color: isMine ? WA.sentText : WA.recvText }} dir="auto">{displayText}</p>
                                  <div className="flex items-center gap-1.5 mt-0.5">
                                    <Loader2 className="h-3 w-3 animate-spin" style={{ color: WA.metaColor }} />
                                    <span style={{ fontSize: 10, color: WA.metaColor }}>Translating…</span>
                                  </div>
                                </>
                              ) : (
                                <>
                                  <p className="whitespace-pre-wrap break-words unicode-text" style={{ fontSize: 14, color: isMine ? WA.sentText : WA.recvText }} dir="auto">{displayText}</p>
                                  {translationLine && (
                                    <p className="whitespace-pre-wrap break-words" style={{ fontSize: 12, color: WA.subtitleColor, fontStyle: 'italic', marginTop: 2 }} dir="auto">{translationLine}</p>
                                  )}
                                </>
                              )}
                              {/* Meta row */}
                              <div className="flex items-center justify-end gap-[3px]" style={{ marginTop: 2 }}>
                                <span style={{ fontSize: 11, color: WA.metaColor }}>{formatTime(message.createdAt)}</span>
                                {message.isEdited && <span style={{ fontSize: 10, color: WA.metaColor, fontStyle: 'italic' }}>edited</span>}
                                {message.isPinned && <Pin className="w-3 h-3" style={{ color: WA.headerBg }} />}
                                {isMine && (message.isRead ? <CheckCheck className="w-[14px] h-[14px]" style={{ color: WA.tickRead }} /> : <Check className="w-[14px] h-[14px]" style={{ color: WA.tickSent }} />)}
                              </div>
                            </div>
                          )}

                          {/* Meta row for voice/attachment-only messages */}
                          {(voiceUrl || attachmentUrl) && (!displayText || displayText.startsWith("📷") || displayText.startsWith("📎")) && (
                            <div className="flex items-center justify-end gap-[3px] px-1" style={{ marginTop: 2 }}>
                              <span style={{ fontSize: 11, color: WA.metaColor }}>{formatTime(message.createdAt)}</span>
                              {isMine && (message.isRead ? <CheckCheck className="w-[14px] h-[14px]" style={{ color: WA.tickRead }} /> : <Check className="w-[14px] h-[14px]" style={{ color: WA.tickSent }} />)}
                            </div>
                          )}

                          {/* Reactions */}
                          {message.reactions && message.reactions.length > 0 && (
                            <MessageReactions reactions={message.reactions} onToggle={(emoji) => handleReaction(message.id, emoji)} isOwn={isMine} />
                          )}
                        </div>
                      </div>
                    </div>
                  </MessageActions>
                );
              })}
            </div>
          ))}
          
          {/* Typing indicator */}
          {isTyping && (
            <div className="flex justify-start mb-[2px]">
              <div style={{
                background: WA.recvBubble,
                borderRadius: '8px 8px 8px 2px',
                padding: '10px 14px',
                display: 'inline-flex',
                gap: 4,
                alignItems: 'center',
                boxShadow: '0 1px 0.5px rgba(0,0,0,0.13)',
              }}>
                <span className="wa-typing-dot" style={{ width: 8, height: 8, borderRadius: '50%', background: '#999', animationDelay: '0s' }} />
                <span className="wa-typing-dot" style={{ width: 8, height: 8, borderRadius: '50%', background: '#999', animationDelay: '0.2s' }} />
                <span className="wa-typing-dot" style={{ width: 8, height: 8, borderRadius: '50%', background: '#999', animationDelay: '0.4s' }} />
              </div>
            </div>
          )}

          {/* Invisible element at bottom for auto-scroll anchor */}
          <div ref={messagesEndRef} />
        </div>
      </main>
      {/* ============= MESSAGE INPUT AREA ============= */}
      <footer className="sticky bottom-0 pb-[env(safe-area-inset-bottom)]" style={{ background: WA.inputBarBg }}>
        <div>
          {/* Issue 2.3: Show explanation when blocked */}
          {(isBlocked || isBlockedByPartner) && (
            <div className="flex items-center gap-2 px-3 py-2 mx-2 mb-1 rounded-md" style={{ background: 'rgba(198,40,40,0.08)' }}>
              <AlertTriangle className="h-4 w-4 flex-shrink-0" style={{ color: '#C62828' }} />
              <span style={{ fontSize: 12, color: '#C62828' }}>{isBlocked ? "You have blocked this user. Unblock to send messages." : "You cannot send messages to this user."}</span>
            </div>
          )}
          
          {/* Selected-file preview banner */}
          {selectedFile && (
            <div className="mx-3 mb-2 flex items-center gap-3 rounded-lg border bg-card p-2 shadow-sm">
              {previewUrl ? (
                <img src={previewUrl} alt="preview" className="h-14 w-14 rounded object-cover" />
              ) : selectedFile.type.startsWith("video/") ? (
                <div className="flex h-14 w-14 items-center justify-center rounded bg-muted"><Video className="h-6 w-6 text-muted-foreground" /></div>
              ) : (
                <div className="flex h-14 w-14 items-center justify-center rounded bg-muted"><FileText className="h-6 w-6 text-muted-foreground" /></div>
              )}
              <div className="flex-1 min-w-0">
                <p className="truncate text-sm font-medium">{selectedFile.name}</p>
                <p className="text-[11px] text-muted-foreground">{(selectedFile.size / 1024).toFixed(0)} KB</p>
              </div>
              <Button type="button" variant="ghost" size="icon" className="h-8 w-8" onClick={cancelSelectedFile} disabled={isSending}>
                <X className="h-4 w-4" />
              </Button>
              <Button
                type="button"
                size="icon"
                className="h-9 w-9 rounded-full bg-primary hover:bg-primary/90"
                onClick={handleSendWithAttachment}
                disabled={isSending}
              >
                {isSending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
              </Button>
            </div>
          )}

          {/* Hidden file inputs */}
          <input ref={imageInputRef} type="file" accept="image/*,video/*" className="hidden" onChange={handleImageSelect} />
          <input ref={fileInputRef} type="file" accept=".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.zip,.rar,.csv" className="hidden" onChange={handleFileSelect} />

          {/* WhatsApp-style Chat Input with attachments + voice */}
          <div className="flex items-end gap-1 px-2 pb-2">
            <Popover open={isAttachmentOpen} onOpenChange={setIsAttachmentOpen}>
              <PopoverTrigger asChild>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  className="h-11 w-11 shrink-0 rounded-full text-muted-foreground"
                  disabled={isBlocked || isBlockedByPartner}
                  aria-label="Attach"
                >
                  <Paperclip className="h-5 w-5" />
                </Button>
              </PopoverTrigger>
              <PopoverContent side="top" align="start" className="w-48 p-1 z-[100]">
                <div className="flex flex-col gap-0.5">
                  <Button variant="ghost" size="sm" className="justify-start" onClick={() => { setIsAttachmentOpen(false); imageInputRef.current?.click(); }}>
                    <Image className="mr-2 h-4 w-4 text-blue-500" /> Photo / Video
                  </Button>
                  <Button variant="ghost" size="sm" className="justify-start" onClick={openCamera}>
                    <Camera className="mr-2 h-4 w-4 text-rose-500" /> Camera
                  </Button>
                  <Button variant="ghost" size="sm" className="justify-start" onClick={() => { setIsAttachmentOpen(false); fileInputRef.current?.click(); }}>
                    <FileText className="mr-2 h-4 w-4 text-orange-500" /> Document
                  </Button>
                </div>
              </PopoverContent>
            </Popover>

            <div className="flex-1">
              <Input
                value={newMessage}
                onChange={(e) => { 
                  setNewMessage(e.target.value); 
                  sendTyping(e.target.value.trim().length > 0); 
                }}
                onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); handleSendMessage(newMessage); } }}
                placeholder="Type a message..."
                disabled={isBlocked || isBlockedByPartner || isUploading}
                dir="auto"
                className="h-11"
              />
            </div>

            {newMessage.trim() ? (
              <Button size="icon" className="h-11 w-11 shrink-0 rounded-full bg-primary" onClick={() => handleSendMessage(newMessage)} disabled={!newMessage.trim()}>
                <Send className="h-5 w-5 text-primary-foreground" />
              </Button>
            ) : (
              <VoiceRecorder
                chatId={activeChatId || chatId.current}
                currentUserId={currentUserId}
                receiverId={chatPartner?.userId || ""}
                disabled={isBlocked || isBlockedByPartner || isUploading || !currentUserId || !(activeChatId || chatId.current)}
                onVoiceSent={(row) => {
                  if (!row) return;
                  setMessages((prev) => {
                    if (prev.some((m) => m.id === row.id)) return prev;
                    return [...prev, {
                      id: row.id,
                      senderId: row.sender_id,
                      message: row.message,
                      isRead: false,
                      createdAt: row.created_at,
                    }];
                  });
                }}
                onError={(m) => toast({ title: "Voice failed", description: m, variant: "destructive" })}
              />
            )}
          </div>
        </div>

        {/* Camera modal for selfie capture */}
        {isCameraOpen && (
          <div className="fixed inset-0 z-[200] flex flex-col items-center justify-center bg-black/90">
            <video ref={videoRef} autoPlay playsInline muted className="max-h-[70vh] w-full max-w-md rounded-lg object-cover" />
            <canvas ref={canvasRef} className="hidden" />
            <div className="mt-4 flex gap-3">
              <Button variant="secondary" onClick={closeCamera}>Cancel</Button>
              <Button onClick={captureSelfie} className="bg-primary"><Camera className="mr-2 h-4 w-4" /> Capture</Button>
            </div>
          </div>
        )}
      </footer>
    </div>
  );
};

// Export as default for router
export default ChatScreen;
