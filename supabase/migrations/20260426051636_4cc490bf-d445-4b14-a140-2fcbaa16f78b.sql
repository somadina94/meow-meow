
-- ─── 1. Backfill missing legacy ledger rows into canonical ───
-- Map legacy transaction_type → canonical (type, transaction_type)
INSERT INTO public.wallet_transactions
  (id, user_id, type, transaction_type, amount, description, reference_id, status, created_at, session_id, session_type, balance_after, duration_seconds, rate_per_minute)
SELECT
  gen_random_uuid(),
  lt.user_id,
  CASE WHEN lt.credit > 0 THEN 'credit' ELSE 'debit' END AS type,
  CASE lt.transaction_type
    WHEN 'chat_charge' THEN 'chat_charge'
    WHEN 'chat_debit' THEN 'chat_charge'
    WHEN 'video_call_charge' THEN 'call_charge'
    WHEN 'audio_call_charge' THEN 'call_charge'
    WHEN 'group_call_charge' THEN 'group_charge'
    WHEN 'video_call_earning' THEN 'call_earning'
    WHEN 'audio_call_earning' THEN 'call_earning'
    WHEN 'earning' THEN 'chat_earning'
    WHEN 'recharge' THEN 'recharge'
    WHEN 'opening_balance' THEN 'opening_balance'
    WHEN 'tip_charge' THEN 'tip_charge'
    WHEN 'tip_earning' THEN 'tip_earning'
    ELSE lt.transaction_type
  END AS transaction_type,
  CASE WHEN lt.credit > 0 THEN lt.credit ELSE lt.debit END AS amount,
  COALESCE(lt.description, lt.transaction_type) AS description,
  lt.reference_id,
  'completed',
  lt.created_at,
  lt.session_id,
  CASE 
    WHEN lt.transaction_type ILIKE '%chat%' THEN 'chat'
    WHEN lt.transaction_type ILIKE '%video%' THEN 'video'
    WHEN lt.transaction_type ILIKE '%audio%' THEN 'audio'
    WHEN lt.transaction_type ILIKE '%group%' THEN 'group'
    WHEN lt.transaction_type ILIKE '%tip%' THEN 'group'
    ELSE NULL
  END,
  NULL,  -- balance_after will be recomputed below
  lt.duration_seconds,
  lt.rate_per_minute
FROM public.ledger_transactions lt
WHERE NOT EXISTS (
  SELECT 1 FROM public.wallet_transactions wt 
  WHERE wt.reference_id IS NOT NULL AND wt.reference_id = lt.reference_id
)
AND NOT EXISTS (
  -- Avoid duplicating rows already mirrored under different reference_id but matching session+type+amount+time
  SELECT 1 FROM public.wallet_transactions wt
  WHERE wt.user_id = lt.user_id
    AND wt.session_id IS NOT DISTINCT FROM lt.session_id
    AND wt.amount = (CASE WHEN lt.credit > 0 THEN lt.credit ELSE lt.debit END)
    AND ABS(EXTRACT(EPOCH FROM (wt.created_at - lt.created_at))) < 5
);

-- ─── 2. Reconcile drifted wallets so SUM(wallet_transactions) = wallets.balance ───
-- For each wallet where there is drift, insert a single adjustment row to align.
INSERT INTO public.wallet_transactions
  (id, wallet_id, user_id, type, transaction_type, amount, description, status, created_at, balance_after)
SELECT
  gen_random_uuid(),
  w.id,
  w.user_id,
  CASE WHEN (w.balance - wt_sum) >= 0 THEN 'credit' ELSE 'debit' END,
  'reconciliation',
  ABS(ROUND(w.balance - wt_sum, 2)),
  'Reconciliation adjustment to match canonical wallet balance (post legacy-ledger backfill)',
  'completed',
  now(),
  w.balance
FROM (
  SELECT w.id, w.user_id, w.balance,
    COALESCE((SELECT SUM(amount) FROM public.wallet_transactions wt WHERE wt.user_id = w.user_id), 0) AS wt_sum
  FROM public.wallets w
) w
WHERE ROUND(w.balance::numeric, 2) <> ROUND(w.wt_sum::numeric, 2);

-- ─── 3. Recompute balance_after for all wallet_transactions in chronological order ───
WITH ranked AS (
  SELECT id, user_id, amount,
    SUM(amount) OVER (
      PARTITION BY user_id 
      ORDER BY created_at, id 
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running
  FROM public.wallet_transactions
)
UPDATE public.wallet_transactions wt
SET balance_after = r.running
FROM ranked r
WHERE wt.id = r.id;
