-- Allow service_role to update ledger transactions (needed for backfill)
CREATE POLICY "_temp_backfill_update" ON public.ledger_transactions
  FOR UPDATE TO service_role USING (true) WITH CHECK (true);

UPDATE public.ledger_transactions SET transaction_type='chat_earning'
 WHERE transaction_type='earning' AND description ILIKE 'Chat earning%';

UPDATE public.ledger_transactions SET transaction_type='video_call_earning'
 WHERE transaction_type='earning' AND description ILIKE 'Video earning%';

UPDATE public.ledger_transactions SET transaction_type='group_call_earning'
 WHERE transaction_type='earning' AND description ILIKE 'Group call earning%';

DROP POLICY "_temp_backfill_update" ON public.ledger_transactions;