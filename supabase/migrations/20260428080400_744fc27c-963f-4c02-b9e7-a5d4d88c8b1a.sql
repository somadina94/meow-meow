
-- Remove group_charge shadow duplicates of group_call_charge
DELETE FROM public.wallet_transactions
WHERE transaction_type = 'group_charge'
  AND (idempotency_key LIKE 'backfill_%' OR idempotency_key IS NULL);

-- Extend the guard trigger to also block 'group_charge' legacy type
CREATE OR REPLACE FUNCTION public.guard_wallet_txn_legacy_types()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.transaction_type IN ('audio_call','video_call','chat','earning','call_charge','gift','group_charge') THEN
    RAISE EXCEPTION
      'Legacy transaction_type "%" is forbidden. Use canonical RPCs (process_*_billing, process_gift_transaction, ledger_recharge, ledger_withdrawal).',
      NEW.transaction_type;
  END IF;
  RETURN NEW;
END;
$$;

-- One-time opening balance credit for the woman whose historical earnings
-- lived only in deleted shadow rows. Aligns her statement with wallet balance.
INSERT INTO public.wallet_transactions (
  user_id, type, amount, transaction_type, description, idempotency_key, created_at
)
SELECT
  '04cad57a-2647-457e-beb4-9a5c60fbbe44'::uuid,
  'credit',
  786.50,
  'opening_balance',
  'Opening balance reconciliation (historical earnings prior to SoT cleanup)',
  'opening_balance:04cad57a-2647-457e-beb4-9a5c60fbbe44:2026-04-28',
  '2026-01-01 00:00:00+00'
WHERE NOT EXISTS (
  SELECT 1 FROM public.wallet_transactions
  WHERE idempotency_key = 'opening_balance:04cad57a-2647-457e-beb4-9a5c60fbbe44:2026-04-28'
);

-- Re-sync wallets.balance one more time
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
