
-- Fix get_my_statement_detail: skip women_earnings when ledger already has earnings
CREATE OR REPLACE FUNCTION public.get_my_statement_detail(p_year integer, p_month integer)
 RETURNS TABLE(txn_date timestamp with time zone, transaction_id text, session_id text, txn_type text, description text, duration_seconds integer, rate_per_minute numeric, debit numeric, credit numeric, running_balance numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
DECLARE
  v_user_id        uuid := auth.uid();
  v_gender         text;
  v_period_start   timestamptz;
  v_period_end     timestamptz;
  v_opening        numeric(12,2) := 0;
  v_prev_year      integer;
  v_prev_month     integer;
  v_six_months_ago timestamptz;
  v_wallet_balance numeric(12,2);
  v_total_credit   numeric(12,2);
  v_total_debit    numeric(12,2);
  v_is_current_month boolean;
  v_ledger_opening numeric(12,2);
  v_has_ledger_earnings boolean := false;
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  SELECT p.gender INTO v_gender FROM public.profiles p WHERE p.user_id = v_user_id;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';
  v_is_current_month := (date_trunc('month', now()) = v_period_start);

  v_six_months_ago := date_trunc('month', now() - interval '5 months');
  IF v_period_start < v_six_months_ago THEN RETURN; END IF;

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1; END IF;

  -- Check if ledger_transactions has earning entries for this woman
  IF v_gender = 'female' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.ledger_transactions lt
      WHERE lt.user_id = v_user_id AND lt.transaction_type = 'earning'
      LIMIT 1
    ) INTO v_has_ledger_earnings;
  END IF;

  -- Compute opening from ledger
  SELECT COALESCE(SUM(cr - dr), 0) INTO v_ledger_opening
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
        SELECT 1 FROM public.wallet_transactions wt3
        WHERE wt3.user_id = v_user_id AND wt3.idempotency_key = pl2.idempotency_key
          AND pl2.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.ledger_transactions lt4
        WHERE lt4.user_id = v_user_id AND lt4.reference_id = pl2.idempotency_key
          AND pl2.idempotency_key IS NOT NULL
      )
    UNION ALL
    -- Only include women_earnings in opening if ledger doesn't have earnings
    SELECT we2.amount, 0 FROM public.women_earnings we2
    WHERE we2.user_id = v_user_id AND we2.created_at < v_period_start
      AND v_gender = 'female'
      AND NOT v_has_ledger_earnings
      AND NOT EXISTS (
        SELECT 1 FROM public.wallet_transactions wt4
        WHERE wt4.user_id = v_user_id AND wt4.idempotency_key = we2.idempotency_key
          AND we2.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.platform_ledger pl3
        WHERE pl3.user_id = v_user_id AND pl3.idempotency_key = we2.idempotency_key
          AND we2.idempotency_key IS NOT NULL
      )
  ) combined;

  v_opening := v_ledger_opening;
  IF v_gender = 'male' AND v_opening < 0 THEN v_opening := 0; END IF;

  -- Build rows
  CREATE TEMP TABLE IF NOT EXISTS _stmt_rows (
    row_num serial, txn_date timestamptz, transaction_id text, session_id text,
    txn_type text, description text, duration_seconds integer, rate_per_minute numeric,
    debit numeric NOT NULL DEFAULT 0, credit numeric NOT NULL DEFAULT 0
  ) ON COMMIT DROP;
  TRUNCATE _stmt_rows;

  -- Ledger transactions (primary source for both men and women)
  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit)
  SELECT lt.created_at, lt.id::text, lt.session_id::text,
    lt.transaction_type, lt.description, lt.duration_seconds, lt.rate_per_minute,
    lt.debit, lt.credit
  FROM public.ledger_transactions lt
  WHERE lt.user_id = v_user_id AND lt.created_at >= v_period_start AND lt.created_at < v_period_end
  ORDER BY lt.created_at, lt.id;

  -- Wallet transactions (deduped against ledger)
  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit)
  SELECT wt.created_at, wt.id::text, wt.session_id::text,
    COALESCE(wt.transaction_type, wt.type), wt.description, wt.duration_seconds, wt.rate_per_minute,
    CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END,
    CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END
  FROM public.wallet_transactions wt
  WHERE wt.user_id = v_user_id AND wt.created_at >= v_period_start AND wt.created_at < v_period_end AND wt.status = 'completed'
    AND NOT EXISTS (
      SELECT 1 FROM public.ledger_transactions lt
      WHERE lt.user_id = v_user_id AND lt.reference_id = wt.idempotency_key
        AND wt.idempotency_key IS NOT NULL
    )
  ORDER BY wt.created_at, wt.id;

  -- Platform ledger (deduped against wallet + ledger)
  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit)
  SELECT pl.created_at_ist, pl.id::text, pl.session_id::text,
    pl.entry_type, pl.description,
    CASE WHEN pl.duration_minutes IS NOT NULL THEN (pl.duration_minutes * 60)::integer ELSE NULL END,
    pl.rate_per_unit,
    pl.debit, pl.credit
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

  -- Women earnings: ONLY include if ledger doesn't already have earning entries
  IF v_gender = 'female' AND NOT v_has_ledger_earnings THEN
    INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit)
    SELECT we.created_at, we.id::text,
      COALESCE(we.chat_session_id, we.video_session_id, we.group_id, we.private_call_id)::text,
      we.earning_type, we.description,
      CASE WHEN we.minutes_billed IS NOT NULL THEN (we.minutes_billed * 60)::integer ELSE NULL END,
      we.rate_per_minute,
      0, we.amount
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
    ORDER BY we.created_at, we.id;
  END IF;

  -- For current month: anchor opening to wallet so equation holds
  IF v_is_current_month THEN
    SELECT COALESCE(SUM(sr.credit), 0), COALESCE(SUM(sr.debit), 0)
    INTO v_total_credit, v_total_debit FROM _stmt_rows sr;
    
    SELECT COALESCE(w.balance, 0) INTO v_wallet_balance FROM public.wallets w WHERE w.user_id = v_user_id;
    IF v_wallet_balance IS NULL THEN v_wallet_balance := 0; END IF;
    v_opening := v_wallet_balance - v_total_credit + v_total_debit;
  END IF;

  RETURN QUERY
  SELECT sr.txn_date, sr.transaction_id, sr.session_id, sr.txn_type, sr.description,
    sr.duration_seconds, sr.rate_per_minute, sr.debit, sr.credit,
    (v_opening + SUM(sr.credit - sr.debit) OVER (ORDER BY sr.txn_date, sr.row_num))::numeric AS running_balance
  FROM _stmt_rows sr ORDER BY sr.txn_date, sr.row_num;
END;
$function$;

-- Fix get_my_statement_summary: same dedup fix
CREATE OR REPLACE FUNCTION public.get_my_statement_summary(p_year integer, p_month integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_prev_year       integer;
  v_prev_month      integer;
  v_six_months_ago  timestamptz;
  v_is_current_month boolean;
  v_ledger_opening  numeric(12,2);
  v_ms_opening      numeric(12,2);
  v_has_ledger_earnings boolean := false;
BEGIN
  IF v_user_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Not authenticated'); END IF;

  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = v_user_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Profile not found'); END IF;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  v_six_months_ago := date_trunc('month', now() - interval '5 months');
  IF v_period_start < v_six_months_ago THEN
    RETURN jsonb_build_object('success', false, 'error', 'Statements are available for the last 6 months only');
  END IF;

  v_is_current_month := (date_trunc('month', now()) = v_period_start);

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1; END IF;

  -- Check if ledger has earning entries for this woman (to avoid double-counting with women_earnings)
  IF v_gender = 'female' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.ledger_transactions lt
      WHERE lt.user_id = v_user_id AND lt.transaction_type = 'earning'
      LIMIT 1
    ) INTO v_has_ledger_earnings;
  END IF;

  -- Compute opening from ledger data
  SELECT COALESCE(SUM(credit - debit), 0) INTO v_ledger_opening
  FROM (
    SELECT credit, debit FROM public.ledger_transactions
    WHERE user_id = v_user_id AND created_at < v_period_start

    UNION ALL
    SELECT
      CASE WHEN type = 'credit' THEN amount ELSE 0 END AS credit,
      CASE WHEN type = 'debit' THEN amount ELSE 0 END AS debit
    FROM public.wallet_transactions
    WHERE user_id = v_user_id AND created_at < v_period_start AND status = 'completed'
      AND NOT EXISTS (
        SELECT 1 FROM public.ledger_transactions lt
        WHERE lt.user_id = v_user_id AND lt.reference_id = wallet_transactions.idempotency_key
          AND wallet_transactions.idempotency_key IS NOT NULL
      )

    UNION ALL
    SELECT pl.credit, pl.debit FROM public.platform_ledger pl
    WHERE pl.user_id = v_user_id AND pl.created_at_ist < v_period_start
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
    -- Only include women_earnings if ledger doesn't already have earnings
    SELECT we.amount AS credit, 0 AS debit FROM public.women_earnings we
    WHERE we.user_id = v_user_id AND we.created_at < v_period_start
      AND v_gender = 'female'
      AND NOT v_has_ledger_earnings
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
  ) combined;

  -- Check monthly_statements but cross-validate
  SELECT closing_balance INTO v_ms_opening FROM public.monthly_statements
  WHERE user_id = v_user_id AND year = v_prev_year AND month = v_prev_month;

  IF v_ledger_opening != 0 THEN
    v_opening_balance := v_ledger_opening;
  ELSIF v_ms_opening IS NOT NULL THEN
    v_opening_balance := v_ms_opening;
  ELSE
    v_opening_balance := 0;
  END IF;

  IF v_gender = 'male' AND v_opening_balance < 0 THEN v_opening_balance := 0; END IF;

  -- Current period totals from ALL sources
  SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
  INTO v_total_debit, v_total_credit
  FROM (
    SELECT debit, credit FROM public.ledger_transactions
    WHERE user_id = v_user_id AND created_at >= v_period_start AND created_at < v_period_end

    UNION ALL
    SELECT
      CASE WHEN type = 'debit' THEN amount ELSE 0 END AS debit,
      CASE WHEN type = 'credit' THEN amount ELSE 0 END AS credit
    FROM public.wallet_transactions
    WHERE user_id = v_user_id AND created_at >= v_period_start AND created_at < v_period_end AND status = 'completed'
      AND NOT EXISTS (
        SELECT 1 FROM public.ledger_transactions lt
        WHERE lt.user_id = v_user_id AND lt.reference_id = wallet_transactions.idempotency_key
          AND wallet_transactions.idempotency_key IS NOT NULL
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
    -- Only include women_earnings if ledger doesn't already have earnings
    SELECT 0 AS debit, we.amount AS credit FROM public.women_earnings we
    WHERE we.user_id = v_user_id AND we.created_at >= v_period_start AND we.created_at < v_period_end
      AND v_gender = 'female'
      AND NOT v_has_ledger_earnings
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
  ) combined;

  -- For current month, anchor closing to wallets table
  IF v_is_current_month THEN
    SELECT COALESCE(w.balance, 0) INTO v_wallet_balance FROM public.wallets w WHERE w.user_id = v_user_id;
    IF v_wallet_balance IS NULL THEN v_wallet_balance := 0; END IF;
    v_closing_balance := v_wallet_balance;
    v_opening_balance := v_closing_balance - v_total_credit + v_total_debit;
  ELSE
    v_closing_balance := v_opening_balance + v_total_credit - v_total_debit;
    IF v_gender = 'male' AND v_closing_balance < 0 THEN v_closing_balance := 0; END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'gender', v_gender, 'year', p_year, 'month', p_month,
    'opening_balance', v_opening_balance, 'total_debit', v_total_debit,
    'total_credit', v_total_credit, 'closing_balance', v_closing_balance);
END;
$function$;
