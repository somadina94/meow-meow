import { useEffect, useRef, useState, useCallback } from "react";
import { supabase } from "@/integrations/supabase/client";

export type PartnerPresenceState =
  | "connecting"
  | "in_chat"        // Partner has THIS chat window open and focused/visible
  | "typing"         // Partner is typing in this chat
  | "online_away"    // Partner is online (app open) but not in this chat tab
  | "offline"        // Partner is not online
  | "left_chat";     // Partner explicitly closed this chat window

interface UseChatPresenceOptions {
  chatId: string;
  currentUserId: string;
  partnerId: string;
  /** Whether THIS chat window is currently visible/focused for the local user */
  isWindowActive: boolean;
}

interface PresenceMeta {
  user_id: string;
  in_chat: boolean;
  typing: boolean;
  online_at: string;
}

/**
 * useChatPresence
 *
 * Realtime per-chat presence using Supabase Realtime Presence + Broadcast.
 * - Tracks whether the partner has THIS specific chat window open ("in_chat").
 * - Tracks typing status (broadcast, ephemeral, 3s auto-clear).
 * - Emits a "left" broadcast when the local user closes the window.
 *
 * No DB writes — purely realtime ephemeral signals, safe for high frequency.
 */
export const useChatPresence = ({
  chatId,
  currentUserId,
  partnerId,
  isWindowActive,
}: UseChatPresenceOptions) => {
  const [partnerState, setPartnerState] = useState<PartnerPresenceState>("connecting");
  const [partnerLastSeen, setPartnerLastSeen] = useState<Date | null>(null);
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null);
  const typingTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const partnerTypingTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const lastTypingSentRef = useRef<number>(0);
  const isMountedRef = useRef(true);

  // Compute partner state from a presence snapshot
  const computePartnerState = useCallback((metas: PresenceMeta[]): PartnerPresenceState => {
    if (!metas.length) return "offline";
    // Prefer the most recent meta
    const latest = metas[metas.length - 1];
    if (latest.typing) return "typing";
    if (latest.in_chat) return "in_chat";
    return "online_away";
  }, []);

  useEffect(() => {
    if (!chatId || !currentUserId || !partnerId) return;
    isMountedRef.current = true;

    const channel = supabase.channel(`chat-presence:${chatId}`, {
      config: { presence: { key: currentUserId } },
    });
    channelRef.current = channel;

    const refreshFromPresence = () => {
      const state = channel.presenceState() as Record<string, PresenceMeta[]>;
      const partnerMetas = state[partnerId] || [];
      if (!isMountedRef.current) return;
      const next = computePartnerState(partnerMetas);
      setPartnerState((prev) => {
        // If partner just disappeared and we previously saw them in chat, mark "left_chat" briefly
        if (next === "offline" && (prev === "in_chat" || prev === "typing")) {
          setPartnerLastSeen(new Date());
          return "left_chat";
        }
        if (next !== "offline") setPartnerLastSeen(new Date());
        return next;
      });
    };

    channel
      .on("presence", { event: "sync" }, refreshFromPresence)
      .on("presence", { event: "join" }, refreshFromPresence)
      .on("presence", { event: "leave" }, refreshFromPresence)
      .on("broadcast", { event: "typing" }, (payload) => {
        const fromId = (payload.payload as any)?.user_id;
        const isTyping = !!(payload.payload as any)?.typing;
        if (fromId !== partnerId || !isMountedRef.current) return;
        if (isTyping) {
          setPartnerState("typing");
          if (partnerTypingTimeoutRef.current) clearTimeout(partnerTypingTimeoutRef.current);
          partnerTypingTimeoutRef.current = setTimeout(() => {
            // Re-derive from presence after typing stops
            refreshFromPresence();
          }, 3000);
        } else {
          if (partnerTypingTimeoutRef.current) clearTimeout(partnerTypingTimeoutRef.current);
          refreshFromPresence();
        }
      })
      .on("broadcast", { event: "left" }, (payload) => {
        const fromId = (payload.payload as any)?.user_id;
        if (fromId !== partnerId || !isMountedRef.current) return;
        setPartnerLastSeen(new Date());
        setPartnerState("left_chat");
      })
      .subscribe(async (status) => {
        if (status === "SUBSCRIBED") {
          await channel.track({
            user_id: currentUserId,
            in_chat: isWindowActive,
            typing: false,
            online_at: new Date().toISOString(),
          } satisfies PresenceMeta);
          // Initial sync
          refreshFromPresence();
        }
      });

    return () => {
      isMountedRef.current = false;
      // Notify partner we left
      try {
        channel.send({
          type: "broadcast",
          event: "left",
          payload: { user_id: currentUserId },
        });
      } catch {
        /* noop */
      }
      if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
      if (partnerTypingTimeoutRef.current) clearTimeout(partnerTypingTimeoutRef.current);
      supabase.removeChannel(channel);
      channelRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [chatId, currentUserId, partnerId]);

  // Update local in_chat flag whenever window-active state changes
  useEffect(() => {
    const channel = channelRef.current;
    if (!channel) return;
    channel
      .track({
        user_id: currentUserId,
        in_chat: isWindowActive,
        typing: false,
        online_at: new Date().toISOString(),
      } satisfies PresenceMeta)
      .catch(() => {});
  }, [isWindowActive, currentUserId]);

  /** Call when local user types. Throttled to 1 broadcast/sec; auto-clears after 2.5s. */
  const sendTyping = useCallback(
    (isTyping: boolean) => {
      const channel = channelRef.current;
      if (!channel) return;
      const now = Date.now();
      // Throttle "typing=true" broadcasts
      if (isTyping && now - lastTypingSentRef.current < 1000) return;
      lastTypingSentRef.current = now;
      channel
        .send({
          type: "broadcast",
          event: "typing",
          payload: { user_id: currentUserId, typing: isTyping },
        })
        .catch(() => {});

      if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
      if (isTyping) {
        typingTimeoutRef.current = setTimeout(() => {
          channel
            .send({
              type: "broadcast",
              event: "typing",
              payload: { user_id: currentUserId, typing: false },
            })
            .catch(() => {});
        }, 2500);
      }
    },
    [currentUserId]
  );

  return { partnerState, partnerLastSeen, sendTyping };
};
