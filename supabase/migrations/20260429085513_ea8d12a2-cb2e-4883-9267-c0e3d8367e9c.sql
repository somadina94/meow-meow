CREATE OR REPLACE FUNCTION public.simulate_group_call_billing(
  p_man_id   uuid DEFAULT NULL,
  p_woman_id uuid DEFAULT NULL,
  p_minutes  integer DEFAULT 5
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pricing        jsonb;
  v_man_rate       numeric(10,2);
  v_woman_rate     numeric(10,2);
  v_man_id         uuid := p_man_id;
  v_woman_id       uuid := p_woman_id;
  v_session_id     uuid := gen_random_uuid();
  v_expected_debit  numeric(10,2);
  v_expected_credit numeric(10,2);
  v_man_bal_before  numeric(10,2);
  v_woman_bal_before numeric(10,2);
  v_man_bal_after   numeric(10,2);
  v_woman_bal_after numeric(10,2);
  v_actual_debit    numeric(10,2);
  v_actual_credit   numeric(10,2);
  v_debit_rows      integer;
  v_credit_rows     integer;
  v_stmt_rows       integer;
  v_results         jsonb := '[]'::jsonb;
  v_minute          integer;
  v_call_result     jsonb;
  v_call_log        jsonb := '[]'::jsonb;
BEGIN
  -- Admin gate
  IF NOT public.has_role(auth.uid(), 'admin'::app_role) THEN
    RAISE EXCEPTION 'Access denied: admin role required';
  END IF;

  IF p_minutes < 1 OR p_minutes > 30 THEN
    RAISE EXCEPTION 'p_minutes must be between 1 and 30';
  END IF;

  -- Auto-pick a man with balance ≥ required if not provided
  v_pricing    := public.get_unified_pricing();
  v_man_rate   := (v_pricing->>'group_man_rate')::numeric;
  v_woman_rate := (v_pricing->>'group_woman_rate')::numeric;
  v_expected_debit  := ROUND(v_man_rate   * p_minutes, 2);
  v_expected_credit := ROUND(v_woman_rate * p_minutes, 2);

  IF v_man_id IS NULL THEN
    SELECT p.id INTO v_man_id
    FROM public.profiles p
    JOIN public.wallets w ON w.user_id = p.id
    WHERE p.gender = 'male' AND w.balance >= v_expected_debit
    ORDER BY w.balance DESC
    LIMIT 1;
  END IF;

  IF v_woman_id IS NULL THEN
    SELECT p.id INTO v_woman_id
    FROM public.profiles p
    WHERE p.gender = 'female'
    ORDER BY p.created_at ASC
    LIMIT 1;
  END IF;

  IF v_man_id IS NULL OR v_woman_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error',   'Could not auto-pick man or woman host',
      'man_id',  v_man_id,
      'woman_id',v_woman_id
    );
  END IF;

  -- Snapshot wallets BEFORE
  SELECT balance INTO v_man_bal_before  FROM public.wallets WHERE user_id = v_man_id;
  SELECT balance INTO v_woman_bal_before FROM public.wallets WHERE user_id = v_woman_id;

  -- Run p_minutes calls through canonical billing RPC
  FOR v_minute IN 0 .. p_minutes - 1 LOOP
    SELECT public.bill_session_minute(
      v_session_id, 'private_group_call', 1.0,
      v_man_id, v_woman_id, 1, v_minute
    ) INTO v_call_result;
    v_call_log := v_call_log || jsonb_build_array(
      jsonb_build_object('minute', v_minute, 'result', v_call_result)
    );
  END LOOP;

  -- Snapshot wallets AFTER
  SELECT balance INTO v_man_bal_after  FROM public.wallets WHERE user_id = v_man_id;
  SELECT balance INTO v_woman_bal_after FROM public.wallets WHERE user_id = v_woman_id;

  -- Verify wallet_transactions
  SELECT COALESCE(SUM(amount),0), COUNT(*)
    INTO v_actual_debit, v_debit_rows
  FROM public.wallet_transactions
  WHERE session_id   = v_session_id
    AND session_type = 'private_group_call'
    AND user_id      = v_man_id
    AND type         = 'debit';

  SELECT COALESCE(SUM(amount),0), COUNT(*)
    INTO v_actual_credit, v_credit_rows
  FROM public.wallet_transactions
  WHERE session_id   = v_session_id
    AND session_type = 'private_group_call'
    AND user_id      = v_woman_id
    AND type         = 'credit';

  -- Verify statement view picks the rows up
  SELECT COUNT(*) INTO v_stmt_rows
  FROM public.wallet_transactions
  WHERE session_id = v_session_id;

  -- Build per-check pass/fail array
  v_results := jsonb_build_array(
    jsonb_build_object('check','man_debit_rows',     'expected', p_minutes,        'actual', v_debit_rows,     'pass', v_debit_rows  = p_minutes),
    jsonb_build_object('check','woman_credit_rows',  'expected', p_minutes,        'actual', v_credit_rows,    'pass', v_credit_rows = p_minutes),
    jsonb_build_object('check','man_total_debit',    'expected', v_expected_debit, 'actual', v_actual_debit,   'pass', v_actual_debit  = v_expected_debit),
    jsonb_build_object('check','woman_total_credit', 'expected', v_expected_credit,'actual', v_actual_credit,  'pass', v_actual_credit = v_expected_credit),
    jsonb_build_object('check','man_balance_delta',  'expected', v_expected_debit, 'actual', v_man_bal_before  - v_man_bal_after,  'pass', (v_man_bal_before  - v_man_bal_after)  = v_expected_debit),
    jsonb_build_object('check','woman_balance_delta','expected', v_expected_credit,'actual', v_woman_bal_after - v_woman_bal_before,'pass', (v_woman_bal_after - v_woman_bal_before) = v_expected_credit),
    jsonb_build_object('check','statement_visibility','expected', p_minutes * 2,   'actual', v_stmt_rows,      'pass', v_stmt_rows = p_minutes * 2)
  );

  RETURN jsonb_build_object(
    'success',           true,
    'session_id',        v_session_id,
    'minutes',           p_minutes,
    'man_id',            v_man_id,
    'woman_id',          v_woman_id,
    'pricing', jsonb_build_object(
      'group_man_rate',   v_man_rate,
      'group_woman_rate', v_woman_rate
    ),
    'man_balance_before',  v_man_bal_before,
    'man_balance_after',   v_man_bal_after,
    'woman_balance_before',v_woman_bal_before,
    'woman_balance_after', v_woman_bal_after,
    'expected_debit',      v_expected_debit,
    'expected_credit',     v_expected_credit,
    'actual_debit',        v_actual_debit,
    'actual_credit',       v_actual_credit,
    'checks',              v_results,
    'all_passed', NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_results) e WHERE (e->>'pass')::boolean = false
    ),
    'call_log',            v_call_log
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.simulate_group_call_billing(uuid,uuid,integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.simulate_group_call_billing(uuid,uuid,integer) TO authenticated, service_role;