
-- Remove seed group_call_charge rows
DELETE FROM public.wallet_transactions
WHERE transaction_type = 'group_call_charge'
  AND idempotency_key LIKE 'backfill_lt_%';

-- Remove orphan tip_charge rows whose recipient host is the placeholder UUID
DELETE FROM public.wallet_transactions t
WHERE t.transaction_type = 'tip_charge'
  AND NOT EXISTS (
    SELECT 1 FROM public.wallet_transactions e
    WHERE e.transaction_type = 'tip_earning'
      AND ABS(EXTRACT(EPOCH FROM (e.created_at - t.created_at))) < 5
      AND e.amount = ROUND(t.amount * 0.5, 2)
  );

-- Re-sync wallet balances
DO $$
DECLARE r record; v_sum numeric;
BEGIN
  FOR r IN SELECT DISTINCT user_id FROM public.wallet_transactions LOOP
    SELECT COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE -amount END), 0)
      INTO v_sum FROM public.wallet_transactions WHERE user_id = r.user_id;
    INSERT INTO public.wallets (user_id, balance, currency)
    VALUES (r.user_id, GREATEST(v_sum, 0), 'INR')
    ON CONFLICT (user_id) DO UPDATE SET balance = GREATEST(EXCLUDED.balance, 0);
  END LOOP;
END $$;
