/**
 * ReplyPreview.tsx - Shows the quoted message being replied to
 */
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';

interface ReplyPreviewProps {
  replyToText: string;
  replyToSender: string;
  isOwn: boolean;
  onCancel?: () => void;
  compact?: boolean; // true = inline in bubble, false = above input
}

export const ReplyPreview = ({
  replyToText,
  replyToSender,
  isOwn,
  onCancel,
  compact = false,
}: ReplyPreviewProps) => {
  if (compact) {
    return (
      <div className={cn(
        'border-l-2 pl-2 mb-1.5 py-0.5',
        isOwn ? 'border-primary/50' : 'border-emerald-500/50'
      )}>
        <p className="text-[10px] font-semibold text-muted-foreground">{replyToSender}</p>
        <p className="text-[11px] text-muted-foreground/80 truncate max-w-[200px]">{replyToText}</p>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-2 mx-4 mt-2 px-3 py-2 bg-muted/50 rounded-lg border-l-4 border-primary">
      <div className="flex-1 min-w-0">
        <p className="text-xs font-semibold text-primary">{replyToSender}</p>
        <p className="text-sm text-muted-foreground truncate">{replyToText}</p>
      </div>
      {onCancel && (
        <button onClick={onCancel} className="p-1 hover:bg-muted rounded-full">
          <X className="h-4 w-4 text-muted-foreground" />
        </button>
      )}
    </div>
  );
};

export default ReplyPreview;
