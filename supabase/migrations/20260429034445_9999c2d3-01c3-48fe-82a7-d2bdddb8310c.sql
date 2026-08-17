
-- Identify make-whole credits whose source charge had NULL session_id (already credited originally)
WITH bad AS (
  SELECT mw.id
  FROM public.wallet_transactions mw
  JOIN public.wallet_transactions vc
    ON vc.id::text = REPLACE(mw.idempotency_key, 'video_makewhole:', '')
  WHERE mw.idempotency_key LIKE 'video_makewhole:%'
    AND vc.session_id IS NULL
),
archived AS (
  INSERT INTO public.wallet_transactions_purged_audit
    (id, wallet_id, user_id, type, transaction_type, amount, description, reference_id, status,
     created_at, idempotency_key, session_id, session_type, balance_after, duration_seconds,
     rate_per_minute, billing_metadata, purge_reason)
  SELECT id, wallet_id, user_id, type, transaction_type, amount, description, reference_id, status,
         created_at, idempotency_key, session_id, session_type, balance_after, duration_seconds,
         rate_per_minute, billing_metadata, 'over_credit_makewhole_already_paid'
  FROM public.wallet_transactions
  WHERE id IN (SELECT id FROM bad)
  RETURNING id
)
DELETE FROM public.wallet_transactions WHERE id IN (SELECT id FROM archived);

-- Resync woman's wallet
WITH ledger AS (
  SELECT user_id, SUM(CASE WHEN type='credit' THEN amount ELSE -amount END) AS lsum
  FROM public.wallet_transactions GROUP BY user_id
)
UPDATE public.wallets w
SET balance = COALESCE(l.lsum,0), updated_at=now()
FROM ledger l
WHERE w.user_id = l.user_id
  AND ABS(COALESCE(w.balance,0) - COALESCE(l.lsum,0)) > 0.01;

DO $$
DECLARE v jsonb;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname='validate_financial_sot') THEN
    SELECT public.validate_financial_sot() INTO v;
    RAISE NOTICE 'SoT validator final: %', v;
  END IF;
END $$;
