import React, { memo, useRef, useEffect, useState, useCallback } from 'react';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { ScrollArea } from '@/components/ui/scroll-area';
import { cn } from '@/lib/utils';
import { Check, CheckCheck, MessageCircle, Loader2, Trash2, Ban } from 'lucide-react';
import { format, isToday, isYesterday } from 'date-fns';
import { supabase } from '@/integrations/supabase/client';
import { useToast } from '@/hooks/use-toast';
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuTrigger,
  ContextMenuSeparator,
} from '@/components/ui/context-menu';

export interface ChatMessage {
  id: string;
  content: string;
  senderId: string;
  senderName: string;
  senderAvatar?: string | null;
  senderLanguage?: string;
  timestamp: string;
  isRead?: boolean;
  isDelivered?: boolean;
  isTranslating?: boolean;
  englishText?: string;
  translatedContent?: string;
  deletedForEveryone?: boolean;
}

interface ChatMessageListProps {
  messages: ChatMessage[];
  currentUserId: string;
  className?: string;
  onMessageDeleted?: (messageId: string, deleteType: 'for_me' | 'for_everyone') => void;
}

const formatMessageTime = (timestamp: string) => {
  const date = new Date(timestamp);
  return format(date, 'HH:mm');
};

const formatDateHeader = (timestamp: string) => {
  const date = new Date(timestamp);
  if (isToday(date)) return 'Today';
  if (isYesterday(date)) return 'Yesterday';
  return format(date, 'MMMM d, yyyy');
};

const MessageStatus = memo(({ isDelivered, isRead }: { isDelivered?: boolean; isRead?: boolean }) => {
  if (isRead) {
    return <CheckCheck className="h-3.5 w-3.5 text-primary" aria-label="Read" />;
  }
  if (isDelivered) {
    return <Check className="h-3.5 w-3.5 text-muted-foreground" aria-label="Delivered" />;
  }
  return null;
});
MessageStatus.displayName = 'MessageStatus';

const MessageBubble = memo(({
  message,
  isOwn,
  currentUserId,
  onMessageDeleted,
}: {
  message: ChatMessage;
  isOwn: boolean;
  currentUserId: string;
  onMessageDeleted?: (messageId: string, deleteType: 'for_me' | 'for_everyone') => void;
}) => {
  const { toast } = useToast();
  const [isDeleting, setIsDeleting] = useState(false);
  // Long-press support for mobile
  const longPressTimer = useRef<NodeJS.Timeout | null>(null);
  const [showMobileMenu, setShowMobileMenu] = useState(false);

  const handleDeleteForMe = useCallback(async () => {
    setIsDeleting(true);
    try {
      const updateField = isOwn ? 'deleted_for_sender' : 'deleted_for_receiver';
      const { error } = await supabase
        .from('chat_messages')
        .update({ [updateField]: true, deleted_at: new Date().toISOString() } as any)
        .eq('id', message.id);

      if (error) throw error;
      onMessageDeleted?.(message.id, 'for_me');
      toast({ title: 'Message deleted', description: 'Deleted for you' });
    } catch (err) {
      console.error('Delete for me error:', err);
      toast({ title: 'Error', description: 'Failed to delete message', variant: 'destructive' });
    } finally {
      setIsDeleting(false);
      setShowMobileMenu(false);
    }
  }, [message.id, isOwn, onMessageDeleted, toast]);

  const handleDeleteForEveryone = useCallback(async () => {
    setIsDeleting(true);
    try {
      const { error } = await supabase
        .from('chat_messages')
        .update({
          deleted_for_everyone: true,
          deleted_for_sender: true,
          deleted_for_receiver: true,
          deleted_at: new Date().toISOString(),
        } as any)
        .eq('id', message.id);

      if (error) throw error;
      onMessageDeleted?.(message.id, 'for_everyone');
      toast({ title: 'Message deleted', description: 'Deleted for everyone' });
    } catch (err) {
      console.error('Delete for everyone error:', err);
      toast({ title: 'Error', description: 'Failed to delete message', variant: 'destructive' });
    } finally {
      setIsDeleting(false);
      setShowMobileMenu(false);
    }
  }, [message.id, onMessageDeleted, toast]);

  // Handle long press for mobile
  const handleTouchStart = useCallback(() => {
    longPressTimer.current = setTimeout(() => {
      setShowMobileMenu(true);
    }, 600);
  }, []);

  const handleTouchEnd = useCallback(() => {
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
  }, []);

  // If deleted for everyone, show placeholder
  if (message.deletedForEveryone) {
    return (
      <div
        className={cn(
          'flex gap-2 max-w-[85%] sm:max-w-[75%] animate-fade-in',
          isOwn ? 'ms-auto flex-row-reverse' : 'me-auto'
        )}
      >
        {!isOwn && (
          <Avatar className="h-8 w-8 flex-shrink-0">
            <AvatarImage src={message.senderAvatar || undefined} alt={message.senderName} />
            <AvatarFallback className="bg-primary/10 text-primary text-xs">
              {message.senderName.charAt(0).toUpperCase()}
            </AvatarFallback>
          </Avatar>
        )}
        <div className={cn('flex flex-col', isOwn ? 'items-end' : 'items-start')}>
          <div className="rounded-2xl px-4 py-2.5 bg-muted/30 border border-dashed border-muted-foreground/20 rounded-br-md">
            <p className="text-sm text-muted-foreground italic flex items-center gap-1.5">
              <Ban className="h-3.5 w-3.5" />
              This message was deleted
            </p>
          </div>
          <span className="text-[10px] text-muted-foreground mt-0.5 px-1">
            {formatMessageTime(message.timestamp)}
          </span>
        </div>
      </div>
    );
  }

  const bubbleContent = (
    <div
      className={cn(
        'flex gap-2 max-w-[85%] sm:max-w-[75%] animate-fade-in relative',
        isOwn ? 'ms-auto flex-row-reverse' : 'me-auto'
      )}
      onTouchStart={handleTouchStart}
      onTouchEnd={handleTouchEnd}
      onTouchCancel={handleTouchEnd}
    >
      {!isOwn && (
        <Avatar className="h-8 w-8 flex-shrink-0">
          <AvatarImage src={message.senderAvatar || undefined} alt={message.senderName} />
          <AvatarFallback className="bg-primary/10 text-primary text-xs">
            {message.senderName.charAt(0).toUpperCase()}
          </AvatarFallback>
        </Avatar>
      )}

      <div className={cn('flex flex-col', isOwn ? 'items-end' : 'items-start')}>
        <span className={cn(
          'text-xs font-semibold mb-1 px-1',
          isOwn
            ? 'text-primary'
            : 'text-emerald-600 dark:text-emerald-400'
        )}>
          {message.senderName}
          {message.senderLanguage && (
            <span className="text-muted-foreground/60 font-normal ms-1">• {message.senderLanguage}</span>
          )}
        </span>

        <div
          className={cn(
            'rounded-2xl px-4 py-2.5 unicode-text shadow-sm border',
            isOwn
              ? 'bg-primary/5 border-primary/20 rounded-br-md'
              : 'bg-emerald-50 border-emerald-200 dark:bg-emerald-950/20 dark:border-emerald-800 rounded-bl-md'
          )}
          dir="auto"
        >
          {message.isTranslating ? (
            <div className="flex items-center gap-1.5 py-1">
              <Loader2 className="h-3.5 w-3.5 animate-spin text-muted-foreground" />
              <span className="text-xs text-muted-foreground">Translating...</span>
            </div>
          ) : (
            <>
              <p className={cn(
                'text-sm leading-relaxed whitespace-pre-wrap break-words',
                isOwn
                  ? 'text-primary dark:text-primary'
                  : 'text-emerald-800 dark:text-emerald-200'
              )}>
                {message.translatedContent || message.content}
              </p>
              {message.englishText && message.englishText.toLowerCase() !== (message.translatedContent || message.content).toLowerCase() && (
                <p className="text-[10px] text-muted-foreground/70 italic mt-1" dir="ltr">
                  english: {message.englishText.toLowerCase()}
                </p>
              )}
            </>
          )}
        </div>

        <div className={cn(
          'flex items-center gap-1 mt-0.5 px-1',
          isOwn ? 'flex-row-reverse' : ''
        )}>
          <span className="text-[10px] text-muted-foreground">
            {formatMessageTime(message.timestamp)}
          </span>
          {isOwn && (
            <MessageStatus isDelivered={message.isDelivered} isRead={message.isRead} />
          )}
        </div>
      </div>

      {/* Mobile long-press menu */}
      {showMobileMenu && (
        <div
          className="fixed inset-0 z-[200] bg-black/20"
          onClick={() => setShowMobileMenu(false)}
        >
          <div
            className="absolute bg-popover border border-border rounded-lg shadow-xl p-1 min-w-[200px]"
            style={{
              top: '50%',
              left: '50%',
              transform: 'translate(-50%, -50%)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              className="w-full flex items-center gap-2 px-3 py-2.5 text-sm text-foreground hover:bg-muted rounded-md transition-colors"
              onClick={handleDeleteForMe}
              disabled={isDeleting}
            >
              <Trash2 className="h-4 w-4 text-muted-foreground" />
              Delete for me
            </button>
            {isOwn && (
              <button
                className="w-full flex items-center gap-2 px-3 py-2.5 text-sm text-destructive hover:bg-destructive/10 rounded-md transition-colors"
                onClick={handleDeleteForEveryone}
                disabled={isDeleting}
              >
                <Trash2 className="h-4 w-4" />
                Delete for everyone
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );

  // Desktop: right-click context menu
  return (
    <ContextMenu>
      <ContextMenuTrigger asChild>
        {bubbleContent}
      </ContextMenuTrigger>
      <ContextMenuContent className="w-52">
        <ContextMenuItem
          onClick={handleDeleteForMe}
          disabled={isDeleting}
          className="gap-2"
        >
          <Trash2 className="h-4 w-4" />
          Delete for me
        </ContextMenuItem>
        {isOwn && (
          <>
            <ContextMenuSeparator />
            <ContextMenuItem
              onClick={handleDeleteForEveryone}
              disabled={isDeleting}
              className="gap-2 text-destructive focus:text-destructive"
            >
              <Trash2 className="h-4 w-4" />
              Delete for everyone
            </ContextMenuItem>
          </>
        )}
      </ContextMenuContent>
    </ContextMenu>
  );
});
MessageBubble.displayName = 'MessageBubble';

export const ChatMessageList: React.FC<ChatMessageListProps> = memo(({
  messages,
  currentUserId,
  className,
  onMessageDeleted,
}) => {
  const scrollRef = useRef<HTMLDivElement>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  // Group messages by date
  const groupedMessages = messages.reduce((groups, message) => {
    const dateKey = formatDateHeader(message.timestamp);
    if (!groups[dateKey]) {
      groups[dateKey] = [];
    }
    groups[dateKey].push(message);
    return groups;
  }, {} as Record<string, ChatMessage[]>);

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages.length]);

  return (
    <ScrollArea className={cn('flex-1', className)} ref={scrollRef}>
      <div className="p-4 space-y-4">
        {Object.entries(groupedMessages).map(([date, dateMessages]) => (
          <div key={date}>
            <div className="flex items-center justify-center my-4" role="separator">
              <div className="bg-muted/50 px-3 py-1 rounded-full">
                <span className="text-xs text-muted-foreground font-medium">
                  {date}
                </span>
              </div>
            </div>

            <div className="space-y-3">
              {dateMessages.map((message) => (
                <MessageBubble
                  key={message.id}
                  message={message}
                  isOwn={message.senderId === currentUserId}
                  currentUserId={currentUserId}
                  onMessageDeleted={onMessageDeleted}
                />
              ))}
            </div>
          </div>
        ))}

        {messages.length === 0 && (
          <div className="text-center py-12">
            <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-muted/50 flex items-center justify-center">
              <MessageCircle className="h-8 w-8 text-muted-foreground/50" />
            </div>
            <h3 className="font-medium text-foreground mb-1">
              No messages yet
            </h3>
            <p className="text-sm text-muted-foreground">
              Start the conversation!
            </p>
          </div>
        )}

        <div ref={bottomRef} />
      </div>
    </ScrollArea>
  );
});

ChatMessageList.displayName = 'ChatMessageList';

export default ChatMessageList;
