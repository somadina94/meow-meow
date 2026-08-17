-- 1. Recompute running totals for the user with the 4 negative balance_after rows
WITH running AS (
  SELECT id,
    SUM(CASE
      WHEN transaction_type IN ('recharge','reconciliation','chat_earning','audio_call_earning','video_call_earning','tip_earning') THEN amount
      WHEN transaction_type IN ('chat_charge','audio_call_charge','video_call_charge','group_charge','call_charge','tip_charge') THEN -amount
      ELSE 0
    END) OVER (PARTITION BY user_id ORDER BY created_at, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS new_balance
  FROM wallet_transactions
  WHERE user_id = '0b933372-7f04-4397-9aae-0e8be4730702'
)
UPDATE wallet_transactions wt
SET balance_after = GREATEST(running.new_balance, 0)
FROM running
WHERE wt.id = running.id;

-- 2. Hard-resync wallets.balance to match the canonical ledger (defensive)
WITH ledger_totals AS (
  SELECT user_id,
    SUM(CASE
      WHEN transaction_type IN ('recharge','reconciliation','chat_earning','audio_call_earning','video_call_earning','tip_earning') THEN amount
      WHEN transaction_type IN ('chat_charge','audio_call_charge','video_call_charge','group_charge','call_charge','tip_charge') THEN -amount
      ELSE 0
    END) AS computed_balance
  FROM wallet_transactions
  GROUP BY user_id
)
UPDATE wallets w
SET balance = GREATEST(lt.computed_balance, 0), updated_at = NOW()
FROM ledger_totals lt
WHERE w.user_id = lt.user_id
  AND ABS(w.balance - GREATEST(lt.computed_balance, 0)) > 0.01;

-- 3. Add CHECK constraint to enforce spec rule going forward
ALTER TABLE public.wallet_transactions
  DROP CONSTRAINT IF EXISTS wallet_tx_balance_after_nonneg;
ALTER TABLE public.wallet_transactions
  ADD CONSTRAINT wallet_tx_balance_after_nonneg
  CHECK (balance_after >= 0);