
CREATE OR REPLACE FUNCTION public.validate_financial_sot()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_checks jsonb := '[]'::jsonb;
  v_ok boolean := true;
  v_count int;
  v_exists boolean;
  v_blocked boolean;
  v_mismatch_users jsonb;
  v_legacy_rpcs jsonb;
BEGIN
  -- 1) No duplicate / shadow rows
  SELECT COUNT(*) INTO v_count
  FROM public.wallet_transactions
  WHERE transaction_type IN
    ('audio_call','video_call','chat','earning','call_charge','gift','group_charge');

  v_checks := v_checks || jsonb_build_object(
    'name','no_shadow_rows',
    'pass', v_count = 0,
    'detail', jsonb_build_object('shadow_row_count', v_count)
  );
  IF v_count <> 0 THEN v_ok := false; END IF;

  -- 2) Guard trigger present
  SELECT EXISTS(
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_guard_wallet_txn_legacy_types'
      AND NOT tgisinternal
  ) INTO v_exists;

  v_checks := v_checks || jsonb_build_object(
    'name','guard_trigger_present',
    'pass', v_exists,
    'detail', jsonb_build_object('trigger', 'trg_guard_wallet_txn_legacy_types')
  );
  IF NOT v_exists THEN v_ok := false; END IF;

  -- 3) Live forbidden-insert test (savepoint, must raise)
  v_blocked := false;
  BEGIN
    BEGIN
      INSERT INTO public.wallet_transactions
        (user_id, type, amount, transaction_type, description, idempotency_key)
      VALUES
        ('00000000-0000-0000-0000-000000000000'::uuid, 'credit', 0.01,
         'audio_call', 'sot-validator-probe',
         'sot_probe:' || extract(epoch from now())::text);
    EXCEPTION WHEN OTHERS THEN
      v_blocked := true;
    END;
    -- if it somehow inserted, undo it
    IF NOT v_blocked THEN
      DELETE FROM public.wallet_transactions
      WHERE description = 'sot-validator-probe';
    END IF;
  END;

  v_checks := v_checks || jsonb_build_object(
    'name','forbidden_insert_blocked',
    'pass', v_blocked,
    'detail', jsonb_build_object('probe_type','audio_call')
  );
  IF NOT v_blocked THEN v_ok := false; END IF;

  -- 4) Wallet balance ↔ ledger reconciliation
  WITH sums AS (
    SELECT user_id,
      SUM(CASE WHEN type='credit' THEN amount ELSE -amount END) AS s
    FROM public.wallet_transactions GROUP BY user_id
  ),
  diffs AS (
    SELECT w.user_id,
      w.balance,
      COALESCE(s.s, 0) AS sum_txn,
      ROUND(w.balance - COALESCE(s.s,0), 2) AS diff
    FROM public.wallets w
    LEFT JOIN sums s USING (user_id)
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'user_id', user_id, 'balance', balance, 'sum_txn', sum_txn, 'diff', diff
  )), '[]'::jsonb)
  INTO v_mismatch_users
  FROM diffs WHERE ABS(diff) > 0.01;

  v_checks := v_checks || jsonb_build_object(
    'name','wallet_balance_reconciled',
    'pass', jsonb_array_length(v_mismatch_users) = 0,
    'detail', jsonb_build_object(
      'mismatch_count', jsonb_array_length(v_mismatch_users),
      'mismatched', v_mismatch_users
    )
  );
  IF jsonb_array_length(v_mismatch_users) <> 0 THEN v_ok := false; END IF;

  -- 5) Forbidden RPCs must not exist
  SELECT COALESCE(jsonb_agg(proname::text), '[]'::jsonb)
  INTO v_legacy_rpcs
  FROM pg_proc
  WHERE pronamespace = 'public'::regnamespace
    AND proname IN ('process_video_billing','process_wallet_transaction','process_group_billing');

  v_checks := v_checks || jsonb_build_object(
    'name','forbidden_rpcs_absent',
    'pass', jsonb_array_length(v_legacy_rpcs) = 0,
    'detail', jsonb_build_object('found', v_legacy_rpcs)
  );
  IF jsonb_array_length(v_legacy_rpcs) <> 0 THEN v_ok := false; END IF;

  RETURN jsonb_build_object(
    'ok', v_ok,
    'checked_at', now(),
    'checks', v_checks
  );
END;
$$;

REVOKE ALL ON FUNCTION public.validate_financial_sot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_financial_sot() TO authenticated, service_role;
