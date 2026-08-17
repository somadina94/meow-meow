import { classifyError, ERROR_MESSAGES } from "@/lib/errors";
import { moderateMessage } from '@/lib/content-moderation';
import { useState, useEffect, useRef, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";
import {
  Send,
  X,
  Maximize2,
  Clock,
  IndianRupee,
  Loader2,
  ChevronDown,
  ChevronUp,
  TrendingUp,
  Wallet,
  AlertTriangle,
  MoreHorizontal
} from "lucide-react";
import { ChatRelationshipActions } from "@/components/ChatRelationshipActions";
import { SendGiftButton } from "@/components/SendGiftButton";
import { useBlockCheck } from "@/hooks/useBlockCheck";
import { billChatMinute, billFinalPartialMinute } from "@/services/billing.service";
import { translateForViewer, languagesMatch } from "@/lib/translation-service";
import { isTranslatableChatText } from "@/lib/chat-attachments";

const IDLE_PAUSE_MS = 2 * 60 * 1000; // 2 minutes mutual idle → pause billing (chat stays open)
const IDLE_WARNING_MS = 1 * 60 * 1000; // 1 minute → show warning
const MUTUAL_REPLY_WINDOW_MS = 2 * 60 * 1000; // both must reply within 2 min for billing to be active

interface Message {
  id: string;
  senderId: string;
  message: string;
  translatedMessage?: string;
  englishText?: string;
  isTranslated?: boolean;
  isTranslating?: boolean;
  createdAt: string;
}

interface MiniChatWindowProps {
  chatId: string;
  sessionId: string;
  partnerId: string;
  partnerName: string;
  partnerPhoto: string | null;
  partnerLanguage: string;
  isPartnerOnline: boolean;
  currentUserId: string;
  currentUserLanguage: string;
  currentUserName?: string;
  userGender: "male" | "female";
  ratePerMinute: number;
  onClose: () => void;
  windowWidthClass?: string;
}

const MiniChatWindow = ({
  chatId,
  sessionId,
  partnerId,
  partnerName,
  partnerPhoto,
  partnerLanguage,
  isPartnerOnline,
  currentUserId,
  currentUserLanguage,
  currentUserName,
  userGender,
  ratePerMinute,
  onClose,
  windowWidthClass = "w-72"
}: MiniChatWindowProps) => {
  const navigate = useNavigate();
  const { toast } = useToast();
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState("");
  const [isSending, setIsSending] = useState(false);
  const [isMinimized, setIsMinimized] = useState(false);
  const [areButtonsExpanded, setAreButtonsExpanded] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [billingStarted, setBillingStarted] = useState(false);
  const [lastActivityTime, setLastActivityTime] = useState<number>(Date.now());
  const [totalEarned, setTotalEarned] = useState(0);
  const [walletBalance, setWalletBalance] = useState(0);
  const [todayEarnings, setTodayEarnings] = useState(0);
  const [earningRate, setEarningRate] = useState(2);
  const [inactiveWarning, setInactiveWarning] = useState<string | null>(null);
  const [sessionStarted, setSessionStarted] = useState(false);
  
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const timerRef = useRef<NodeJS.Timeout | null>(null);
  const heartbeatRef = useRef<NodeJS.Timeout | null>(null);
  const inactivityRef = useRef<NodeJS.Timeout | null>(null);
  const logoutTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const billingPauseTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  
  const sessionStartedRef = useRef(false);
  const billingStartedRef = useRef(false);
  const tempToRealIdRef = useRef<Map<string, string>>(new Map());
  
  const [isBillingPaused, setIsBillingPaused] = useState(false);
  const [lastUserMessageTime, setLastUserMessageTime] = useState<number>(Date.now());
  const [lastPartnerMessageTime, setLastPartnerMessageTime] = useState<number>(Date.now());

  // Derive canonical man/woman IDs for billing RPC (used by idle effect + startBilling)
  const manId = userGender === "male" ? currentUserId : partnerId;
  const womanId = userGender === "female" ? currentUserId : partnerId;
  
  // Free chat tracking for women chatting with no-balance men
  const [isFreeChatMode, setIsFreeChatMode] = useState(false);
  const [freeChatRemainingSeconds, setFreeChatRemainingSeconds] = useState(300);
  const freeChatTimerRef = useRef<NodeJS.Timeout | null>(null);
  const freeChatElapsedRef = useRef(0);

  const { isBlocked, isBlockedByThem } = useBlockCheck(currentUserId, partnerId);

  const blockMountedRef = useRef(false);
  useEffect(() => {
    if (!blockMountedRef.current) {
      blockMountedRef.current = true;
      return;
    }
    if (isBlocked) {
      toast({
        title: "Chat Ended",
        description: isBlockedByThem 
          ? "This user has blocked you" 
          : "You have blocked this user",
        variant: "destructive"
      });
      handleClose();
    }
  }, [isBlocked]);

  // Placeholder: Type a message...
  const translatedPlaceholder = "Type a message...";

  useEffect(() => {
    const loadInitialData = async () => {
      try {
        const { data: pricing } = await supabase
          .from("chat_pricing")
          .select("rate_per_minute, women_earning_rate")
          .eq("is_active", true)
          .maybeSingle();
        
        if (pricing) {
          setEarningRate(pricing.women_earning_rate || ratePerMinute * 0.5);
        }

        if (userGender === "male") {
          // Canonical SoT RPC instead of stale wallets.balance
          const { data: walletRpc } = await supabase.rpc("get_men_wallet_balance", { p_user_id: currentUserId });
          const balance = Number((walletRpc as Record<string, number> | null)?.balance) || 0;
          setWalletBalance(balance);
        } else {
          const today = new Date().toISOString().split("T")[0];
          // Earnings come from wallet_transactions (canonical) — credits are positive amounts
          const { data: earnings } = await supabase
            .from("wallet_transactions")
            .select("amount")
            .eq("user_id", currentUserId)
            .gt("amount", 0)
            .gte("created_at", `${today}T00:00:00`);
          
          const total = earnings?.reduce((acc, e) => acc + Number(e.amount), 0) || 0;
          setTodayEarnings(total);
        }

        // Check if this is a free chat (woman chatting with no-balance man)
        if (userGender === "female") {
          // Canonical SoT RPC for partner (male) balance
          const { data: partnerWalletRpc } = await supabase.rpc("get_men_wallet_balance", { p_user_id: partnerId });
          const partnerBalance = Number((partnerWalletRpc as Record<string, number> | null)?.balance) || 0;
          if (partnerBalance <= 0) {
            // Check free chat status
            const { data: freeChatStatus } = await supabase.rpc("check_free_chat_status", {
              p_woman_id: currentUserId,
              p_man_id: partnerId,
            });
            
            if (freeChatStatus?.blocked) {
              toast({
                title: "Free Chat Expired",
                description: "You've used your 5-minute free chat with this user. Ask them to recharge!",
                variant: "destructive",
              });
              onClose();
              return;
            }
            
            setIsFreeChatMode(true);
            setFreeChatRemainingSeconds(freeChatStatus?.remaining_seconds ?? 300);
            freeChatElapsedRef.current = freeChatStatus?.seconds_used ?? 0;
          }
        }

        if (!sessionStartedRef.current) {
          sessionStartedRef.current = true;
        }
      } catch (error) {
        console.error("Error loading initial data:", error);
        toast({ title: "Chat unavailable", description: ERROR_MESSAGES.chat.loadFailed, variant: "destructive" });
      }
    };

    loadInitialData();
  }, [currentUserId, userGender, ratePerMinute, partnerId]);

  useEffect(() => {
    loadMessages();
    const unsubscribe = subscribeToMessages();

    // Subscribe to session status changes - auto-close when partner ends chat
    const sessionChannel = supabase
      .channel(`session-status-mini-${sessionId}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'active_chat_sessions',
          filter: `id=eq.${sessionId}`
        },
        (payload: any) => {
          const session = payload.new;
          if (session.status === 'ended') {
            let message = "Chat session ended";
            if (session.end_reason === 'user_closed' || session.end_reason === 'user_ended' || session.end_reason === 'man_closed' || session.end_reason === 'woman_closed') {
              message = `${partnerName} ended the chat`;
            } else if (session.end_reason === 'inactivity_timeout') {
              message = "Chat ended due to inactivity";
            } else if (session.end_reason === 'insufficient_balance') {
              message = "Chat ended - insufficient balance";
            } else if (session.end_reason === 'user_blocked') {
              message = "Chat ended - user blocked";
            } else if (session.end_reason === 'auto_timeout') {
              message = "Chat request expired - no response";
            }
            toast({
              title: "Chat Disconnected",
              description: message + ". You are now available for new chats.",
            });
            onClose();
          }
        }
      )
      .subscribe();

    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
      if (heartbeatRef.current) clearInterval(heartbeatRef.current);
      if (inactivityRef.current) clearTimeout(inactivityRef.current);
      if (logoutTimeoutRef.current) clearTimeout(logoutTimeoutRef.current);
      if (billingPauseTimeoutRef.current) clearTimeout(billingPauseTimeoutRef.current);
      unsubscribe?.();
      supabase.removeChannel(sessionChannel);
    };
  }, [chatId, sessionId]);

  useEffect(() => {
    if (!isMinimized) {
      messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [messages, isMinimized]);

  useEffect(() => {
    const hasSentMessage = messages.some(m => m.senderId === currentUserId);
    const hasReceivedMessage = messages.some(m => m.senderId !== currentUserId);
    if (hasSentMessage && hasReceivedMessage && !billingStartedRef.current) {
      billingStartedRef.current = true;
      setBillingStarted(true);
      setLastActivityTime(Date.now());
      startBilling();
    }
  }, [messages, currentUserId]);

  useEffect(() => {
    if (messages.length > 0) {
      const lastMsg = messages[messages.length - 1];
      if (lastMsg.senderId === currentUserId) {
        setLastUserMessageTime(Date.now());
      } else {
        setLastPartnerMessageTime(Date.now());
      }
    }
  }, [messages, currentUserId]);

  // CHT-F-005 FIX: Reset idle timer on incoming partner messages too
  useEffect(() => {
    if (messages.length > 0) {
      const lastMsg = messages[messages.length - 1];
      if (lastMsg.senderId !== currentUserId) {
        // Partner sent a message — reset activity timer
        setLastActivityTime(Date.now());
      }
    }
  }, [messages, currentUserId]);

  // Mutual-idle billing PAUSE: if BOTH sides have not sent a message for 2 min, stop billing.
  // Chat session stays open. Billing auto-resumes the moment both sides have replied within 2 min.
  useEffect(() => {
    if (!billingStartedRef.current) return;

    const tick = setInterval(async () => {
      const now = Date.now();
      const userIdleMs = now - lastUserMessageTime;
      const partnerIdleMs = now - lastPartnerMessageTime;
      const bothIdleMs = Math.min(userIdleMs, partnerIdleMs);
      const replyGapMs = Math.abs(lastUserMessageTime - lastPartnerMessageTime);
      const mutualReplyActive = replyGapMs <= MUTUAL_REPLY_WINDOW_MS;

      // Warning band
      if (bothIdleMs >= IDLE_WARNING_MS && bothIdleMs < IDLE_PAUSE_MS) {
        const remainingSec = Math.ceil((IDLE_PAUSE_MS - bothIdleMs) / 1000);
        setInactiveWarning(`Billing pauses in ${remainingSec}s — reply to keep it active`);
      } else {
        setInactiveWarning(null);
      }

      // PAUSE: both idle ≥ 2 min and billing currently running
      if (bothIdleMs >= IDLE_PAUSE_MS && heartbeatRef.current) {
        if (timerRef.current) { clearInterval(timerRef.current); timerRef.current = null; }
        if (heartbeatRef.current) { clearInterval(heartbeatRef.current); heartbeatRef.current = null; }

        // Settle: round UP any leftover seconds to a full chargeable minute.
        if (billingStartTimeRef.current > 0) {
          const elapsedSec = Math.floor((Date.now() - billingStartTimeRef.current) / 1000);
          if (elapsedSec >= 1) {
            try {
              await billFinalPartialMinute(sessionId || chatId, "chat", elapsedSec, manId, womanId);
            } catch (e) { console.error("Pause partial billing error:", e); }
          }
        }
        billingStartTimeRef.current = 0;
        setIsBillingPaused(true);
        toast({
          title: "Billing paused",
          description: "Both of you went quiet for 2 min. Send a message to resume billing.",
        });
      }

      // RESUME: mutual reply within 2 min, both recently active, and billing currently paused
      if (mutualReplyActive && bothIdleMs < IDLE_PAUSE_MS && !heartbeatRef.current) {
        setIsBillingPaused(false);
        startBilling();
      }
    }, 1000);

    return () => clearInterval(tick);
  }, [lastUserMessageTime, lastPartnerMessageTime, billingStarted, sessionId, chatId, manId, womanId]);


  // Free chat timer: 5-min countdown for women chatting with no-balance men
  useEffect(() => {
    if (!isFreeChatMode || !billingStarted) return;
    
    freeChatTimerRef.current = setInterval(async () => {
      freeChatElapsedRef.current += 10; // update every 10 seconds
      const remaining = Math.max(300 - freeChatElapsedRef.current, 0);
      setFreeChatRemainingSeconds(remaining);
      
      // Persist to DB every 10 seconds
      try {
        const { data } = await supabase.rpc("update_free_chat_usage", {
          p_woman_id: currentUserId,
          p_man_id: partnerId,
          p_seconds: 10,
        });
        
        if (data?.blocked) {
          // 5 minutes up — auto-close and send recharge message
          if (freeChatTimerRef.current) clearInterval(freeChatTimerRef.current);
          
          await supabase.from("chat_messages").insert({
            chat_id: chatId,
            sender_id: currentUserId,
            receiver_id: partnerId,
            message: "⏰ Free chat time is over! Please recharge your wallet to continue chatting. 💳",
          });
          
          toast({
            title: "Free Chat Ended",
            description: "5-minute free chat with this user has ended. They need to recharge to chat again.",
          });
          
          try {
            await supabase
              .from("active_chat_sessions")
              .update({ status: "ended", ended_at: new Date().toISOString(), end_reason: "free_chat_expired" })
              .eq("id", sessionId);
          } catch {}
          
          onClose();
        }
      } catch (err) {
        console.error("[FreeChat] Error updating usage:", err);
      }
    }, 10000); // every 10 seconds
    
    return () => {
      if (freeChatTimerRef.current) clearInterval(freeChatTimerRef.current);
    };
  }, [isFreeChatMode, billingStarted, currentUserId, partnerId, chatId, sessionId, onClose]);

  // Translate history messages in background using live Lingva translation
          } catch {
            return null;
          }
        })
      );

      setMessages(prev => prev.map(m => {
        const translation = results
          .filter((r): r is PromiseFulfilledResult<any> => r.status === 'fulfilled')
          .map(r => r.value)
          .find(r => r && r.id === m.id);
        if (translation) {
          return { ...m, ...translation };
        }
        return m;
      }));
    }
  }, []);


  const loadMessages = async () => {
    const { data } = await supabase
      .from("chat_messages")
      .select("*")
      .eq("chat_id", chatId)
      .order("created_at", { ascending: true })
      .limit(50);

    if (data) {
      const formattedMessages: Message[] = data.map((m) => ({
        id: m.id,
        senderId: m.sender_id,
        message: m.message,
        createdAt: m.created_at
      }));
      setMessages(formattedMessages);

      // Always translate history messages for native display + English subtitles
      const langToUse = currentUserLanguage || 'English';
  };

  const subscribeToMessages = () => {
    const channel = supabase
      .channel(`mini-chat-${chatId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'chat_messages',
          filter: `chat_id=eq.${chatId}`
        },
        async (payload: any) => {
          const newMsg = payload.new;
          const isPartnerMessage = newMsg.sender_id !== currentUserId;
          
          setMessages(prev => {
            const existingRealIndex = prev.findIndex(m => m.id === newMsg.id);
            if (existingRealIndex >= 0) return prev;
            
            // For own messages, find and replace temp message, preserving translation
            if (newMsg.sender_id === currentUserId) {
              const tempIdx = prev.findIndex(m =>
                m.id.startsWith('temp-') && m.senderId === newMsg.sender_id &&
                Math.abs(new Date(m.createdAt).getTime() - new Date(newMsg.created_at).getTime()) < 5000
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
                  createdAt: newMsg.created_at
                };
                return updated;
              }
            }
            
            const filtered = prev.filter(m => 
              !(m.id.startsWith('temp-') && m.senderId === newMsg.sender_id && 
                Math.abs(new Date(m.createdAt).getTime() - new Date(newMsg.created_at).getTime()) < 5000)
            );
            
            return [...filtered, {
              id: newMsg.id,
              senderId: newMsg.sender_id,
              message: newMsg.message,
              createdAt: newMsg.created_at
            }];
          });

          if (isPartnerMessage && isTranslatableChatText(newMsg.message) && !languagesMatch(currentUserLanguage, partnerLanguage)) {
            const langToUse = currentUserLanguage || "English";
            void translateForViewer(newMsg.message, langToUse, partnerLanguage).then((result) => {
              setMessages((prev) => prev.map((m) =>
                m.id === newMsg.id
                  ? {
                      ...m,
                      translatedMessage: result.nativeText,
                      englishText: result.englishText,
                      isTranslated: result.nativeText !== newMsg.message,
                      isTranslating: false,
                    }
                  : m
              ));
            }).catch(() => {});
          }

          if (isMinimized && isPartnerMessage) {
            setUnreadCount(prev => prev + 1);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  };

  const billingStartTimeRef = useRef<number>(0);
  const billedMinutesRef = useRef<number>(0);

  // (manId/womanId moved above near top of component)


  const startBilling = () => {
    // Clear any existing intervals to prevent orphaned timers on resume
    if (timerRef.current) { clearInterval(timerRef.current); timerRef.current = null; }
    if (heartbeatRef.current) { clearInterval(heartbeatRef.current); heartbeatRef.current = null; }

    billingStartTimeRef.current = Date.now();
    billedMinutesRef.current = 0;

    timerRef.current = setInterval(() => {
      setElapsedSeconds(prev => prev + 1);
    }, 1000);

    // Per-minute heartbeat: keeps server activity AND bills 1 minute via canonical RPC
    heartbeatRef.current = setInterval(async () => {
      try {
        // Server activity ping (keeps session alive, partner online tracking)
        supabase.functions.invoke("chat-manager", {
          body: { action: "heartbeat", chat_id: chatId }
        }).catch((e) => console.error("Heartbeat error:", e));

        // Canonical billing — 1 full minute per tick, idempotent on minute_idx
        const minuteIdx = billedMinutesRef.current;
        const r = await billChatMinute(sessionId || chatId, 1.0, manId, womanId, minuteIdx);
        if (r.success && !r.duplicate_skipped) {
          billedMinutesRef.current = minuteIdx + 1;
          if (userGender === "female") {
            setTotalEarned(prev => prev + (r.earned ?? 0));
          } else {
            setWalletBalance(prev => Math.max(0, prev - (r.charged ?? 0)));
          }
        } else if (r.error?.includes("Insufficient balance")) {
          toast({
            title: "Chat ended",
            description: "Insufficient balance to continue.",
            variant: "destructive",
          });
          onClose();
        }
      } catch (error) {
        console.error("Billing tick error:", error);
      }
    }, 60000);
  };

  const MAX_MESSAGE_LENGTH = 2000;

  const sendMessage = async () => {
    if (!newMessage.trim() || isSending) return;
    setIsSending(true); // CHT-03 FIX: prevent double-send

    const messageText = newMessage.trim();
    
    if (messageText.length > MAX_MESSAGE_LENGTH) {
      toast({
        title: "Message too long",
        description: `Messages must be under ${MAX_MESSAGE_LENGTH} characters`,
        variant: "destructive"
      });
      setIsSending(false);
      return;
    }

    // Content moderation - block phone numbers, emails, social media
    const moderationResult = moderateMessage(messageText);
    if (moderationResult.isBlocked) {
      toast({
        title: "Message Blocked",
        description: moderationResult.reason,
        variant: "destructive"
      });
      setIsSending(false);
      return;
    }

    if (messageText.length === 0) {
      setIsSending(false);
      return;
    }

    setNewMessage("");
    setLastActivityTime(Date.now());

    const tempId = `temp-${Date.now()}`;
    const optimisticMessage: Message = {
      id: tempId,
      senderId: currentUserId,
      message: messageText,
      isTranslating: false,
      createdAt: new Date().toISOString()
    };
    setMessages(prev => [...prev, optimisticMessage]);

    try {
      const { error } = await supabase
        .from("chat_messages")
        .insert({
          chat_id: chatId,
          sender_id: currentUserId,
          receiver_id: partnerId,
          message: messageText
        });

      if (error) {
        console.error("Error sending message:", error);
        setMessages(prev => prev.filter(m => m.id !== tempId));
        toast({
          title: "Error",
          description: "Failed to send message",
          variant: "destructive"
        });
      }
    } catch (error) {
      console.error("Error sending message:", error);
      setMessages(prev => prev.filter(m => m.id !== tempId));
      toast({
        title: "Error",
        description: "Failed to send message",
        variant: "destructive"
      });
    } finally {
      setIsSending(false); // CHT-03 FIX: always reset
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const toggleMinimize = () => {
    setIsMinimized(!isMinimized);
    if (isMinimized) {
      setUnreadCount(0);
    }
  };

  const openFullChat = () => {
    setIsMinimized(false);
  };

  const handleClose = async () => {
    // Stop billing timers immediately
    if (timerRef.current) { clearInterval(timerRef.current); timerRef.current = null; }
    if (heartbeatRef.current) { clearInterval(heartbeatRef.current); heartbeatRef.current = null; }

    // Final settlement: round UP any leftover seconds to a full chargeable minute.
    // Ensures sub-1-minute chats and partial-minute closes (e.g. 1m12s) are billed.
    if (billingStartedRef.current && billingStartTimeRef.current > 0) {
      const elapsedSec = Math.floor((Date.now() - billingStartTimeRef.current) / 1000);
      if (elapsedSec >= 1) {
        try {
          await billFinalPartialMinute(sessionId || chatId, "chat", elapsedSec, manId, womanId);
        } catch (e) {
          console.error("Final partial billing error:", e);
        }
      }
    }

    
    try {
      // Call chat-manager end_chat for proper final billing and cleanup
      await supabase.functions.invoke("chat-manager", {
        body: { 
          action: "end_chat", 
          chat_id: chatId, 
          end_reason: userGender === "male" ? "man_closed" : "woman_closed",
          user_id: currentUserId
        }
      });
    } catch (error) {
      console.error("Error closing chat via chat-manager:", error);
      toast({ title: "Chat not closed", description: "Unable to close this chat session properly.", variant: "destructive" });
      // Fallback: directly update session
      try {
        await supabase
          .from("active_chat_sessions")
          .update({
            status: "ended",
            ended_at: new Date().toISOString(),
            end_reason: userGender === "male" ? "man_closed" : "woman_closed"
          })
          .eq("id", sessionId);
      } catch (fallbackError) {
        console.error("Fallback close also failed:", fallbackError);
      }
    }
    onClose();
  };

  // Format as MM:SS — 60 seconds = 1 minute
  const formatTime = (seconds: number) => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const estimatedCost = billingStarted ? (elapsedSeconds / 60) * ratePerMinute : 0;
  const estimatedEarning = billingStarted ? totalEarned + ((elapsedSeconds / 60) * earningRate) : 0;

  return (
    <Card 
      className={cn(
        "flex flex-col shadow-xl border-2 transition-all duration-200",
        isMinimized ? "w-56 h-12" : `${windowWidthClass} h-80`,
        isPartnerOnline ? "border-primary/30" : "border-muted"
      )}
    >
      {inactiveWarning && (
        <div className="flex items-center gap-1 px-2 py-0.5 bg-destructive/10 text-destructive text-[9px]">
          <AlertTriangle className="h-2.5 w-2.5" />
          <span>{inactiveWarning}</span>
        </div>
      )}
      
      <div 
        className="flex items-center justify-between p-2 bg-gradient-to-r from-primary/10 to-transparent border-b cursor-pointer"
        onClick={toggleMinimize}
      >
        <div className="flex items-center gap-2 flex-1 min-w-0">
          <div className="relative">
            <Avatar className="h-7 w-7">
              <AvatarImage src={partnerPhoto || undefined} />
              <AvatarFallback className="text-xs bg-primary/20">
                {partnerName.charAt(0)}
              </AvatarFallback>
            </Avatar>
            <div className={cn(
              "absolute -bottom-0.5 -right-0.5 w-2 h-2 rounded-full border border-background",
              isPartnerOnline ? "bg-green-500" : "bg-muted-foreground"
            )} />
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-1">
              <p className="text-xs font-medium truncate">{partnerName}</p>
              {userGender === "male" && walletBalance > 0 && (
                <Badge variant="outline" className="h-3.5 text-[8px] px-1 gap-0.5">
                  <Wallet className="h-2 w-2" />₹{walletBalance.toFixed(2)}
                </Badge>
              )}
              {userGender === "female" && todayEarnings > 0 && (
                <Badge variant="outline" className="h-3.5 text-[8px] px-1 gap-0.5 border-green-500/30 text-green-600">
                  <TrendingUp className="h-2 w-2" />₹{todayEarnings.toFixed(2)}
                </Badge>
              )}
            </div>
            {isFreeChatMode && (
              <Badge variant="outline" className="text-[9px] h-4 px-1 border-amber-400 text-amber-600">
                ⏱ Free {Math.ceil(freeChatRemainingSeconds / 60)} min
              </Badge>
            )}
            {billingStarted && (
              <div className="flex items-center gap-1 text-[10px]">
                <Clock className="h-2 w-2 text-muted-foreground" />
                <span className="text-muted-foreground">{formatTime(elapsedSeconds)}</span>
              </div>
            )}
          </div>
          {unreadCount > 0 && isMinimized && (
            <Badge className="h-4 min-w-[16px] text-[9px] px-1 bg-primary">
              {unreadCount}
            </Badge>
          )}
        </div>
        <div className="flex items-center gap-0.5">
          <Button
            variant="ghost"
            size="icon"
            className="h-5 w-5"
            onClick={(e) => { e.stopPropagation(); setAreButtonsExpanded(!areButtonsExpanded); }}
            title={areButtonsExpanded ? "Hide actions" : "Show actions"}
          >
            <MoreHorizontal className="h-2.5 w-2.5" />
          </Button>
          
          {areButtonsExpanded && (
            <>
              {userGender === 'male' && (
                <SendGiftButton
                  senderUserId={currentUserId}
                  recipientUserId={partnerId}
                  context="chat"
                />
              )}
              <ChatRelationshipActions
                currentUserId={currentUserId}
                targetUserId={partnerId}
                targetUserName={partnerName}
                onBlock={handleClose}
                className="h-5 w-5"
              />
              <Button
                variant="ghost"
                size="icon"
                className="h-5 w-5"
                onClick={(e) => { e.stopPropagation(); openFullChat(); }}
                title="Open full chat"
              >
                <Maximize2 className="h-2.5 w-2.5" />
              </Button>
            </>
          )}
          
          <Button
            variant="ghost"
            size="icon"
            className="h-5 w-5"
            onClick={(e) => { e.stopPropagation(); toggleMinimize(); }}
          >
            {isMinimized ? <ChevronUp className="h-2.5 w-2.5" /> : <ChevronDown className="h-2.5 w-2.5" />}
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="h-5 w-5 hover:bg-destructive/20 hover:text-destructive"
            onClick={(e) => {
              e.stopPropagation();
              e.preventDefault();
              handleClose();
            }}
            onPointerDown={(e) => e.stopPropagation()}
            onMouseDown={(e) => e.stopPropagation()}
            onTouchStart={(e) => e.stopPropagation()}
          >
            <X className="h-2.5 w-2.5" />
          </Button>
        </div>
      </div>

      {!isMinimized && (
        <>
          <ScrollArea className="flex-1 p-2">
            <div className="space-y-1.5">
              {messages.length === 0 && (
                <p className="text-center text-[10px] text-muted-foreground py-4">
                  Say hi to start!
                </p>
              )}
              {messages.map((msg) => {
                const isOwn = msg.senderId === currentUserId;
                const senderName = isOwn ? (currentUserName || "You") : partnerName;
                const senderLang = isOwn ? currentUserLanguage : partnerLanguage;
                return (
                  <div
                    key={msg.id}
                    className={cn(
                      "flex flex-col",
                      isOwn ? "items-end" : "items-start"
                    )}
                  >
                    {/* Sender/Receiver name with distinct colors */}
                    <span className={cn(
                      "text-[9px] font-semibold mb-0.5 px-1",
                      isOwn
                        ? "text-primary"
                        : "text-emerald-600 dark:text-emerald-400"
                    )}>
                      {senderName}
                      {senderLang && <span className="text-muted-foreground/60 font-normal"> • {senderLang}</span>}
                    </span>
                    <div
                      className={cn(
                        "max-w-[85%] px-2 py-1 rounded-xl text-[11px] shadow-sm border",
                        isOwn
                          ? "bg-primary/5 border-primary/20 rounded-br-sm"
                          : "bg-emerald-50 border-emerald-200 dark:bg-emerald-950/20 dark:border-emerald-800 rounded-bl-sm"
                      )}
                    >
                      {msg.isTranslating ? (
                        <>
                          <p className={cn(
                            "unicode-text",
                            isOwn
                              ? "text-primary dark:text-primary"
                              : "text-emerald-800 dark:text-emerald-200"
                          )} dir="auto">
                            {msg.message}
                          </p>
                          <div className="flex items-center gap-1 py-0.5">
                            <Loader2 className="h-3 w-3 animate-spin text-muted-foreground" />
                            <span className="text-muted-foreground text-[10px]">Translating...</span>
                          </div>
                        </>
                      ) : (
                        <>
                          <p className={cn(
                            "unicode-text",
                            isOwn
                              ? "text-primary dark:text-primary"
                              : "text-emerald-800 dark:text-emerald-200"
                          )} dir="auto">
                            {msg.message}
                          </p>
                          {!isOwn && msg.translatedMessage && msg.translatedMessage.toLowerCase() !== msg.message.toLowerCase() && (
                            <p className="text-[9px] text-muted-foreground/60 italic mt-0.5" dir="auto">
                              {msg.translatedMessage}
                            </p>
                          )}
                        </>
                      )}
                      <span className="text-[8px] text-muted-foreground/50 block mt-0.5">
                        {new Date(msg.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </span>
                    </div>
                  </div>
                );
              })}
              <div ref={messagesEndRef} />
            </div>
          </ScrollArea>

          <div className="p-1.5 border-t">
            <div className="flex items-center gap-1">
              <Input
                placeholder={translatedPlaceholder}
                value={newMessage}
                onChange={(e) => {
                  setNewMessage(e.target.value);
                  setLastActivityTime(Date.now());
                }}
                onKeyDown={handleKeyPress}
                dir="auto"
                spellCheck={true}
                autoComplete="off"
                autoCorrect="on"
                className="h-7 text-[11px] unicode-text"
              />
              <Button
                size="icon"
                className="h-7 w-7"
                onClick={sendMessage}
                disabled={!newMessage.trim() || isSending}
              >
                <Send className="h-3 w-3" />
              </Button>
            </div>
          </div>
        </>
      )}
    </Card>
  );
};

export default MiniChatWindow;
