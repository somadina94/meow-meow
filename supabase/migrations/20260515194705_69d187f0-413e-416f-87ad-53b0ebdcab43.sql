ALTER TABLE public.women_payout_snapshots
  DROP CONSTRAINT IF EXISTS women_payout_snapshots_payment_status_check;

ALTER TABLE public.women_payout_snapshots
  ADD CONSTRAINT women_payout_snapshots_payment_status_check
  CHECK (payment_status = ANY (ARRAY['pending'::text, 'processed'::text, 'failed'::text, 'no_balance'::text]));