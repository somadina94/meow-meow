
-- 1. Remove the incorrect reconciliation rows
DELETE FROM public.wallet_transactions WHERE transaction_type = 'reconciliation';

-- 2. Reconcile using SIGNED sum (credit positive, debit negative)
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
    ROUND(w.balance - COALESCE((
      SELECT SUM(CASE WHEN type='credit' THEN amount ELSE -amount END)
      FROM public.wallet_transactions wt WHERE wt.user_id=w.user_id
    ), 0), 2) AS diff
  FROM public.wallets w
) w
WHERE diff <> 0;

-- 3. Recompute balance_after using SIGNED sum
WITH ranked AS (
  SELECT id, user_id,
    SUM(CASE WHEN type='credit' THEN amount ELSE -amount END) OVER (
      PARTITION BY user_id 
      ORDER BY created_at, id 
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running
  FROM public.wallet_transactions
)
UPDATE public.wallet_transactions wt
SET balance_after = r.running FROM ranked r WHERE wt.id = r.id;
