
-- Fix get_my_statement_summary to use IST timezone for period boundaries
CREATE OR REPLACE FUNCTION public.get_my_statement_summary(p_year integer, p_month integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id         uuid := auth.uid();
  v_gender          text;
  v_period_start    timestamptz;
  v_period_end      timestamptz;
  v_opening_balance numeric(12,2) := 0;
  v_total_debit     numeric(12,2) := 0;
  v_total_credit    numeric(12,2) := 0;
  v_closing_balance numeric(12,2);
  v_wallet_balance  numeric(12,2);
  v_six_months_ago  timestamptz;
  v_is_current_month boolean;
BEGIN
  IF v_user_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Not authenticated'); END IF;

  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = v_user_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Profile not found'); END IF;

  -- Use IST (Asia/Kolkata) for period boundaries per spec
  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'Asia/Kolkata');
  v_period_end   := v_period_start + interval '1 month';
  v_is_current_month := (date_trunc('month', now() AT TIME ZONE 'Asia/Kolkata') = date_trunc('month', v_period_start AT TIME ZONE 'Asia/Kolkata'));

  v_six_months_ago := date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata') - interval '5 months');
  IF (v_period_start AT TIME ZONE 'Asia/Kolkata') < v_six_months_ago THEN
    RETURN jsonb_build_object('success', false, 'error', 'Statements are available for the last 6 months only');
  END IF;

  -- Current period totals from ALL sources with per-row dedup
  SELECT COALESCE(SUM(dr), 0), COALESCE(SUM(cr), 0)
  INTO v_total_debit, v_total_credit
  FROM (
    SELECT debit as dr, credit as cr FROM public.ledger_transactions
    WHERE user_id = v_user_id AND created_at >= v_period_start AND created_at < v_period_end

    UNION ALL
    SELECT
      CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END,
      CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END
    FROM public.wallet_transactions wt
    WHERE wt.user_id = v_user_id AND wt.created_at >= v_period_start AND wt.created_at < v_period_end AND wt.status = 'completed'
      AND NOT EXISTS (
        SELECT 1 FROM public.ledger_transactions lt
        WHERE lt.user_id = v_user_id AND lt.reference_id = wt.idempotency_key
          AND wt.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.ledger_transactions lt
        WHERE lt.user_id = v_user_id
          AND wt.session_id IS NOT NULL AND lt.session_id IS NOT NULL
          AND lt.session_id::text = wt.session_id::text
          AND lt.debit = (CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END)
          AND lt.credit = (CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END)
          AND ABS(EXTRACT(EPOCH FROM (lt.created_at - wt.created_at))) < 120
      )

    UNION ALL
    SELECT pl.debit, pl.credit FROM public.platform_ledger pl
    WHERE pl.user_id = v_user_id AND pl.created_at_ist >= v_period_start AND pl.created_at_ist < v_period_end
      AND NOT EXISTS (
        SELECT 1 FROM public.wallet_transactions wt
        WHERE wt.user_id = v_user_id AND wt.idempotency_key = pl.idempotency_key
          AND pl.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.ledger_transactions lt
        WHERE lt.user_id = v_user_id AND lt.reference_id = pl.idempotency_key
          AND pl.idempotency_key IS NOT NULL
      )

    UNION ALL
    SELECT 0, we.amount FROM public.women_earnings we
    WHERE we.user_id = v_user_id AND we.created_at >= v_period_start AND we.created_at < v_period_end
      AND v_gender = 'female'
      AND NOT EXISTS (
        SELECT 1 FROM public.wallet_transactions wt
        WHERE wt.user_id = v_user_id AND wt.idempotency_key = we.idempotency_key
          AND we.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.platform_ledger pl
        WHERE pl.user_id = v_user_id AND pl.idempotency_key = we.idempotency_key
          AND we.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.ledger_transactions lt
        WHERE lt.user_id = v_user_id AND lt.transaction_type = 'earning'
          AND lt.credit = we.amount
          AND COALESCE(we.chat_session_id, we.video_session_id, we.group_id, we.private_call_id) IS NOT NULL
          AND lt.session_id IS NOT NULL
          AND lt.session_id::text = COALESCE(we.chat_session_id, we.video_session_id, we.group_id, we.private_call_id)::text
          AND ABS(EXTRACT(EPOCH FROM (lt.created_at - we.created_at))) < 120
      )
  ) combined;

  -- For current month, anchor to wallet balance
  IF v_is_current_month THEN
    SELECT COALESCE(w.balance, 0) INTO v_wallet_balance FROM public.wallets w WHERE w.user_id = v_user_id;
    IF v_wallet_balance IS NULL THEN v_wallet_balance := 0; END IF;
    v_closing_balance := v_wallet_balance;
    v_opening_balance := v_closing_balance - v_total_credit + v_total_debit;
  ELSE
    SELECT COALESCE(SUM(cr - dr), 0) INTO v_opening_balance
    FROM (
      SELECT credit as cr, debit as dr FROM public.ledger_transactions
      WHERE user_id = v_user_id AND created_at < v_period_start
      UNION ALL
      SELECT
        CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END,
        CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END
      FROM public.wallet_transactions wt
      WHERE wt.user_id = v_user_id AND wt.created_at < v_period_start AND wt.status = 'completed'
        AND NOT EXISTS (
          SELECT 1 FROM public.ledger_transactions lt
          WHERE lt.user_id = v_user_id AND lt.reference_id = wt.idempotency_key
            AND wt.idempotency_key IS NOT NULL
        )
      UNION ALL
      SELECT pl.credit, pl.debit FROM public.platform_ledger pl
      WHERE pl.user_id = v_user_id AND pl.created_at_ist < v_period_start
        AND NOT EXISTS (
          SELECT 1 FROM public.ledger_transactions lt
          WHERE lt.user_id = v_user_id AND lt.reference_id = pl.idempotency_key
            AND pl.idempotency_key IS NOT NULL
        )
      UNION ALL
      SELECT we.amount, 0 FROM public.women_earnings we
      WHERE we.user_id = v_user_id AND we.created_at < v_period_start
        AND v_gender = 'female'
        AND NOT EXISTS (
          SELECT 1 FROM public.ledger_transactions lt
          WHERE lt.user_id = v_user_id AND lt.transaction_type = 'earning'
            AND lt.credit = we.amount
            AND COALESCE(we.chat_session_id, we.video_session_id, we.group_id, we.private_call_id) IS NOT NULL
            AND lt.session_id IS NOT NULL
            AND lt.session_id::text = COALESCE(we.chat_session_id, we.video_session_id, we.group_id, we.private_call_id)::text
            AND ABS(EXTRACT(EPOCH FROM (lt.created_at - we.created_at))) < 120
        )
    ) combined;
    IF v_gender = 'male' AND v_opening_balance < 0 THEN v_opening_balance := 0; END IF;
    v_closing_balance := v_opening_balance + v_total_credit - v_total_debit;
    IF v_gender = 'male' AND v_closing_balance < 0 THEN v_closing_balance := 0; END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'gender', v_gender, 'year', p_year, 'month', p_month,
    'opening_balance', v_opening_balance, 'total_debit', v_total_debit,
    'total_credit', v_total_credit, 'closing_balance', v_closing_balance);
END;
$$;

-- Fix get_my_statement_detail to use IST timezone for period boundaries
CREATE OR REPLACE FUNCTION public.get_my_statement_detail(p_year integer, p_month integer)
RETURNS TABLE(
  txn_date timestamptz, transaction_id text, session_id text,
  txn_type text, description text, duration_seconds integer, rate_per_minute numeric,
  debit numeric, credit numeric, running_balance numeric,
  start_time timestamptz, end_time timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_user_id        uuid := auth.uid();
  v_gender         text;
  v_period_start   timestamptz;
  v_period_end     timestamptz;
  v_opening        numeric(12,2) := 0;
  v_six_months_ago timestamptz;
  v_wallet_balance numeric(12,2);
  v_total_credit   numeric(12,2);
  v_total_debit    numeric(12,2);
  v_is_current_month boolean;
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  SELECT p.gender INTO v_gender FROM public.profiles p WHERE p.user_id = v_user_id;

  -- Use IST (Asia/Kolkata) for period boundaries per spec
  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'Asia/Kolkata');
  v_period_end   := v_period_start + interval '1 month';
  v_is_current_month := (date_trunc('month', now() AT TIME ZONE 'Asia/Kolkata') = date_trunc('month', v_period_start AT TIME ZONE 'Asia/Kolkata'));

  v_six_months_ago := date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata') - interval '5 months');
  IF (v_period_start AT TIME ZONE 'Asia/Kolkata') < v_six_months_ago THEN RETURN; END IF;

  -- Temp table for statement rows
  CREATE TEMP TABLE IF NOT EXISTS _stmt_rows (
    row_num serial, txn_date timestamptz, transaction_id text, session_id text,
    txn_type text, description text, duration_seconds integer, rate_per_minute numeric,
    debit numeric NOT NULL DEFAULT 0, credit numeric NOT NULL DEFAULT 0,
    start_time timestamptz, end_time timestamptz
  ) ON COMMIT DROP;
  TRUNCATE _stmt_rows;

  -- 1) Ledger transactions (primary source)
  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit, start_time, end_time)
  SELECT lt.created_at, lt.id::text, lt.session_id::text,
    lt.transaction_type, lt.description, lt.duration_seconds, lt.rate_per_minute,
    lt.debit, lt.credit,
    CASE WHEN lt.duration_seconds IS NOT NULL AND lt.duration_seconds > 0
      THEN lt.created_at - (lt.duration_seconds * interval '1 second')
      ELSE NULL END,
    CASE WHEN lt.duration_seconds IS NOT NULL AND lt.duration_seconds > 0
      THEN lt.created_at ELSE NULL END
  FROM public.ledger_transactions lt
  WHERE lt.user_id = v_user_id AND lt.created_at >= v_period_start AND lt.created_at < v_period_end
  ORDER BY lt.created_at, lt.id;

  -- 2) Wallet transactions (deduplicated against ledger)
  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit, start_time, end_time)
  SELECT wt.created_at, wt.id::text, wt.session_id::text,
    COALESCE(wt.transaction_type, wt.type), wt.description, wt.duration_seconds, wt.rate_per_minute,
    CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END,
    CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END,
    CASE WHEN wt.duration_seconds IS NOT NULL AND wt.duration_seconds > 0
      THEN wt.created_at - (wt.duration_seconds * interval '1 second')
      ELSE NULL END,
    CASE WHEN wt.duration_seconds IS NOT NULL AND wt.duration_seconds > 0
      THEN wt.created_at ELSE NULL END
  FROM public.wallet_transactions wt
  WHERE wt.user_id = v_user_id AND wt.created_at >= v_period_start AND wt.created_at < v_period_end AND wt.status = 'completed'
    AND NOT EXISTS (
      SELECT 1 FROM public.ledger_transactions lt
      WHERE lt.user_id = v_user_id AND lt.reference_id = wt.idempotency_key
        AND wt.idempotency_key IS NOT NULL
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.ledger_transactions lt
      WHERE lt.user_id = v_user_id
        AND wt.session_id IS NOT NULL AND lt.session_id IS NOT NULL
        AND lt.session_id::text = wt.session_id::text
        AND lt.debit = (CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END)
        AND lt.credit = (CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END)
        AND ABS(EXTRACT(EPOCH FROM (lt.created_at - wt.created_at))) < 120
    )
  ORDER BY wt.created_at, wt.id;

  -- 3) Platform ledger (deduplicated)
  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit, start_time, end_time)
  SELECT pl.created_at_ist, pl.id::text, pl.session_id::text,
    pl.entry_type, pl.description,
    CASE WHEN pl.duration_minutes IS NOT NULL THEN (pl.duration_minutes * 60)::integer ELSE NULL END,
    pl.rate_per_unit,
    pl.debit, pl.credit,
    CASE WHEN pl.duration_minutes IS NOT NULL AND pl.duration_minutes > 0
      THEN pl.created_at_ist - (pl.duration_minutes * interval '1 minute')
      ELSE NULL END,
    CASE WHEN pl.duration_minutes IS NOT NULL AND pl.duration_minutes > 0
      THEN pl.created_at_ist ELSE NULL END
  FROM public.platform_ledger pl
  WHERE pl.user_id = v_user_id AND pl.created_at_ist >= v_period_start AND pl.created_at_ist < v_period_end
    AND NOT EXISTS (
      SELECT 1 FROM public.wallet_transactions wt
      WHERE wt.user_id = v_user_id AND wt.idempotency_key = pl.idempotency_key
        AND pl.idempotency_key IS NOT NULL
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.ledger_transactions lt
      WHERE lt.user_id = v_user_id AND lt.reference_id = pl.idempotency_key
        AND pl.idempotency_key IS NOT NULL
    )
  ORDER BY pl.created_at_ist, pl.id;

  -- 4) Women earnings
  IF v_gender = 'female' THEN
    INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit, start_time, end_time)
    SELECT we.created_at, we.id::text,
      COALESCE(we.chat_session_id, we.video_session_id, we.group_id, we.private_call_id)::text,
      we.earning_type, we.description,
      CASE WHEN we.minutes_billed IS NOT NULL THEN (we.minutes_billed * 60)::integer ELSE NULL END,
      we.rate_per_minute,
      0, we.amount,
      CASE WHEN we.minutes_billed IS NOT NULL AND we.minutes_billed > 0
        THEN we.created_at - (we.minutes_billed * interval '1 minute')
        ELSE NULL END,
      CASE WHEN we.minutes_billed IS NOT NULL AND we.minutes_billed > 0
        THEN we.created_at ELSE NULL END
    FROM public.women_earnings we
    WHERE we.user_id = v_user_id AND we.created_at >= v_period_start AND we.created_at < v_period_end
      AND NOT EXISTS (
        SELECT 1 FROM public.wallet_transactions wt
        WHERE wt.user_id = v_user_id AND wt.idempotency_key = we.idempotency_key
          AND we.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.platform_ledger pl
        WHERE pl.user_id = v_user_id AND pl.idempotency_key = we.idempotency_key
          AND we.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.ledger_transactions lt
        WHERE lt.user_id = v_user_id
          AND lt.transaction_type = 'earning'
          AND lt.credit = we.amount
          AND COALESCE(we.chat_session_id, we.video_session_id, we.group_id, we.private_call_id) IS NOT NULL
          AND lt.session_id IS NOT NULL
          AND lt.session_id::text = COALESCE(we.chat_session_id, we.video_session_id, we.group_id, we.private_call_id)::text
          AND ABS(EXTRACT(EPOCH FROM (lt.created_at - we.created_at))) < 120
      )
    ORDER BY we.created_at, we.id;
  END IF;

  -- Calculate opening balance
  IF v_is_current_month THEN
    SELECT COALESCE(SUM(sr.credit), 0), COALESCE(SUM(sr.debit), 0)
    INTO v_total_credit, v_total_debit FROM _stmt_rows sr;
    
    SELECT COALESCE(w.balance, 0) INTO v_wallet_balance FROM public.wallets w WHERE w.user_id = v_user_id;
    IF v_wallet_balance IS NULL THEN v_wallet_balance := 0; END IF;
    v_opening := v_wallet_balance - v_total_credit + v_total_debit;
  ELSE
    SELECT COALESCE(SUM(cr - dr), 0) INTO v_opening
    FROM (
      SELECT lt2.credit as cr, lt2.debit as dr FROM public.ledger_transactions lt2
      WHERE lt2.user_id = v_user_id AND lt2.created_at < v_period_start
      UNION ALL
      SELECT
        CASE WHEN wt2.type = 'credit' THEN wt2.amount ELSE 0 END,
        CASE WHEN wt2.type = 'debit' THEN wt2.amount ELSE 0 END
      FROM public.wallet_transactions wt2
      WHERE wt2.user_id = v_user_id AND wt2.created_at < v_period_start AND wt2.status = 'completed'
        AND NOT EXISTS (
          SELECT 1 FROM public.ledger_transactions lt3
          WHERE lt3.user_id = v_user_id AND lt3.reference_id = wt2.idempotency_key
            AND wt2.idempotency_key IS NOT NULL
        )
      UNION ALL
      SELECT pl2.credit, pl2.debit FROM public.platform_ledger pl2
      WHERE pl2.user_id = v_user_id AND pl2.created_at_ist < v_period_start
        AND NOT EXISTS (
          SELECT 1 FROM public.ledger_transactions lt4
          WHERE lt4.user_id = v_user_id AND lt4.reference_id = pl2.idempotency_key
            AND pl2.idempotency_key IS NOT NULL
        )
      UNION ALL
      SELECT we2.amount, 0 FROM public.women_earnings we2
      WHERE we2.user_id = v_user_id AND we2.created_at < v_period_start
        AND v_gender = 'female'
        AND NOT EXISTS (
          SELECT 1 FROM public.ledger_transactions lt5
          WHERE lt5.user_id = v_user_id AND lt5.transaction_type = 'earning'
            AND lt5.credit = we2.amount
            AND COALESCE(we2.chat_session_id, we2.video_session_id, we2.group_id, we2.private_call_id) IS NOT NULL
            AND lt5.session_id IS NOT NULL
            AND lt5.session_id::text = COALESCE(we2.chat_session_id, we2.video_session_id, we2.group_id, we2.private_call_id)::text
            AND ABS(EXTRACT(EPOCH FROM (lt5.created_at - we2.created_at))) < 120
        )
    ) combined;
    IF v_gender = 'male' AND v_opening < 0 THEN v_opening := 0; END IF;
  END IF;

  RETURN QUERY
  SELECT sr.txn_date, sr.transaction_id, sr.session_id, sr.txn_type, sr.description,
    sr.duration_seconds, sr.rate_per_minute, sr.debit, sr.credit,
    (v_opening + SUM(sr.credit - sr.debit) OVER (ORDER BY sr.txn_date, sr.row_num))::numeric AS running_balance,
    sr.start_time, sr.end_time
  FROM _stmt_rows sr ORDER BY sr.txn_date, sr.row_num;
END;
$$;
