/**
 * ForwardDialog.tsx - Dialog to forward a message to another chat partner
 */
import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useToast } from '@/hooks/use-toast';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Input } from '@/components/ui/input';
import { Forward, Search, Loader2 } from 'lucide-react';

interface ForwardDialogProps {
  open: boolean;
  onClose: () => void;
  messageText: string;
  messageId: string;
  currentUserId: string;
}

interface RecentChat {
  partnerId: string;
  partnerName: string;
  partnerAvatar: string | null;
  chatId: string;
}

export const ForwardDialog = ({
  open,
  onClose,
  messageText,
  messageId,
  currentUserId,
}: ForwardDialogProps) => {
  const { toast } = useToast();
  const [recentChats, setRecentChats] = useState<RecentChat[]>([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isSending, setIsSending] = useState<string | null>(null);

  useEffect(() => {
    if (!open || !currentUserId) return;
    loadRecentChats();
  }, [open, currentUserId]);

  const loadRecentChats = async () => {
    setIsLoading(true);
    try {
      // Get recent distinct chat partners
      const { data: sessions } = await supabase
        .from('active_chat_sessions')
        .select('chat_id, man_user_id, woman_user_id')
        .or(`man_user_id.eq.${currentUserId},woman_user_id.eq.${currentUserId}`)
        .order('last_activity_at', { ascending: false })
        .limit(20);

      if (!sessions) { setIsLoading(false); return; }

      const chats: RecentChat[] = [];
      const seen = new Set<string>();

      for (const s of sessions) {
        const pid = s.man_user_id === currentUserId ? s.woman_user_id : s.man_user_id;
        if (seen.has(pid)) continue;
        seen.add(pid);

        const { data: profile } = await supabase
          .from('profiles')
          .select('full_name, photo_url')
          .eq('user_id', pid)
          .maybeSingle();

        chats.push({
          partnerId: pid,
          partnerName: profile?.full_name || 'User',
          partnerAvatar: profile?.photo_url || null,
          chatId: s.chat_id,
        });
      }
      setRecentChats(chats);
    } catch (err) {
      console.error('Load recent chats error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleForward = async (chat: RecentChat) => {
    setIsSending(chat.partnerId);
    try {
      await supabase.from('chat_messages').insert({
        chat_id: chat.chatId,
        sender_id: currentUserId,
        receiver_id: chat.partnerId,
        message: messageText,
        is_forwarded: true,
        forwarded_from_id: messageId,
      } as any);

      toast({ title: 'Message forwarded', description: `Sent to ${chat.partnerName}` });
      onClose();
    } catch (err) {
      console.error('Forward error:', err);
      toast({ title: 'Error', description: 'Failed to forward message', variant: 'destructive' });
    } finally {
      setIsSending(null);
    }
  };

  const filtered = recentChats.filter(c =>
    c.partnerName.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Forward className="h-5 w-5" /> Forward Message
          </DialogTitle>
        </DialogHeader>

        {/* Message preview */}
        <div className="bg-muted/50 rounded-lg p-3 text-sm text-muted-foreground truncate">
          "{messageText}"
        </div>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search chats..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>

        {/* Chat list */}
        <ScrollArea className="max-h-[300px]">
          {isLoading ? (
            <div className="flex items-center justify-center py-8">
              <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
            </div>
          ) : filtered.length === 0 ? (
            <p className="text-center text-sm text-muted-foreground py-8">No chats found</p>
          ) : (
            <div className="space-y-1">
              {filtered.map(chat => (
                <button
                  key={chat.partnerId}
                  className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-muted transition-colors"
                  onClick={() => handleForward(chat)}
                  disabled={!!isSending}
                >
                  <Avatar className="h-10 w-10">
                    <AvatarImage src={chat.partnerAvatar || undefined} />
                    <AvatarFallback className="bg-primary/10 text-primary">
                      {chat.partnerName.charAt(0)}
                    </AvatarFallback>
                  </Avatar>
                  <span className="flex-1 text-left text-sm font-medium">{chat.partnerName}</span>
                  {isSending === chat.partnerId && (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  )}
                </button>
              ))}
            </div>
          )}
        </ScrollArea>
      </DialogContent>
    </Dialog>
  );
};

export default ForwardDialog;
