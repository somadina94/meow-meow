/**
 * MessageReactions.tsx - Displays emoji reactions below a message bubble
 */
import { cn } from '@/lib/utils';

interface Reaction {
  emoji: string;
  count: number;
  userReacted: boolean;
}

interface MessageReactionsProps {
  reactions: Reaction[];
  onToggle: (emoji: string) => void;
  isOwn: boolean;
}

export const MessageReactions = ({ reactions, onToggle, isOwn }: MessageReactionsProps) => {
  if (reactions.length === 0) return null;

  return (
    <div className={cn('flex flex-wrap gap-1 mt-0.5 px-1', isOwn ? 'justify-end' : 'justify-start')}>
      {reactions.map(r => (
        <button
          key={r.emoji}
          onClick={() => onToggle(r.emoji)}
          className={cn(
            'flex items-center gap-0.5 px-1.5 py-0.5 rounded-full text-xs border transition-colors',
            r.userReacted
              ? 'bg-primary/10 border-primary/30 text-primary'
              : 'bg-muted/50 border-border hover:bg-muted'
          )}
        >
          <span>{r.emoji}</span>
          {r.count > 1 && <span className="text-[10px]">{r.count}</span>}
        </button>
      ))}
    </div>
  );
};

export default MessageReactions;
