
CREATE OR REPLACE FUNCTION public.validate_financial_sot()
RETURNS TABLE(check_name text, status text, details text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_neg int; v_null_idem int; v_unpaired int; v_bad_split int; v_legacy int;
BEGIN
  SELECT COUNT(*) INTO v_neg FROM public.wallet_transactions WHERE balance_after < 0;
  check_name:='no_negative_balances'; status:=CASE WHEN v_neg=0 THEN 'PASS' ELSE 'FAIL' END;
  details:='rows: '||v_neg; RETURN NEXT;

  SELECT COUNT(*) INTO v_null_idem FROM public.wallet_transactions WHERE idempotency_key IS NULL;
  check_name:='idempotency_keys_present'; status:=CASE WHEN v_null_idem=0 THEN 'PASS' ELSE 'FAIL' END;
  details:='null rows: '||v_null_idem; RETURN NEXT;

  SELECT COUNT(*) INTO v_unpaired
    FROM public.wallet_transactions c
   WHERE c.transaction_type='session_charge'
     AND c.created_at > now() - interval '30 days'
     AND NOT EXISTS (SELECT 1 FROM public.wallet_transactions e
       WHERE e.transaction_type='session_earning' AND e.session_id=c.session_id);
  check_name:='charge_earning_paired_30d'; status:=CASE WHEN v_unpaired=0 THEN 'PASS' ELSE 'WARN' END;
  details:='unpaired charges: '||v_unpaired; RETURN NEXT;

  -- 50% split applies only to 1:1 chat / audio / video, not group calls
  SELECT COUNT(*) INTO v_bad_split FROM (
    SELECT c.session_id,
      SUM(CASE WHEN transaction_type='session_charge'  THEN amount END) AS chg,
      SUM(CASE WHEN transaction_type='session_earning' THEN amount END) AS ern
    FROM public.wallet_transactions c
    WHERE transaction_type IN ('session_charge','session_earning')
      AND created_at > now() - interval '30 days'
      AND COALESCE(description,'') !~* '(group call|private group)'
    GROUP BY c.session_id
  ) s WHERE s.chg IS NOT NULL AND s.ern IS NOT NULL
      AND ABS(s.ern - s.chg/2.0) > 0.05;
  check_name:='rev_share_50pct_1to1_30d'; status:=CASE WHEN v_bad_split=0 THEN 'PASS' ELSE 'FAIL' END;
  details:='mismatched 1:1 sessions: '||v_bad_split; RETURN NEXT;

  v_legacy:=0;
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema='public' AND table_name='platform_ledger') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.platform_ledger WHERE created_at > now() - interval ''7 days''' INTO v_legacy;
  END IF;
  check_name:='no_legacy_ledger_writes_7d'; status:=CASE WHEN v_legacy=0 THEN 'PASS' ELSE 'FAIL' END;
  details:='legacy writes: '||v_legacy; RETURN NEXT;
END;
$$;
GRANT EXECUTE ON FUNCTION public.validate_financial_sot() TO authenticated, service_role;
