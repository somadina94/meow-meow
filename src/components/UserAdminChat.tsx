/**
 * UserAdminChat - Floating chat button for users to message admin
 * All admin emails (admin1-15@meow-meow.com) appear as "Admin"
 * Messages auto-delete after 1 week
 */
import { useState, useEffect, useRef } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import { toast } from 'sonner';
import { format } from 'date-fns';
import {
  MessageCircle, Send, X, Loader2, Shield, ChevronDown
} from 'lucide-react';
import { cn } from '@/lib/utils';

interface UserAdminChatProps {
  currentUserId: string;
  userName: string;
  embedded?: boolean;
}

interface Message {
  id: string;
  sender_role: string;
  sender_id: string;
  message: string;
  created_at: string;
}

export function UserAdminChat({ currentUserId, userName, embedded = false }: UserAdminChatProps) {
  const [isOpen, setIsOpen] = useState(embedded);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [isSending, setIsSending] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const chatEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (isOpen) {
      fetchMessages();
      markAsRead();
    } else {
      fetchUnreadCount();
    }
  }, [isOpen, currentUserId]);

  useEffect(() => {
    // Realtime subscription for new messages
    const channel = supabase
      .channel(`admin-chat-${currentUserId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'admin_user_messages',
        filter: `target_user_id=eq.${currentUserId}`,
      }, () => {
        if (isOpen) {
          fetchMessages();
          markAsRead();
        } else {
          fetchUnreadCount();
        }
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [currentUserId, isOpen]);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const fetchMessages = async () => {
    const { data } = await supabase
      .from('admin_user_messages')
      .select('id, sender_role, sender_id, message, created_at')
      .eq('target_user_id', currentUserId)
      .order('created_at', { ascending: true })
      .limit(100);

    if (data) setMessages(data as Message[]);
  };

  const fetchUnreadCount = async () => {
    const { count } = await supabase
      .from('admin_user_messages')
      .select('*', { count: 'exact', head: true })
      .eq('target_user_id', currentUserId)
      .eq('sender_role', 'admin')
      .eq('is_read', false);

    setUnreadCount(count || 0);
  };

  const markAsRead = async () => {
    await supabase
      .from('admin_user_messages')
      .update({ is_read: true })
      .eq('target_user_id', currentUserId)
      .eq('sender_role', 'admin')
      .eq('is_read', false);

    setUnreadCount(0);
  };

  const sendMessage = async () => {
    if (!newMessage.trim()) return;
    setIsSending(true);
    try {
      const { error } = await supabase.from('admin_user_messages').insert({
        admin_id: currentUserId,
        target_group: 'direct',
        target_user_id: currentUserId,
        sender_role: 'user',
        sender_id: currentUserId,
        message: newMessage.trim(),
      });
      if (error) throw error;
      setNewMessage('');
      fetchMessages();
    } catch (err: any) {
      toast.error(err.message || 'Failed to send message');
    } finally {
      setIsSending(false);
    }
  };

  if (embedded) {
    return (
      <div className="flex flex-col h-[60vh]">
        {/* Messages */}
        <ScrollArea className="flex-1 p-2.5 sm:p-3">
          <div className="space-y-2">
            {messages.length === 0 && (
              <div className="text-center py-6 text-muted-foreground">
                <MessageCircle className="h-7 w-7 mx-auto mb-2 opacity-40" />
                <p className="text-xs sm:text-sm">Send a message to Admin</p>
                <p className="text-[10px] sm:text-xs">We'll respond as soon as possible</p>
              </div>
            )}
            {messages.map((msg) => (
              <div
                key={msg.id}
                className={cn(
                  'max-w-[85%] p-2 sm:p-2.5 rounded-xl text-xs sm:text-sm',
                  msg.sender_role === 'user'
                    ? 'ml-auto bg-primary text-primary-foreground rounded-br-sm'
                    : 'mr-auto bg-muted rounded-bl-sm'
                )}
              >
                {msg.sender_role === 'admin' && (
                  <p className="text-[10px] sm:text-xs font-semibold mb-0.5 flex items-center gap-1">
                    <Shield className="h-2.5 w-2.5 sm:h-3 sm:w-3" /> Admin
                  </p>
                )}
                <p className="break-words">{msg.message}</p>
                <p className="text-[9px] sm:text-xs opacity-60 mt-1">
                  {format(new Date(msg.created_at), 'MMM dd, hh:mm a')}
                </p>
              </div>
            ))}
            <div ref={chatEndRef} />
          </div>
        </ScrollArea>

        {/* Input */}
        <div className="p-2 sm:p-3 border-t border-border flex gap-1.5 sm:gap-2">
          <Textarea
            value={newMessage}
            onChange={(e) => setNewMessage(e.target.value)}
            placeholder="Type a message..."
            rows={1}
            className="resize-none flex-1 min-h-[36px] max-h-[72px] text-xs sm:text-sm"
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
              }
            }}
          />
          <Button
            size="icon"
            className="shrink-0 h-9 w-9 sm:h-10 sm:w-10"
            onClick={sendMessage}
            disabled={!newMessage.trim() || isSending}
          >
            {isSending ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Send className="h-3.5 w-3.5" />}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <>
      {/* Floating chat button */}
      <button
        onClick={() => setIsOpen(true)}
        className={cn(
          'fixed bottom-20 right-3 z-40 w-12 h-12 sm:w-14 sm:h-14 rounded-full shadow-lg flex items-center justify-center transition-all',
          'bg-primary text-primary-foreground hover:scale-105 active:scale-95',
          isOpen && 'hidden'
        )}
      >
        <Shield className="h-5 w-5 sm:h-6 sm:w-6" />
        {unreadCount > 0 && (
          <span className="absolute -top-1 -right-1 w-4 h-4 sm:w-5 sm:h-5 bg-destructive text-destructive-foreground text-[10px] sm:text-xs rounded-full flex items-center justify-center font-bold">
            {unreadCount}
          </span>
        )}
      </button>

      {/* Chat window */}
      {isOpen && (
        <div className="fixed bottom-2 right-2 left-2 sm:left-auto sm:right-4 sm:bottom-4 z-50 sm:w-96 max-h-[85vh] sm:max-h-[500px] rounded-2xl border border-border bg-card shadow-2xl flex flex-col overflow-hidden animate-in slide-in-from-bottom-4">
          {/* Header */}
          <div className="flex items-center justify-between px-3 py-2.5 sm:px-4 sm:py-3 bg-primary text-primary-foreground">
            <div className="flex items-center gap-2">
              <Shield className="h-4 w-4 sm:h-5 sm:w-5" />
              <div>
                <p className="font-semibold text-xs sm:text-sm">Contact Admin</p>
                <p className="text-[10px] sm:text-xs opacity-80">Messages kept for 1 week</p>
              </div>
            </div>
            <button onClick={() => setIsOpen(false)} className="p-1 rounded-full hover:bg-white/20 transition-colors">
              <X className="h-4 w-4" />
            </button>
          </div>

          {/* Messages */}
          <ScrollArea className="flex-1 max-h-[50vh] sm:max-h-[340px] p-2.5 sm:p-3">
            <div className="space-y-2">
              {messages.length === 0 && (
                <div className="text-center py-6 text-muted-foreground">
                  <MessageCircle className="h-7 w-7 mx-auto mb-2 opacity-40" />
                  <p className="text-xs sm:text-sm">Send a message to Admin</p>
                  <p className="text-[10px] sm:text-xs">We'll respond as soon as possible</p>
                </div>
              )}
              {messages.map((msg) => (
                <div
                  key={msg.id}
                  className={cn(
                    'max-w-[85%] p-2 sm:p-2.5 rounded-xl text-xs sm:text-sm',
                    msg.sender_role === 'user'
                      ? 'ml-auto bg-primary text-primary-foreground rounded-br-sm'
                      : 'mr-auto bg-muted rounded-bl-sm'
                  )}
                >
                  {msg.sender_role === 'admin' && (
                    <p className="text-[10px] sm:text-xs font-semibold mb-0.5 flex items-center gap-1">
                      <Shield className="h-2.5 w-2.5 sm:h-3 sm:w-3" /> Admin
                    </p>
                  )}
                  <p className="break-words">{msg.message}</p>
                  <p className="text-[9px] sm:text-xs opacity-60 mt-1">
                    {format(new Date(msg.created_at), 'MMM dd, hh:mm a')}
                  </p>
                </div>
              ))}
              <div ref={chatEndRef} />
            </div>
          </ScrollArea>

          {/* Input */}
          <div className="p-2 sm:p-3 border-t border-border flex gap-1.5 sm:gap-2">
            <Textarea
              value={newMessage}
              onChange={(e) => setNewMessage(e.target.value)}
              placeholder="Type a message..."
              rows={1}
              className="resize-none flex-1 min-h-[36px] max-h-[72px] text-xs sm:text-sm"
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault();
                  sendMessage();
                }
              }}
            />
            <Button
              size="icon"
              className="shrink-0 h-9 w-9 sm:h-10 sm:w-10"
              onClick={sendMessage}
              disabled={!newMessage.trim() || isSending}
            >
              {isSending ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Send className="h-3.5 w-3.5" />}
            </Button>
          </div>
        </div>
      )}
    </>
  );
}
