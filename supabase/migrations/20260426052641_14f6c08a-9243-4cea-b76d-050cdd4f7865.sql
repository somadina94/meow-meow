-- 1. Close stale active chat sessions
UPDATE active_chat_sessions
SET status = 'ended', ended_at = COALESCE(ended_at, now()), end_reason = COALESCE(end_reason, 'auto_close_stale')
WHERE status = 'active' AND last_activity_at < now() - interval '30 minutes';

-- 2. Rebuild balance_after running totals using correct signed logic
WITH ordered AS (
  SELECT id, user_id, created_at, amount, transaction_type,
    CASE 
      WHEN transaction_type IN ('recharge','reconciliation','chat_earning','audio_call_earning','video_call_earning','tip_earning','refund','reconciliation_credit') THEN amount
      WHEN transaction_type IN ('chat_charge','audio_call_charge','video_call_charge','call_charge','group_charge','tip_charge','reconciliation_debit') THEN -amount
      ELSE 0
    END AS signed_amt
  FROM wallet_transactions
),
running AS (
  SELECT id, user_id,
    SUM(signed_amt) OVER (PARTITION BY user_id ORDER BY created_at, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS bal_after
  FROM ordered
)
UPDATE wallet_transactions wt
SET balance_after = running.bal_after
FROM running
WHERE wt.id = running.id;

-- 3. Hard re-sync wallets.balance to canonical sum
WITH canonical AS (
  SELECT user_id,
    SUM(CASE 
      WHEN transaction_type IN ('recharge','reconciliation','chat_earning','audio_call_earning','video_call_earning','tip_earning','refund','reconciliation_credit') THEN amount
      WHEN transaction_type IN ('chat_charge','audio_call_charge','video_call_charge','call_charge','group_charge','tip_charge','reconciliation_debit') THEN -amount
      ELSE 0
    END) AS total
  FROM wallet_transactions GROUP BY user_id
)
UPDATE wallets w
SET balance = c.total, updated_at = now()
FROM canonical c
WHERE w.user_id = c.user_id AND ABS(w.balance - c.total) > 0.01;