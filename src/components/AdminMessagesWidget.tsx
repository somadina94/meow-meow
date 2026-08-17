import { toast } from "sonner";
import { useState, useEffect, useCallback } from "react";
import { supabase } from "@/integrations/supabase/client";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Megaphone, Mail, Clock, ChevronDown, ChevronUp } from "lucide-react";
import { Button } from "@/components/ui/button";
import { formatDistanceToNow } from "date-fns";
import { cn } from "@/lib/utils";

interface AdminMessage {
  id: string;
  subject: string;
  message: string;
  is_broadcast: boolean;
  is_read: boolean;
  created_at: string;
  admin_id: string;
}

interface AdminMessagesWidgetProps {
  currentUserId: string;
}

export const AdminMessagesWidget = ({ currentUserId }: AdminMessagesWidgetProps) => {
  const [messages, setMessages] = useState<AdminMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState(true);
  const [expandedMessageId, setExpandedMessageId] = useState<string | null>(null);

  const loadMessages = useCallback(async () => {
    try {
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      // Fetch from admin_broadcast_messages (broadcast + direct)
      const { data: broadcastMsgs } = await supabase
        .from('admin_broadcast_messages')
        .select('*')
        .or(`is_broadcast.eq.true,recipient_id.eq.${currentUserId}`)
        .gte('created_at', sevenDaysAgo.toISOString())
        .order('created_at', { ascending: false })
        .limit(50);

      // Also fetch from admin_user_messages (admin-sent messages to this user or broadcasts)
      const { data: adminUserMsgs } = await supabase
        .from('admin_user_messages')
        .select('id, message, sender_role, target_group, target_user_id, is_read, created_at')
        .eq('sender_role', 'admin')
        .or(`target_user_id.eq.${currentUserId},target_user_id.is.null`)
        .gte('created_at', sevenDaysAgo.toISOString())
        .order('created_at', { ascending: false })
        .limit(50);

      // Merge both sources, dedup by id
      const allMessages: AdminMessage[] = [];
      const seenIds = new Set<string>();

      for (const msg of (broadcastMsgs || [])) {
        if (!seenIds.has(msg.id)) {
          seenIds.add(msg.id);
          allMessages.push({
            id: msg.id,
            subject: msg.subject || 'Admin Message',
            message: msg.message,
            is_broadcast: msg.is_broadcast,
            is_read: msg.is_read,
            created_at: msg.created_at,
            admin_id: msg.admin_id,
          });
        }
      }

      for (const msg of (adminUserMsgs || [])) {
        if (!seenIds.has(msg.id)) {
          seenIds.add(msg.id);
          allMessages.push({
            id: msg.id,
            subject: msg.target_user_id ? 'Message from Admin' : `Broadcast to ${msg.target_group || 'all'}`,
            message: msg.message,
            is_broadcast: !msg.target_user_id,
            is_read: msg.is_read,
            created_at: msg.created_at,
            admin_id: '',
          });
        }
      }

      // Sort by date desc
      allMessages.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
      setMessages(allMessages.slice(0, 50));
    } catch (err) {
      console.error('Error loading admin messages:', err);
      toast.error('Messages unavailable', { description: 'Unable to load admin messages. Please refresh.' });
    } finally {
      setLoading(false);
    }
  }, [currentUserId]);

  useEffect(() => {
    loadMessages();

    // Subscribe to real-time updates from both tables
    const channel = supabase
      .channel(`admin-messages-${currentUserId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'admin_broadcast_messages' },
        () => loadMessages()
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'admin_user_messages' },
        () => loadMessages()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [loadMessages, currentUserId]);

  // Mark message as read
  const markAsRead = async (messageId: string) => {
    // Try both tables since messages come from either source
    await Promise.all([
      supabase.from('admin_broadcast_messages').update({ is_read: true }).eq('id', messageId),
      supabase.from('admin_user_messages').update({ is_read: true }).eq('id', messageId),
    ]);

    setMessages(prev =>
      prev.map(m => (m.id === messageId ? { ...m, is_read: true } : m))
    );
  };

  const unreadCount = messages.filter(m => !m.is_read).length;

  if (loading) {
    return (
      <Card className="border-border bg-card">
        <CardContent className="py-4 flex items-center justify-center">
          <div className="h-5 w-5 animate-spin rounded-full border-2 border-primary border-t-transparent" />
        </CardContent>
      </Card>
    );
  }

  if (messages.length === 0) return null;

  return (
    <Card className="border-border bg-card overflow-hidden max-w-full">
      <CardHeader className="pb-2 px-2.5 sm:px-4 pt-2.5 sm:pt-3">
        <div className="flex items-center justify-between gap-2">
          <CardTitle className="text-xs sm:text-sm font-semibold flex items-center gap-1.5 text-foreground min-w-0">
            <Megaphone className="h-3.5 w-3.5 sm:h-4 sm:w-4 text-primary shrink-0" />
            <span className="truncate">Admin Messages</span>
            {unreadCount > 0 && (
              <Badge variant="destructive" className="text-[9px] sm:text-[10px] px-1 py-0 h-3.5 sm:h-4 min-w-[14px]">
                {unreadCount}
              </Badge>
            )}
          </CardTitle>
          <Button
            variant="ghost"
            size="icon"
            className="h-6 w-6 sm:h-7 sm:w-7 shrink-0"
            onClick={() => setExpanded(!expanded)}
          >
            {expanded ? (
              <ChevronUp className="h-3.5 w-3.5 text-muted-foreground" />
            ) : (
              <ChevronDown className="h-3.5 w-3.5 text-muted-foreground" />
            )}
          </Button>
        </div>
      </CardHeader>

      {expanded && (
        <CardContent className="px-2.5 sm:px-4 pb-2.5 sm:pb-3 pt-0">
          <ScrollArea className="max-h-[250px] sm:max-h-[300px]">
            <div className="space-y-1.5 sm:space-y-2">
              {messages.map((msg) => {
                const isExpanded = expandedMessageId === msg.id;
                return (
                  <div
                    key={msg.id}
                    className={cn(
                      "p-2 sm:p-2.5 rounded-lg border transition-all cursor-pointer",
                      msg.is_read
                        ? "border-border bg-muted/30"
                        : "border-primary/40 bg-primary/5"
                    )}
                    onClick={() => {
                      if (!msg.is_read) markAsRead(msg.id);
                      setExpandedMessageId(isExpanded ? null : msg.id);
                    }}
                  >
                    <div className="flex items-start gap-1.5 sm:gap-2">
                      <div className={cn(
                        "mt-0.5 shrink-0 rounded-full p-0.5 sm:p-1",
                        msg.is_broadcast ? "bg-primary/10" : "bg-accent/10"
                      )}>
                        {msg.is_broadcast ? (
                          <Megaphone className="h-2.5 w-2.5 sm:h-3 sm:w-3 text-primary" />
                        ) : (
                          <Mail className="h-2.5 w-2.5 sm:h-3 sm:w-3 text-accent-foreground" />
                        )}
                      </div>
                      <div className="flex-1 min-w-0 overflow-hidden">
                        <div className="flex items-center justify-between gap-1.5">
                          <p className={cn(
                            "text-[11px] sm:text-xs font-medium truncate",
                            msg.is_read ? "text-foreground" : "text-foreground font-semibold"
                          )}>
                            {msg.subject}
                          </p>
                          {!msg.is_read && (
                            <span className="h-1.5 w-1.5 sm:h-2 sm:w-2 rounded-full bg-primary shrink-0" />
                          )}
                        </div>
                        <div className="flex items-center gap-1 mt-0.5 flex-wrap">
                          <Clock className="h-2 w-2 sm:h-2.5 sm:w-2.5 text-muted-foreground shrink-0" />
                          <span className="text-[9px] sm:text-[10px] text-muted-foreground">
                            {formatDistanceToNow(new Date(msg.created_at), { addSuffix: true })}
                          </span>
                          <Badge
                            variant="secondary"
                            className="text-[8px] sm:text-[9px] px-1 py-0 h-3 sm:h-3.5"
                          >
                            {msg.is_broadcast ? "Broadcast" : "Direct"}
                          </Badge>
                        </div>
                        {isExpanded && (
                          <p className="text-[11px] sm:text-xs text-muted-foreground mt-1.5 whitespace-pre-wrap leading-relaxed break-words">
                            {msg.message}
                          </p>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </ScrollArea>
        </CardContent>
      )}
    </Card>
  );
};
