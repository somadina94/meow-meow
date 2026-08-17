
-- 0. Replace overly-strict session_type check constraint
ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_session_type_check;
ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_session_type_check
  CHECK (session_type IS NULL OR session_type = ANY (ARRAY[
    'chat','audio_call','video_call','group_call','private_call','group',
    'gift','tip','wallet','video'
  ]));

-- 1. Quarantine table for forensic recovery
CREATE TABLE IF NOT EXISTS public.wallet_transactions_purged_audit (
  id uuid PRIMARY KEY,
  wallet_id uuid,
  user_id uuid,
  type text,
  transaction_type text,
  amount numeric,
  description text,
  reference_id text,
  status text,
  created_at timestamptz,
  idempotency_key text,
  session_id uuid,
  session_type text,
  balance_after numeric,
  duration_seconds integer,
  rate_per_minute numeric,
  billing_metadata jsonb,
  purged_at timestamptz NOT NULL DEFAULT now(),
  purge_reason text NOT NULL
);
ALTER TABLE public.wallet_transactions_purged_audit ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "purge audit admin read" ON public.wallet_transactions_purged_audit;
CREATE POLICY "purge audit admin read" ON public.wallet_transactions_purged_audit
  FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- 2. Archive + delete phantom backfill:we:%  (exact mirrors of live earnings)
WITH archived AS (
  INSERT INTO public.wallet_transactions_purged_audit
    (id, wallet_id, user_id, type, transaction_type, amount, description, reference_id, status,
     created_at, idempotency_key, session_id, session_type, balance_after, duration_seconds,
     rate_per_minute, billing_metadata, purge_reason)
  SELECT id, wallet_id, user_id, type, transaction_type, amount, description, reference_id, status,
         created_at, idempotency_key, session_id, session_type, balance_after, duration_seconds,
         rate_per_minute, billing_metadata, 'phantom_duplicate_backfill_we'
  FROM public.wallet_transactions
  WHERE idempotency_key LIKE 'backfill:we:%'
  RETURNING id
)
DELETE FROM public.wallet_transactions WHERE id IN (SELECT id FROM archived);

-- 3. Archive + delete duplicate legacy chat_charge rows
WITH archived AS (
  INSERT INTO public.wallet_transactions_purged_audit
    (id, wallet_id, user_id, type, transaction_type, amount, description, reference_id, status,
     created_at, idempotency_key, session_id, session_type, balance_after, duration_seconds,
     rate_per_minute, billing_metadata, purge_reason)
  SELECT id, wallet_id, user_id, type, transaction_type, amount, description, reference_id, status,
         created_at, idempotency_key, session_id, session_type, balance_after, duration_seconds,
         rate_per_minute, billing_metadata, 'duplicate_legacy_chat_charge'
  FROM public.wallet_transactions
  WHERE idempotency_key LIKE 'legacy:%' AND transaction_type='chat_charge'
  RETURNING id
)
DELETE FROM public.wallet_transactions WHERE id IN (SELECT id FROM archived);

-- 4. Archive + delete duplicate legacy video_call_charge rows
WITH archived AS (
  INSERT INTO public.wallet_transactions_purged_audit
    (id, wallet_id, user_id, type, transaction_type, amount, description, reference_id, status,
     created_at, idempotency_key, session_id, session_type, balance_after, duration_seconds,
     rate_per_minute, billing_metadata, purge_reason)
  SELECT id, wallet_id, user_id, type, transaction_type, amount, description, reference_id, status,
         created_at, idempotency_key, session_id, session_type, balance_after, duration_seconds,
         rate_per_minute, billing_metadata, 'duplicate_legacy_video_charge'
  FROM public.wallet_transactions
  WHERE idempotency_key LIKE 'legacy:%' AND transaction_type='video_call_charge'
  RETURNING id
)
DELETE FROM public.wallet_transactions WHERE id IN (SELECT id FROM archived);

-- 5. Backfill session_type from transaction_type prefix
UPDATE public.wallet_transactions SET session_type='chat'
  WHERE session_type IS NULL AND transaction_type IN ('chat_charge','chat_earning');
UPDATE public.wallet_transactions SET session_type='audio_call'
  WHERE session_type IS NULL AND transaction_type IN ('audio_call_charge','audio_call_earning');
UPDATE public.wallet_transactions SET session_type='video_call'
  WHERE session_type IS NULL AND transaction_type IN ('video_call_charge','video_call_earning');
UPDATE public.wallet_transactions SET session_type='group_call'
  WHERE session_type IS NULL AND transaction_type IN ('group_call_charge','group_call_earning');
UPDATE public.wallet_transactions SET session_type='gift'
  WHERE session_type IS NULL AND transaction_type IN ('gift_charge','gift_earning');
UPDATE public.wallet_transactions SET session_type='tip'
  WHERE session_type IS NULL AND transaction_type IN ('tip_charge','tip_earning');
UPDATE public.wallet_transactions SET session_type='wallet'
  WHERE session_type IS NULL AND transaction_type IN ('recharge','withdrawal','opening_balance');

-- 6. Backfill session_id via text_to_uuid(reference_id) for billable sessions
UPDATE public.wallet_transactions
SET session_id = public.text_to_uuid(reference_id)
WHERE session_id IS NULL
  AND reference_id IS NOT NULL AND reference_id <> ''
  AND transaction_type IN (
    'chat_charge','chat_earning','audio_call_charge','audio_call_earning',
    'video_call_charge','video_call_earning','group_call_charge','group_call_earning',
    'gift_charge','gift_earning','tip_charge','tip_earning'
  );

-- 7. Resync wallet balances from cleaned ledger
WITH ledger AS (
  SELECT user_id,
    SUM(CASE WHEN type='credit' THEN amount ELSE -amount END) AS computed_balance
  FROM public.wallet_transactions GROUP BY user_id
)
UPDATE public.wallets w
SET balance = COALESCE(l.computed_balance, 0), updated_at = now()
FROM ledger l
WHERE w.user_id = l.user_id
  AND ABS(COALESCE(w.balance,0) - COALESCE(l.computed_balance,0)) > 0.01;

-- 8. Run validator
DO $$
DECLARE v jsonb;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname='validate_financial_sot') THEN
    SELECT public.validate_financial_sot() INTO v;
    RAISE NOTICE 'SoT validator post-cleanup: %', v;
  END IF;
END $$;
