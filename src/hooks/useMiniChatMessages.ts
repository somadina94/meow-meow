import { useState, useEffect, useRef, useCallback } from "react";
import { supabase } from "@/integrations/supabase/client";
import { isTranslatableChatText } from "@/lib/chat-attachments";
import { translateForViewer, isEnglishLanguage, languagesMatch } from "@/lib/translation-service";

interface Message {
  id: string;
  ownerId: string;
  message: string;
  createdAt: string;
  sendFailed?: boolean;
  deletedForEveryone?: boolean;
  isSystem?: boolean;
  translatedMessage?: string;
  englishText?: string;
}

interface UseMiniChatMessagesOptions {
  chatId: string;
  currentUserId: string;
  isMinimized: boolean;
  currentUserLanguage?: string;
  partnerLanguage?: string;
}

// CHT-H-01: markMessagesAsRead with retry logic
const markMessagesAsReadWithRetry = async (
  chatId: string,
  receiverId: string,
  maxRetries = 3
) => {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const { error } = await supabase
        .from("chat_messages")
        .update({ is_read: true })
        .eq("chat_id", chatId)
        .eq("receiver_id", receiverId)
        .eq("is_read", false);
      
      if (!error) return;
      console.warn(`[markMessagesAsRead] Attempt ${attempt + 1} failed:`, error.message);
    } catch (err) {
      console.warn(`[markMessagesAsRead] Attempt ${attempt + 1} exception:`, err);
    }
    if (attempt < maxRetries - 1) {
      await new Promise(r => setTimeout(r, 500 * Math.pow(2, attempt)));
    }
  }
  console.error("[markMessagesAsRead] All retries exhausted for chat:", chatId);
};

export const useMiniChatMessages = ({
  chatId,
  currentUserId,
  isMinimized,
  currentUserLanguage,
  partnerLanguage,
}: UseMiniChatMessagesOptions) => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [hasOlderMessages, setHasOlderMessages] = useState(false);
  const [isLoadingOlder, setIsLoadingOlder] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const seenIdsRef = useRef<Set<string>>(new Set());
  const viewerLangRef = useRef(currentUserLanguage || "English");
  const partnerLangRef = useRef(partnerLanguage || "English");

  useEffect(() => {
    viewerLangRef.current = currentUserLanguage || "English";
  }, [currentUserLanguage]);
  useEffect(() => {
    partnerLangRef.current = partnerLanguage || "English";
  }, [partnerLanguage]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data } = await supabase
        .from("profiles")
        .select("preferred_language, primary_language")
        .eq("user_id", currentUserId)
        .maybeSingle();
      const lang = data?.preferred_language || data?.primary_language;
      if (!cancelled && lang) viewerLangRef.current = lang;
    })();
    return () => { cancelled = true; };
  }, [currentUserId]);

  const applyTranslation = useCallback((messageId: string, text: string, senderId: string) => {
    if (senderId === currentUserId) return;
    if (!isTranslatableChatText(text)) return;
    const viewerLang = viewerLangRef.current || "English";
    const senderLang = partnerLangRef.current;
    if (languagesMatch(viewerLang, senderLang)) return;
    void translateForViewer(text, viewerLang, senderLang)
      .then((result) => {
        setMessages((prev) =>
          prev.map((m) =>
            m.id === messageId
              ? {
                  ...m,
                  translatedMessage: result.nativeText,
                }
              : m
          )
        );
      })
      .catch(() => {});
  }, [currentUserId]);

  // Effect 1: Load messages & subscribe to realtime inserts
  useEffect(() => {
    seenIdsRef.current.clear();

    const loadMessages = async () => {
      const { data: profile } = await supabase
        .from("profiles")
        .select("preferred_language, primary_language")
        .eq("user_id", currentUserId)
        .maybeSingle();
      const liveLang = profile?.preferred_language || profile?.primary_language;
      if (liveLang) viewerLangRef.current = liveLang;

      const { data } = await supabase
        .from("chat_messages")
        .select("*")
        .eq("chat_id", chatId)
        .order("created_at", { ascending: true })
        .limit(100);

      if (data) {
        // Filter out messages deleted for the current user
        const filtered = data.filter((m: any) => {
          if (m.deleted_for_everyone) return false;
          if (m.sender_id === currentUserId && m.deleted_for_sender) return false;
          if (m.receiver_id === currentUserId && m.deleted_for_receiver) return false;
          return true;
        });
        const msgs: Message[] = filtered.map((m) => {
          seenIdsRef.current.add(m.id);
          return {
            id: m.id,
            ownerId: m.sender_id,
            message: m.message,
            createdAt: m.created_at,
          };
        });
        setMessages(msgs);
        setHasOlderMessages(data.length >= 100);
        msgs.forEach((msg) => {
          if (!msg.isSystem) applyTranslation(msg.id, msg.message, msg.ownerId);
        });
      }

      markMessagesAsReadWithRetry(chatId, currentUserId);
    };

    loadMessages();

    const channel = supabase
      .channel(`draggable-chat-${chatId}-${currentUserId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "chat_messages", filter: `chat_id=eq.${chatId}` },
        async (payload) => {
          const m = payload.new as any;

          if (seenIdsRef.current.has(m.id)) return;
          seenIdsRef.current.add(m.id);

          const newMsg: Message = {
            id: m.id,
            ownerId: m.sender_id,
            message: m.message,
            createdAt: m.created_at,
          };

          setMessages((prev) => {
            const filtered = prev.filter(
              (msg) => !(msg.id.startsWith("temp-") && msg.ownerId === m.sender_id)
            );
            return [...filtered, newMsg];
          });

          applyTranslation(m.id, m.message, m.sender_id);

          if (m.sender_id !== currentUserId) {
            setUnreadCount((prev) => prev + (!isMinimized ? 0 : 1));
            if (!isMinimized) {
              markMessagesAsReadWithRetry(chatId, currentUserId);
            }
          }
        }
      )
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "chat_messages", filter: `chat_id=eq.${chatId}` },
        (payload) => {
          const m = payload.new as any;
          if (m.deleted_for_everyone) {
            setMessages(prev => prev.map(msg =>
              msg.id === m.id ? { ...msg, message: 'This message was deleted', deletedForEveryone: true } : msg
            ));
            return;
          }
          if (m.sender_id === currentUserId && m.deleted_for_sender) {
            setMessages(prev => prev.filter(msg => msg.id !== m.id));
            return;
          }
          if (m.receiver_id === currentUserId && m.deleted_for_receiver) {
            setMessages(prev => prev.filter(msg => msg.id !== m.id));
            return;
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [chatId, currentUserId, isMinimized, applyTranslation]);

  // Load older messages (pagination)
  const loadOlderMessages = useCallback(async () => {
    if (isLoadingOlder || messages.length === 0) return;
    setIsLoadingOlder(true);
    try {
      const oldestMessage = messages[0];
      const { data } = await supabase
        .from("chat_messages")
        .select("*")
        .eq("chat_id", chatId)
        .lt("created_at", oldestMessage.createdAt)
        .order("created_at", { ascending: false })
        .limit(50);

      if (data) {
        const olderMsgs: Message[] = data.map((m: any) => ({
          id: m.id,
          ownerId: m.sender_id,
          message: m.message,
          createdAt: m.created_at,
        })).reverse();
        setMessages((prev) => [...olderMsgs, ...prev]);
        setHasOlderMessages(data.length >= 50);
      }
    } catch (e) {
      console.error("Error loading older messages:", e);
    } finally {
      setIsLoadingOlder(false);
    }
  }, [chatId, messages, isLoadingOlder]);

  return { messages, setMessages, unreadCount, setUnreadCount, messagesEndRef, hasOlderMessages, isLoadingOlder, loadOlderMessages, addSeenId: (id: string) => seenIdsRef.current.add(id) };
};
