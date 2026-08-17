import { useEffect } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";

interface UsePartnerMonitorOptions {
  partnerId: string;
  partnerName: string;
  sessionId: string;
  isPartnerOnline: boolean;
  onClose: () => void;
}

/**
 * Monitors the chat partner's online status and session lifecycle.
 * WhatsApp-style: does NOT end sessions when partner goes offline.
 * Only closes the chat window when the session is explicitly ended by the other party.
 */
export const usePartnerMonitor = ({
  partnerId,
  partnerName,
  sessionId,
  isPartnerOnline,
  onClose,
}: UsePartnerMonitorOptions) => {
  const { toast } = useToast();

  useEffect(() => {
    // Listen for session status changes (explicit end by partner or admin)
    const sessionChannel = supabase
      .channel(`session-status-${sessionId}`)
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "active_chat_sessions",
          filter: `id=eq.${sessionId}`,
        },
        (payload: any) => {
          const session = payload.new;

          if (session.status === "ended" && session.end_reason) {
            // Only close for explicit user actions, NOT for partner_offline
            // WhatsApp-style: messages persist even when partner is offline
            if (session.end_reason === "partner_offline") {
              // Don't close — just show a subtle status update
              toast({
                title: "Partner Offline",
                description: `${partnerName} is offline. Your messages will be delivered when they return.`,
              });
              return;
            }

            let message = "Chat session ended";
            if (session.end_reason === "user_closed" || session.end_reason === "man_closed" || session.end_reason === "woman_closed") {
              message = `${partnerName} ended the chat`;
            } else if (session.end_reason === "inactivity_timeout") {
              message = "Chat ended due to inactivity";
            } else if (session.end_reason === "auto_timeout") {
              message = "Chat request expired - no response";
            } else if (session.end_reason === "user_blocked") {
              message = "Chat ended";
            } else if (session.end_reason === "mode_switch") {
              message = `${partnerName} changed chat mode`;
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
      supabase.removeChannel(sessionChannel);
    };
  }, [partnerId, partnerName, sessionId, onClose, toast]);
};
