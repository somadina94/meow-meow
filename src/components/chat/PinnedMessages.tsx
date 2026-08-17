/**
 * PinnedMessages.tsx - Displays pinned messages bar at top of chat
 */
import { useState } from 'react';
import { Pin, ChevronDown, ChevronUp, X } from 'lucide-react';
import { cn } from '@/lib/utils';

interface PinnedMessage {
  id: string;
  text: string;
  senderName: string;
}

interface PinnedMessagesProps {
  messages: PinnedMessage[];
  onJumpToMessage?: (messageId: string) => void;
  onUnpin?: (messageId: string) => void;
}

export const PinnedMessages = ({
  messages,
  onJumpToMessage,
  onUnpin,
}: PinnedMessagesProps) => {
  const [isExpanded, setIsExpanded] = useState(false);
  const [currentIndex, setCurrentIndex] = useState(0);

  if (messages.length === 0) return null;

  const current = messages[currentIndex] || messages[0];

  return (
    <div className="bg-muted/50 border-b border-border">
      <div
        className="flex items-center gap-2 px-4 py-2 cursor-pointer"
        onClick={() => {
          if (messages.length > 1) {
            setIsExpanded(!isExpanded);
          } else {
            onJumpToMessage?.(current.id);
          }
        }}
      >
        <Pin className="h-3.5 w-3.5 text-primary flex-shrink-0" />
        <div className="flex-1 min-w-0">
          <p className="text-[10px] font-semibold text-primary">{current.senderName}</p>
          <p className="text-xs text-foreground truncate">{current.text}</p>
        </div>
        {messages.length > 1 && (
          <div className="flex items-center gap-1">
            <span className="text-[10px] text-muted-foreground">
              {currentIndex + 1}/{messages.length}
            </span>
            <div className="flex flex-col">
              <button
                onClick={(e) => { e.stopPropagation(); setCurrentIndex(Math.max(0, currentIndex - 1)); }}
                className="p-0.5 hover:bg-muted rounded"
                disabled={currentIndex === 0}
              >
                <ChevronUp className="h-3 w-3" />
              </button>
              <button
                onClick={(e) => { e.stopPropagation(); setCurrentIndex(Math.min(messages.length - 1, currentIndex + 1)); }}
                className="p-0.5 hover:bg-muted rounded"
                disabled={currentIndex >= messages.length - 1}
              >
                <ChevronDown className="h-3 w-3" />
              </button>
            </div>
          </div>
        )}
      </div>

      {isExpanded && (
        <div className="border-t border-border/50 max-h-[200px] overflow-y-auto">
          {messages.map((msg, i) => (
            <div
              key={msg.id}
              className={cn(
                'flex items-center gap-2 px-4 py-2 hover:bg-muted/50 cursor-pointer',
                i === currentIndex && 'bg-primary/5'
              )}
              onClick={() => { setCurrentIndex(i); onJumpToMessage?.(msg.id); }}
            >
              <div className="flex-1 min-w-0">
                <p className="text-[10px] font-semibold text-muted-foreground">{msg.senderName}</p>
                <p className="text-xs truncate">{msg.text}</p>
              </div>
              {onUnpin && (
                <button
                  onClick={(e) => { e.stopPropagation(); onUnpin(msg.id); }}
                  className="p-1 hover:bg-muted rounded"
                >
                  <X className="h-3 w-3 text-muted-foreground" />
                </button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default PinnedMessages;
