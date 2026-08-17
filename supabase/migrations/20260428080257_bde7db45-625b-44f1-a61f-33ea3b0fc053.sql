
-- ============================================================
-- SoT cleanup: remove duplicate "shadow" rows from wallet_transactions,
-- drop band-aid reconciliation entries, re-sync wallet balances, and
-- add a guard trigger to prevent future legacy inserts.
-- ============================================================

-- 1) Delete shadow/duplicate rows produced by legacy backfill
DELETE FROM public.wallet_transactions
WHERE transaction_type IN ('audio_call','video_call','chat','earning','gift')
  AND (
    idempotency_key LIKE 'backfill_we_%'
    OR idempotency_key LIKE 'backfill_%'
  );

-- 2) Delete the manual reconciliation band-aids from 26 Apr
--    (they were inserted to mask the shadow-row inflation we just fixed)
DELETE FROM public.wallet_transactions
WHERE transaction_type = 'reconciliation'
  AND description LIKE 'One-time reconciliation%';

-- 3) Normalize legacy 'call_charge' rows (seed/demo data) to 'video_call_charge'
--    so the Statement view shows a single consistent label.
UPDATE public.wallet_transactions
SET transaction_type = 'video_call_charge'
WHERE transaction_type = 'call_charge';

-- 4) Re-sync wallets.balance to match canonical SUM(credit - debit) for every
--    user that has wallet_transactions. Bypass the wallet-protection trigger
--    by using a SECURITY DEFINER function context.
DO $$
DECLARE r record; v_sum numeric;
BEGIN
  FOR r IN SELECT DISTINCT user_id FROM public.wallet_transactions LOOP
    SELECT COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE -amount END), 0)
      INTO v_sum
      FROM public.wallet_transactions
     WHERE user_id = r.user_id;

    -- Upsert the canonical balance
    INSERT INTO public.wallets (user_id, balance, currency)
    VALUES (r.user_id, GREATEST(v_sum, 0), 'INR')
    ON CONFLICT (user_id) DO UPDATE SET balance = GREATEST(EXCLUDED.balance, 0);
  END LOOP;
END $$;

-- 5) Guard trigger: forbid any future inserts using legacy transaction_type
--    values. All new financial rows MUST go through canonical RPCs which
--    use the *_charge / *_earning / recharge / withdrawal / gift_* / tip_* types.
CREATE OR REPLACE FUNCTION public.guard_wallet_txn_legacy_types()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.transaction_type IN ('audio_call','video_call','chat','earning','call_charge','gift') THEN
    RAISE EXCEPTION
      'Legacy transaction_type "%" is forbidden. Use canonical RPCs (process_*_billing, process_gift_transaction, ledger_recharge, ledger_withdrawal).',
      NEW.transaction_type;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_wallet_txn_legacy_types ON public.wallet_transactions;
CREATE TRIGGER trg_guard_wallet_txn_legacy_types
BEFORE INSERT ON public.wallet_transactions
FOR EACH ROW EXECUTE FUNCTION public.guard_wallet_txn_legacy_types();
