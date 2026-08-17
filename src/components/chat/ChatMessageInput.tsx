import React, { memo, useState, useRef, useCallback, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { cn } from '@/lib/utils';
import { Send, Loader2, AlertTriangle } from 'lucide-react';
import { chatRateLimiter } from '@/lib/validation';
import { moderateMessage } from '@/lib/content-moderation';

const DEFAULT_LABELS = { placeholder: 'Type a message...', send: 'Send', preview: 'Preview' };

interface ChatMessageInputProps {
  onSendMessage: (message: string) => void;
  onTyping?: (isTyping: boolean) => void;
  onInputChange?: (text: string) => void;
  disabled?: boolean;
  placeholder?: string;
  className?: string;
  userLanguage?: string;
  maxLength?: number;
}

export const ChatMessageInput: React.FC<ChatMessageInputProps> = memo(({
  onSendMessage,
  onTyping,
  onInputChange,
  disabled = false,
  placeholder,
  className,
  maxLength = 2000,
}) => {
  const [message, setMessage] = useState('');
  const [isSending, setIsSending] = useState(false);
  const [moderationWarning, setModerationWarning] = useState<string | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const typingTimeoutRef = useRef<NodeJS.Timeout>();
  const warningTimeoutRef = useRef<NodeJS.Timeout>();

  const labels = DEFAULT_LABELS;

  // iOS keyboard height detection
  useEffect(() => {
    const viewport = window.visualViewport;
    if (!viewport) return;
    const handleResize = () => {
      const keyboardHeight = Math.max(0, window.innerHeight - viewport.height);
      document.documentElement.style.setProperty("--keyboard-height", `${keyboardHeight}px`);
    };
    viewport.addEventListener("resize", handleResize);
    return () => viewport.removeEventListener("resize", handleResize);
  }, []);


  const showWarning = useCallback((reason: string) => {
    setModerationWarning(reason);
    if (warningTimeoutRef.current) clearTimeout(warningTimeoutRef.current);
    warningTimeoutRef.current = setTimeout(() => setModerationWarning(null), 4000);
  }, []);

  const handleChange = useCallback((e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const value = e.target.value;
    if (value.length > maxLength) return;
    setMessage(value);
    onInputChange?.(value);

    // Live moderation as user types — clears warning when text becomes safe
    if (value.trim().length > 2) {
      const result = moderateMessage(value);
      if (result.isBlocked) {
        setModerationWarning(result.reason || 'Prohibited content detected.');
      } else if (moderationWarning) {
        setModerationWarning(null);
      }
    } else if (moderationWarning) {
      setModerationWarning(null);
    }

    if (onTyping) {
      onTyping(value.length > 0);
      if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
      typingTimeoutRef.current = setTimeout(() => onTyping(false), 2000);
    }
  }, [onTyping, onInputChange, maxLength, moderationWarning]);

  const handleSend = useCallback(async () => {
    const text = message.trim().replace(/<[^>]*>/g, "");
    if (!text || disabled || isSending) return;

    // Final moderation gate — block send entirely with red warning
    const moderation = moderateMessage(text);
    if (moderation.isBlocked) {
      showWarning(moderation.reason || 'Message contains prohibited content and was not sent.');
      return;
    }

    if (!chatRateLimiter.canProceed()) {
      return;
    }

    setIsSending(true);
    try {
      setMessage('');
      setModerationWarning(null);
      onTyping?.(false);
      textareaRef.current?.focus();
      await onSendMessage(text);
    } finally {
      setIsSending(false);
    }
  }, [message, disabled, isSending, onSendMessage, onTyping, showWarning]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  }, [handleSend]);

  useEffect(() => {
    return () => {
      if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
      if (warningTimeoutRef.current) clearTimeout(warningTimeoutRef.current);
    };
  }, []);

  // Auto-resize textarea
  useEffect(() => {
    const textarea = textareaRef.current;
    if (textarea) {
      textarea.style.height = 'auto';
      textarea.style.height = `${Math.min(textarea.scrollHeight, 120)}px`;
    }
  }, [message]);

  return (
    <div className={cn('border-t border-border bg-background/95 backdrop-blur-sm', className)}>
      {moderationWarning && (
        <div
          role="alert"
          aria-live="assertive"
          className="mx-3 mt-2 flex items-start gap-2 rounded-lg border-2 border-destructive bg-destructive/10 px-3 py-2 text-destructive animate-in fade-in slide-in-from-bottom-1"
        >
          <AlertTriangle className="h-4 w-4 mt-0.5 flex-shrink-0" />
          <p className="text-sm font-semibold leading-tight">{moderationWarning}</p>
        </div>
      )}
      <div className="p-3 pt-2 flex items-end gap-2">
        <div className="flex-1 relative">
          <Textarea
            ref={textareaRef}
            value={message}
            onChange={handleChange}
            onKeyDown={handleKeyDown}
            placeholder={placeholder || labels.placeholder}
            disabled={disabled || isSending}
            dir="auto"
            spellCheck={true}
            autoComplete="off"
            autoCorrect="on"
            className={cn(
              'min-h-[44px] max-h-[120px] resize-none unicode-text',
              'py-3 px-4 pr-12',
              'rounded-xl border-muted-foreground/20',
              'focus-visible:ring-primary/50',
              'text-lg',
              moderationWarning && 'border-destructive text-destructive placeholder:text-destructive/60 focus-visible:ring-destructive',
            )}
            aria-label={labels.placeholder}
          />
          {/* CHT-08 FIX: Removed non-functional emoji button */}
        </div>

        <Button
          onClick={handleSend}
          disabled={!message.trim() || disabled || isSending}
          size="icon"
          className={cn(
            'h-11 w-11 rounded-full flex-shrink-0',
            'bg-primary hover:bg-primary/90',
            'transition-transform active:scale-95',
          )}
          aria-label={labels.send}
          title={labels.send}
        >
          {isSending ? (
            <Loader2 className="h-5 w-5 animate-spin" />
          ) : (
            <Send className="h-5 w-5" />
          )}
        </Button>
      </div>
    </div>
  );
});

ChatMessageInput.displayName = 'ChatMessageInput';

export default ChatMessageInput;
