import { useState, useEffect, useCallback, useRef, useMemo } from "react";
import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
import { supabase } from "@/integrations/supabase/client";
import DraggableMiniChatWindow from "./DraggableMiniChatWindow";
import ParallelChatSettingsPanel from "./ParallelChatSettingsPanel";
import { useParallelChatSettings } from "@/hooks/useParallelChatSettings";
import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Settings2, MessageSquare } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";

interface ActiveChat {
  id: string;
  chatId: string;
  partnerId: string;
  partnerName: string;
  partnerPhoto: string | null;
  partnerLanguage: string;
  isPartnerOnline: boolean;
  ratePerMinute: number;
  earningRatePerMinute: number;
  startedAt: string;
  position: { x: number; y: number };
  zIndex: number;
}

interface EnhancedParallelChatsContainerProps {
  currentUserId: string;
  userGender: "male" | "female";
  currentUserLanguage?: string;
  currentUserName?: string;
}

const getInitialPosition = (index: number): { x: number; y: number } => {
  const baseX = 20;
  const baseY = 20;
  const offset = 30;
  return { x: baseX + (index * offset), y: baseY + (index * offset) };
};

const useDebounce = (callback: () => void, delay: number) => {
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);
  const callbackRef = useRef(callback);
  callbackRef.current = callback;

  return useCallback(() => {
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    timeoutRef.current = setTimeout(() => callbackRef.current(), delay);
  }, [delay]);
};

const EnhancedParallelChatsContainer = ({ 
  currentUserId, 
  userGender, 
  currentUserLanguage = "English",
  currentUserName
}: EnhancedParallelChatsContainerProps) => {
  const { toast } = useToast();
  const [activeChats, setActiveChats] = useState<ActiveChat[]>([]);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [focusedChatId, setFocusedChatId] = useState<string | null>(null);
  const acceptedSessionsRef = useRef<Set<string>>(new Set());
  const closedSessionsRef = useRef<Set<string>>(new Set());
  const closedChatIdsRef = useRef<Set<string>>(new Set());
  const existingPartnersRef = useRef<Set<string>>(new Set());
  const nextZIndexRef = useRef(50);
  const isLoadingRef = useRef(false);
  const lastLoadTimeRef = useRef(0);
  // Store previous positions/zIndex to avoid activeChats dependency in loadActiveChats
  const chatPositionsRef = useRef<Map<string, { position: { x: number; y: number }; zIndex: number }>>(new Map());
  
  const { maxParallelChats, setMaxParallelChats, isLoading: settingsLoading } = 
    useParallelChatSettings(currentUserId);

  // Chat is now async (WhatsApp-style) — no accept/reject for chats

  // Load active chats - NO dependency on activeChats (uses ref for positions)
  const loadActiveChats = useCallback(async (force = false) => {
    if (!currentUserId || isLoadingRef.current) return;
    
    const now = Date.now();
    if (!force && now - lastLoadTimeRef.current < 500) return;
    lastLoadTimeRef.current = now;
    isLoadingRef.current = true;

    try {
      const column = userGender === "male" ? "man_user_id" : "woman_user_id";
      const partnerColumn = userGender === "male" ? "woman_user_id" : "man_user_id";
      
      // Chat is async (WhatsApp-style) — all sessions are active immediately
      const statusFilter = ["active", "paused", "billing_paused"];
      
      const { data: sessions, error: sessionsError } = await supabase
        .from("active_chat_sessions")
        .select(`id, chat_id, ${partnerColumn}, rate_per_minute, created_at, started_at, updated_at, status`)
        .eq(column, currentUserId)
        .in("status", statusFilter)
        .order("created_at", { ascending: false })
        .limit(10);

      if (sessionsError || !sessions || sessions.length === 0) {
        setActiveChats([]);
        existingPartnersRef.current.clear();
        isLoadingRef.current = false;
        return;
      }

      const partnerIds = [...new Set(sessions.map(s => s[partnerColumn as keyof typeof s] as string))];

      const [pricingResult, profilesResult, statusesResult, messagesResult] = await Promise.all([
        supabase
          .from("chat_pricing")
          .select("rate_per_minute, women_earning_rate")
          .eq("is_active", true)
          .maybeSingle(),
        (async () => {
          const { fetchPublicProfiles } = await import("@/lib/profile-queries");
          return { data: await fetchPublicProfiles(partnerIds as string[]), error: null };
        })(),
        supabase
          .from("user_status")
          .select("user_id, is_online")
          .in("user_id", partnerIds),
        userGender === "female" 
          ? supabase
              .from("chat_messages")
              .select("chat_id, created_at")
              .in("chat_id", sessions.map(s => s.chat_id))
              .eq("sender_id", currentUserId)
              .limit(100)
          : Promise.resolve({ data: [] })
      ]);

      const pricing = pricingResult.data;
      const profiles = profilesResult.data || [];
      const statuses = statusesResult.data || [];
      const messages = messagesResult.data || [];

      const ratePerMinute = pricing?.rate_per_minute || 2;
      const earningRatePerMinute = pricing?.women_earning_rate || 2;

      const sessionStartTimes = new Map(
        sessions.map(s => [
          s.chat_id,
          (s as any).started_at || (s as any).updated_at || s.created_at,
        ])
      );
      const chatsWithUserMessages = new Set(
        messages
          .filter((m: any) => {
            const sessionStart = sessionStartTimes.get(m.chat_id);
            if (!sessionStart) return true;
            return new Date(m.created_at) >= new Date(sessionStart as string);
          })
          .map((m: any) => m.chat_id)
      );
      const profileMap = new Map((profiles as any[]).map(p => [p.user_id, p]));
      const statusMap = new Map((statuses as any[]).map(s => [s.user_id, s.is_online as boolean]));

      const partnerToSession = new Map<string, typeof sessions[0]>();
      
      for (const session of sessions) {
        const partnerId = session[partnerColumn as keyof typeof session] as string;
        
        // Skip sessions that the user explicitly closed in this browser session
        if (closedSessionsRef.current.has(session.id) || closedChatIdsRef.current.has(session.chat_id)) continue;
        
        // Chat is async — show all active sessions immediately for both genders
        
        const existing = partnerToSession.get(partnerId);
        if (!existing || new Date(session.created_at) > new Date(existing.created_at)) {
          partnerToSession.set(partnerId, session);
        }
      }
      
      existingPartnersRef.current = new Set(partnerToSession.keys());
      
      const chats: ActiveChat[] = Array.from(partnerToSession.entries()).map(([partnerId, session], index) => {
        const profile = profileMap.get(partnerId);
        // Use ref for position persistence instead of activeChats state
        const savedLayout = chatPositionsRef.current.get(partnerId);
        
        return {
          id: session.id,
          chatId: session.chat_id,
          partnerId,
          partnerName: profile?.full_name || "Anonymous",
          partnerPhoto: profile?.photo_url || null,
          partnerLanguage: profile?.primary_language || "Unknown",
          isPartnerOnline: statusMap.get(partnerId) || false,
          ratePerMinute: session.rate_per_minute || ratePerMinute,
          earningRatePerMinute,
          startedAt: session.created_at,
          position: savedLayout?.position || getInitialPosition(index),
          zIndex: savedLayout?.zIndex || nextZIndexRef.current++
        };
      });

      // Save positions to ref for next load
      for (const chat of chats) {
        chatPositionsRef.current.set(chat.partnerId, { position: chat.position, zIndex: chat.zIndex });
      }

      setActiveChats(chats);
    } catch (error) {
      console.error("[EnhancedParallelChats] Error loading chats:", error);
      toast({ title: "Chats unavailable", description: ERROR_MESSAGES.chat.loadFailed, variant: "destructive" });
    } finally {
      isLoadingRef.current = false;
    }
  }, [currentUserId, userGender]); // NO activeChats dependency - prevents infinite loops

  const debouncedLoadChats = useDebounce(loadActiveChats, 300);

  useEffect(() => {
    const handler = () => loadActiveChats(true);
    window.addEventListener('force-reload-chats', handler);
    return () => window.removeEventListener('force-reload-chats', handler);
  }, [loadActiveChats]);

  useEffect(() => {
    if (!currentUserId) return;
    
    loadActiveChats();

    const channelName = `chats-${currentUserId}`;
    const column = userGender === "male" ? "man_user_id" : "woman_user_id";

    const channel = supabase
      .channel(channelName)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'active_chat_sessions',
          filter: `${column}=eq.${currentUserId}`
        },
        (payload) => {
          // When a session is recycled back to pending, clear stale closed refs
          const session = payload.new as { id?: string; chat_id?: string; status?: string } | undefined;
          if (session?.status === 'pending') {
            if (session.id) closedSessionsRef.current.delete(session.id);
            if (session.chat_id) closedChatIdsRef.current.delete(session.chat_id);
          }
          debouncedLoadChats();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [currentUserId, userGender, loadActiveChats, debouncedLoadChats]);

  // Handle closing a chat
  const handleCloseChat = useCallback(async (chatId: string, sessionId?: string, silent = false) => {
    // CRITICAL: Track closed session/chatId IMMEDIATELY before any async work
    if (sessionId) closedSessionsRef.current.add(sessionId);
    closedChatIdsRef.current.add(chatId);
    acceptedSessionsRef.current.delete(sessionId || "");
    
    // Also remove from positions ref
    setActiveChats(prev => {
      const chat = prev.find(c => c.chatId === chatId);
      if (chat) {
        chatPositionsRef.current.delete(chat.partnerId);
        existingPartnersRef.current.delete(chat.partnerId);
      }
      return prev.filter(c => c.chatId !== chatId);
    });

    try {
      if (sessionId) {
        try {
          await supabase.functions.invoke("chat-manager", {
            body: {
              action: "end_chat",
              chat_id: chatId,
              end_reason: userGender === "male" ? "man_closed" : "woman_closed",
              user_id: currentUserId
            }
          });
        } catch (invokeError) {
          console.error("Error calling chat-manager:", invokeError);
          // Fallback: directly update session
          await supabase
            .from("active_chat_sessions")
            .update({
              status: "ended",
              ended_at: new Date().toISOString(),
              end_reason: userGender === "male" ? "man_closed" : "woman_closed"
            })
            .eq("id", sessionId);
        }
      }
      
      // Keep chatId in closed set for 30 seconds to prevent realtime reopening
      setTimeout(() => {
        closedChatIdsRef.current.delete(chatId);
        if (sessionId) closedSessionsRef.current.delete(sessionId);
      }, 30000);
      
      if (!silent) {
        loadActiveChats();
      }
    } catch (error) {
      console.error("Error closing chat:", error);
      toast({ title: "Chat not closed", description: "Unable to close this chat. Please refresh and try again.", variant: "destructive" });
    }
  }, [userGender, currentUserId, loadActiveChats]);

  const handleFocusChat = useCallback((chatId: string) => {
    setFocusedChatId(chatId);
    setActiveChats(prev => prev.map(chat => {
      if (chat.chatId === chatId) {
        const newZIndex = nextZIndexRef.current++;
        chatPositionsRef.current.set(chat.partnerId, { position: chat.position, zIndex: newZIndex });
        return { ...chat, zIndex: newZIndex };
      }
      return chat;
    }));
  }, []);

  const displayedChats = activeChats.slice(0, maxParallelChats);

  return (
    <>
      {/* Settings button */}
      <div className="fixed bottom-4 left-4 z-[100] flex items-center gap-2">
        {displayedChats.length > 0 && (
          <div className="flex items-center gap-1 px-2 py-1 bg-primary/10 rounded-full text-xs font-medium backdrop-blur-sm">
            <MessageSquare className="h-3 w-3 text-primary" />
            <span>{displayedChats.length}/{maxParallelChats}</span>
          </div>
        )}
        <Popover open={settingsOpen} onOpenChange={setSettingsOpen}>
          <PopoverTrigger asChild>
            <Button
              variant="outline"
              size="icon"
              className={cn(
                "h-10 w-10 rounded-full shadow-lg bg-background/95 backdrop-blur-sm",
                "hover:bg-primary/10 transition-all",
                activeChats.length > 0 && "border-primary"
              )}
            >
              <Settings2 className="h-4 w-4" />
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-80 p-0" align="start">
            <ParallelChatSettingsPanel
              currentValue={maxParallelChats}
              onSave={setMaxParallelChats}
              isLoading={settingsLoading}
            />
          </PopoverContent>
        </Popover>
      </div>

      {/* Chat is async (WhatsApp-style) — no incoming chat popups needed */}

      {/* Active chat windows */}
      <div className="fixed bottom-4 right-2 left-2 sm:left-auto sm:right-4 z-50 flex flex-row flex-wrap-reverse sm:flex-nowrap justify-end gap-2 sm:gap-3 items-end max-w-full overflow-x-auto">
        {displayedChats.map((chat) => (
          <DraggableMiniChatWindow
            key={chat.chatId}
            chatId={chat.chatId}
            sessionId={chat.id}
            partnerId={chat.partnerId}
            partnerName={chat.partnerName}
            partnerPhoto={chat.partnerPhoto}
            partnerLanguage={chat.partnerLanguage}
            isPartnerOnline={chat.isPartnerOnline}
            currentUserId={currentUserId}
            currentUserLanguage={currentUserLanguage}
            currentUserName={currentUserName}
            userGender={userGender}
            ratePerMinute={chat.ratePerMinute}
            earningRatePerMinute={chat.earningRatePerMinute}
            onClose={() => handleCloseChat(chat.chatId, chat.id)}
            initialPosition={{ x: 0, y: 0 }}
            zIndex={chat.zIndex}
            onFocus={() => handleFocusChat(chat.chatId)}
          />
        ))}
      </div>
    </>
  );
};

export default EnhancedParallelChatsContainer;
