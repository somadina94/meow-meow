
-- 1. Remove the just-inserted backfill rows (transaction_type='reconciliation' or where reference_id originated from ledger_transactions)
DELETE FROM public.wallet_transactions 
WHERE transaction_type = 'reconciliation';

DELETE FROM public.wallet_transactions wt
WHERE wt.reference_id IN (SELECT reference_id FROM public.ledger_transactions WHERE reference_id IS NOT NULL)
  AND wt.created_at < now() + interval '1 hour'  -- safety
  AND wt.idempotency_key IS NULL;  -- only the just-backfilled rows have no idempotency_key

-- 2. Insert ONE reconciliation row per drifted wallet so SUM(wallet_transactions)=wallets.balance
INSERT INTO public.wallet_transactions
  (wallet_id, user_id, type, transaction_type, amount, description, status, created_at, balance_after)
SELECT
  w.id,
  w.user_id,
  CASE WHEN diff >= 0 THEN 'credit' ELSE 'debit' END,
  'reconciliation',
  ABS(diff),
  'One-time reconciliation: align statement total with current wallet balance after legacy ledger split',
  'completed',
  now(),
  w.balance
FROM (
  SELECT w.id, w.user_id, w.balance,
    ROUND(w.balance - COALESCE((SELECT SUM(amount) FROM public.wallet_transactions wt WHERE wt.user_id=w.user_id),0), 2) AS diff
  FROM public.wallets w
) w
WHERE diff <> 0;

-- 3. Recompute balance_after chronologically
WITH ranked AS (
  SELECT id, user_id, amount,
    SUM(amount) OVER (PARTITION BY user_id ORDER BY created_at, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running
  FROM public.wallet_transactions
)
UPDATE public.wallet_transactions wt
SET balance_after = r.running FROM ranked r WHERE wt.id = r.id;
