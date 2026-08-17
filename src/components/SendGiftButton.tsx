/**
 * SendGiftButton — opens a gift catalog dialog and sends the selected gift
 * via the canonical bill_gift_or_tip RPC.
 *
 * Money flow (all rows go to wallet_transactions — single source of truth):
 *   • Man:   debit 100% of gift price       (transaction_type = 'gift_charge')
 *   • Woman: credit gift_woman_pct (50%)    (transaction_type = 'gift_earning')
 *
 * Used inside chat windows and 1-on-1 audio/video call screens.
 * Only rendered for male senders. Receiver is the conversation partner.
 */
import { useEffect, useState } from 'react';
import { Gift } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { supabase } from '@/integrations/supabase/client';
import { toast } from 'sonner';
import { cn } from '@/lib/utils';

interface GiftItem {
  id: string;
  name: string;
  emoji: string;
  price: number;
}

interface SendGiftButtonProps {
  /** auth user_id of the male sender. If omitted, resolved from supabase.auth */
  senderUserId?: string;
  /** auth user_id of the female recipient (chat partner / call peer) */
  recipientUserId: string;
  /** Optional context label embedded in the wallet description (e.g. "chat", "video call") */
  context?: 'chat' | 'audio_call' | 'video_call';
  className?: string;
  /** Visual size — small for chat headers, normal for call controls */
  variant?: 'icon-sm' | 'icon-md' | 'control';
}

export const SendGiftButton = ({
  senderUserId,
  recipientUserId,
  context = 'chat',
  className,
  variant = 'icon-sm',
}: SendGiftButtonProps) => {
  const [open, setOpen] = useState(false);
  const [gifts, setGifts] = useState<GiftItem[]>([]);
  const [sending, setSending] = useState<string | null>(null);

  useEffect(() => {
    if (!open || gifts.length > 0) return;
    (async () => {
      const { data } = await supabase
        .from('gifts')
        .select('id,name,emoji,price')
        .eq('is_active', true)
        .order('sort_order', { ascending: true })
        .limit(24);
      if (data) setGifts(data as GiftItem[]);
    })();
  }, [open, gifts.length]);

  const handleSend = async (gift: GiftItem) => {
    if (sending) return;
    setSending(gift.id);
    try {
      let senderAuthId = senderUserId;
      if (!senderAuthId) {
        const { data: u } = await supabase.auth.getUser();
        senderAuthId = u.user?.id;
      }
      if (!senderAuthId) throw new Error('Not signed in');

      // bill_gift_or_tip expects profiles.id, not auth user_id (mirrors group call path)
      const [{ data: manProf }, { data: womanProf }] = await Promise.all([
        supabase.from('profiles').select('id').eq('user_id', senderAuthId).maybeSingle(),
        supabase.from('profiles').select('id').eq('user_id', recipientUserId).maybeSingle(),
      ]);
      if (!manProf?.id || !womanProf?.id) throw new Error('Profile not found');

      const ref = (typeof crypto !== 'undefined' && crypto.randomUUID)
        ? `gift_${context}_${gift.id}_${crypto.randomUUID()}`
        : `gift_${context}_${gift.id}_${Date.now()}_${Math.random().toString(36).slice(2)}`;

      const ctxLabel = context === 'video_call'
        ? 'Video call gift'
        : context === 'audio_call'
          ? 'Audio call gift'
          : 'Chat gift';

      const { data, error } = await supabase.rpc('bill_gift_or_tip', {
        p_man_id: manProf.id,
        p_woman_id: womanProf.id,
        p_amount: gift.price ?? 0,
        p_type: 'gift',
        p_description: `${ctxLabel}: ${gift.name ?? gift.emoji}`,
        p_reference_id: ref,
      });
      if (error) throw error;
      const r = data as { success: boolean; error?: string };
      if (r?.success) {
        toast.success(`${gift.emoji} Gift sent!`);
        setOpen(false);
      } else {
        toast.error(r?.error || 'Failed to send gift');
      }
    } catch (e: any) {
      toast.error(e?.message || 'Failed to send gift');
    } finally {
      setSending(null);
    }
  };

  const trigger = (() => {
    if (variant === 'control') {
      return (
        <button
          onClick={() => setOpen(true)}
          className={cn('flex flex-col items-center gap-1 p-3 rounded-full bg-white/10 transition-colors', className)}
          aria-label="Send gift"
        >
          <Gift className="w-6 h-6 text-white" />
          <span className="text-white/70 text-[10px]">Gift</span>
        </button>
      );
    }
    const sizeCls = variant === 'icon-md' ? 'h-9 w-9' : 'h-5 w-5';
    const iconCls = variant === 'icon-md' ? 'h-4 w-4' : 'h-2.5 w-2.5';
    return (
      <Button
        variant="ghost"
        size="icon"
        className={cn(sizeCls, 'text-pink-500 hover:text-pink-600', className)}
        onClick={(e) => { e.stopPropagation(); setOpen(true); }}
        title="Send gift"
        aria-label="Send gift"
      >
        <Gift className={iconCls} />
      </Button>
    );
  })();

  return (
    <>
      {trigger}
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Send a gift</DialogTitle>
            <DialogDescription>
              100% charged from your wallet. 50% credited to the recipient.
            </DialogDescription>
          </DialogHeader>
          <div className="grid grid-cols-3 gap-2 mt-2">
            {gifts.map((g) => (
              <button
                key={g.id}
                disabled={sending !== null}
                onClick={() => handleSend(g)}
                className={cn(
                  'flex flex-col items-center gap-1 p-3 rounded-lg border bg-card hover:bg-accent transition-colors',
                  sending === g.id && 'opacity-60'
                )}
              >
                <span className="text-3xl">{g.emoji}</span>
                <span className="text-xs font-medium text-foreground">{g.name}</span>
                <span className="text-[10px] text-muted-foreground font-semibold">₹{g.price}</span>
              </button>
            ))}
            {gifts.length === 0 && (
              <div className="col-span-3 text-center text-sm text-muted-foreground py-6">
                No gifts available
              </div>
            )}
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
};

export default SendGiftButton;
