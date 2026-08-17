/**
 * MessageActions.tsx - WhatsApp-style message action menu
 * Provides: React, Reply, Forward, Edit, Delete, Pin
 */
import { useState, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useToast } from '@/hooks/use-toast';
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuSeparator,
  ContextMenuTrigger,
  ContextMenuSub,
  ContextMenuSubContent,
  ContextMenuSubTrigger,
} from '@/components/ui/context-menu';
import {
  Reply,
  Forward,
  Pencil,
  Trash2,
  Pin,
  PinOff,
  SmilePlus,
} from 'lucide-react';

const QUICK_EMOJIS = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
const EDIT_TIME_LIMIT_MS = 15 * 60 * 1000; // 15 minutes

interface MessageActionsProps {
  children: React.ReactNode;
  messageId: string;
  messageText: string;
  senderId: string;
  currentUserId: string;
  chatId: string;
  createdAt: string;
  isPinned?: boolean;
  onReply: (messageId: string, text: string, senderName: string) => void;
  onForward: (messageId: string, text: string) => void;
  onEdit: (messageId: string, currentText: string) => void;
  onDelete: (messageId: string, deleteType: 'for_me' | 'for_everyone') => void;
  onReaction: (messageId: string, emoji: string) => void;
  onPinToggle: (messageId: string, isPinned: boolean) => void;
  senderName: string;
}

export const MessageActions = ({
  children,
  messageId,
  messageText,
  senderId,
  currentUserId,
  chatId,
  createdAt,
  isPinned = false,
  onReply,
  onForward,
  onEdit,
  onDelete,
  onReaction,
  onPinToggle,
  senderName,
}: MessageActionsProps) => {
  const isOwn = senderId === currentUserId;
  const canEdit = isOwn && (Date.now() - new Date(createdAt).getTime()) < EDIT_TIME_LIMIT_MS;

  // Long-press for mobile
  const [showMobileMenu, setShowMobileMenu] = useState(false);
  const longPressTimer = { current: null as NodeJS.Timeout | null };

  const handleTouchStart = () => {
    longPressTimer.current = setTimeout(() => setShowMobileMenu(true), 600);
  };
  const handleTouchEnd = () => {
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
  };

  const menuItems = (close: () => void) => (
    <>
      {/* Quick emoji reactions */}
      <div className="flex items-center gap-1 px-2 py-1.5">
        {QUICK_EMOJIS.map(emoji => (
          <button
            key={emoji}
            className="text-lg hover:scale-125 transition-transform p-1"
            onClick={() => { onReaction(messageId, emoji); close(); }}
          >
            {emoji}
          </button>
        ))}
      </div>
      <ContextMenuSeparator />
      <ContextMenuItem onClick={() => { onReply(messageId, messageText, senderName); close(); }} className="gap-2">
        <Reply className="h-4 w-4" /> Reply
      </ContextMenuItem>
      <ContextMenuItem onClick={() => { onForward(messageId, messageText); close(); }} className="gap-2">
        <Forward className="h-4 w-4" /> Forward
      </ContextMenuItem>
      {canEdit && (
        <ContextMenuItem onClick={() => { onEdit(messageId, messageText); close(); }} className="gap-2">
          <Pencil className="h-4 w-4" /> Edit
        </ContextMenuItem>
      )}
      <ContextMenuItem onClick={() => { onPinToggle(messageId, isPinned); close(); }} className="gap-2">
        {isPinned ? <PinOff className="h-4 w-4" /> : <Pin className="h-4 w-4" />}
        {isPinned ? 'Unpin' : 'Pin'}
      </ContextMenuItem>
      <ContextMenuSeparator />
      <ContextMenuItem onClick={() => { onDelete(messageId, 'for_me'); close(); }} className="gap-2">
        <Trash2 className="h-4 w-4" /> Delete for me
      </ContextMenuItem>
      {isOwn && (
        <ContextMenuItem
          onClick={() => { onDelete(messageId, 'for_everyone'); close(); }}
          className="gap-2 text-destructive focus:text-destructive"
        >
          <Trash2 className="h-4 w-4" /> Delete for everyone
        </ContextMenuItem>
      )}
    </>
  );

  return (
    <>
      <ContextMenu>
        <ContextMenuTrigger asChild>
          <div
            onTouchStart={handleTouchStart}
            onTouchEnd={handleTouchEnd}
            onTouchCancel={handleTouchEnd}
          >
            {children}
          </div>
        </ContextMenuTrigger>
        <ContextMenuContent className="w-56">
          {menuItems(() => {})}
        </ContextMenuContent>
      </ContextMenu>

      {/* Mobile long-press menu */}
      {showMobileMenu && (
        <div
          className="fixed inset-0 z-[200] bg-black/30 flex items-center justify-center"
          onClick={() => setShowMobileMenu(false)}
        >
          <div
            className="bg-popover border border-border rounded-xl shadow-2xl p-2 min-w-[240px] max-w-[300px]"
            onClick={e => e.stopPropagation()}
          >
            {/* Quick emoji reactions */}
            <div className="flex items-center justify-center gap-2 py-2">
              {QUICK_EMOJIS.map(emoji => (
                <button
                  key={emoji}
                  className="text-2xl hover:scale-125 transition-transform p-1"
                  onClick={() => { onReaction(messageId, emoji); setShowMobileMenu(false); }}
                >
                  {emoji}
                </button>
              ))}
            </div>
            <div className="border-t border-border my-1" />
            <button
              className="w-full flex items-center gap-3 px-3 py-2.5 text-sm hover:bg-muted rounded-lg transition-colors"
              onClick={() => { onReply(messageId, messageText, senderName); setShowMobileMenu(false); }}
            >
              <Reply className="h-4 w-4 text-muted-foreground" /> Reply
            </button>
            <button
              className="w-full flex items-center gap-3 px-3 py-2.5 text-sm hover:bg-muted rounded-lg transition-colors"
              onClick={() => { onForward(messageId, messageText); setShowMobileMenu(false); }}
            >
              <Forward className="h-4 w-4 text-muted-foreground" /> Forward
            </button>
            {canEdit && (
              <button
                className="w-full flex items-center gap-3 px-3 py-2.5 text-sm hover:bg-muted rounded-lg transition-colors"
                onClick={() => { onEdit(messageId, messageText); setShowMobileMenu(false); }}
              >
                <Pencil className="h-4 w-4 text-muted-foreground" /> Edit
              </button>
            )}
            <button
              className="w-full flex items-center gap-3 px-3 py-2.5 text-sm hover:bg-muted rounded-lg transition-colors"
              onClick={() => { onPinToggle(messageId, isPinned); setShowMobileMenu(false); }}
            >
              {isPinned ? <PinOff className="h-4 w-4 text-muted-foreground" /> : <Pin className="h-4 w-4 text-muted-foreground" />}
              {isPinned ? 'Unpin' : 'Pin'}
            </button>
            <div className="border-t border-border my-1" />
            <button
              className="w-full flex items-center gap-3 px-3 py-2.5 text-sm hover:bg-muted rounded-lg transition-colors"
              onClick={() => { onDelete(messageId, 'for_me'); setShowMobileMenu(false); }}
            >
              <Trash2 className="h-4 w-4 text-muted-foreground" /> Delete for me
            </button>
            {isOwn && (
              <button
                className="w-full flex items-center gap-3 px-3 py-2.5 text-sm text-destructive hover:bg-destructive/10 rounded-lg transition-colors"
                onClick={() => { onDelete(messageId, 'for_everyone'); setShowMobileMenu(false); }}
              >
                <Trash2 className="h-4 w-4" /> Delete for everyone
              </button>
            )}
          </div>
        </div>
      )}
    </>
  );
};

export default MessageActions;
