
-- ============================================================
-- FIX: get_my_statement_summary — include platform_ledger + women_earnings
-- ============================================================
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
  v_prev_year       integer;
  v_prev_month      integer;
  v_six_months_ago  timestamptz;
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

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1; END IF;

  -- Try monthly_statements for opening balance
  SELECT closing_balance INTO v_opening_balance FROM public.monthly_statements
  WHERE user_id = v_user_id AND year = v_prev_year AND month = v_prev_month;

  -- Fallback: compute from ALL sources before period
  IF v_opening_balance IS NULL THEN
    SELECT COALESCE(SUM(credit - debit), 0) INTO v_opening_balance
    FROM (
      -- Source 1: ledger_transactions
      SELECT credit, debit FROM public.ledger_transactions
      WHERE user_id = v_user_id AND created_at < v_period_start

      UNION ALL
      -- Source 2: wallet_transactions (not duped in ledger)
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
      -- Source 3: platform_ledger (not duped in wallet_transactions or ledger)
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
      -- Source 4: women_earnings (credits for women not captured elsewhere)
      SELECT we.amount AS credit, 0 AS debit FROM public.women_earnings we
      WHERE we.user_id = v_user_id AND we.created_at < v_period_start
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
    ) combined;
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
    SELECT 0 AS debit, we.amount AS credit FROM public.women_earnings we
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
  ) combined;

  v_closing_balance := v_opening_balance + v_total_credit - v_total_debit;
  IF v_gender = 'male' AND v_closing_balance < 0 THEN v_closing_balance := 0; END IF;

  RETURN jsonb_build_object('success', true, 'gender', v_gender, 'year', p_year, 'month', p_month,
    'opening_balance', v_opening_balance, 'total_debit', v_total_debit,
    'total_credit', v_total_credit, 'closing_balance', v_closing_balance);
END;
$$;


-- ============================================================
-- FIX: get_my_statement_detail — include platform_ledger + women_earnings
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_statement_detail(p_year integer, p_month integer)
RETURNS TABLE(
  txn_date timestamptz, transaction_id text, session_id text,
  txn_type text, description text, duration_seconds integer,
  rate_per_minute numeric, debit numeric, credit numeric, running_balance numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id        uuid := auth.uid();
  v_gender         text;
  v_period_start   timestamptz;
  v_period_end     timestamptz;
  v_opening        numeric(12,2) := 0;
  v_prev_year      integer;
  v_prev_month     integer;
  v_six_months_ago timestamptz;
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = v_user_id;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  v_six_months_ago := date_trunc('month', now() - interval '5 months');
  IF v_period_start < v_six_months_ago THEN RETURN; END IF;

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1; END IF;

  SELECT ms.closing_balance INTO v_opening FROM public.monthly_statements ms
  WHERE ms.user_id = v_user_id AND ms.year = v_prev_year AND ms.month = v_prev_month;

  IF v_opening IS NULL THEN
    SELECT COALESCE(SUM(credit - debit), 0) INTO v_opening
    FROM (
      SELECT credit, debit FROM public.ledger_transactions
      WHERE user_id = v_user_id AND created_at < v_period_start
      UNION ALL
      SELECT
        CASE WHEN type = 'credit' THEN amount ELSE 0 END,
        CASE WHEN type = 'debit' THEN amount ELSE 0 END
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
      SELECT we.amount, 0 FROM public.women_earnings we
      WHERE we.user_id = v_user_id AND we.created_at < v_period_start
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
    ) combined;
  END IF;

  IF v_gender = 'male' AND v_opening < 0 THEN v_opening := 0; END IF;

  CREATE TEMP TABLE IF NOT EXISTS _stmt_rows (
    row_num serial, txn_date timestamptz, transaction_id text, session_id text,
    txn_type text, description text, duration_seconds integer, rate_per_minute numeric,
    debit numeric NOT NULL DEFAULT 0, credit numeric NOT NULL DEFAULT 0
  ) ON COMMIT DROP;
  TRUNCATE _stmt_rows;

  -- Source 1: ledger_transactions
  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit)
  SELECT lt.created_at, lt.id::text, lt.session_id::text,
    lt.transaction_type, lt.description, lt.duration_seconds, lt.rate_per_minute,
    lt.debit, lt.credit
  FROM public.ledger_transactions lt
  WHERE lt.user_id = v_user_id AND lt.created_at >= v_period_start AND lt.created_at < v_period_end
  ORDER BY lt.created_at, lt.id;

  -- Source 2: wallet_transactions (deduped against ledger)
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

  -- Source 3: platform_ledger (deduped against wallet_transactions and ledger)
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

  -- Source 4: women_earnings (only for women, deduped)
  IF v_gender = 'female' THEN
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

  RETURN QUERY
  SELECT sr.txn_date, sr.transaction_id, sr.session_id, sr.txn_type, sr.description,
    sr.duration_seconds, sr.rate_per_minute, sr.debit, sr.credit,
    GREATEST(v_opening + SUM(sr.credit - sr.debit) OVER (ORDER BY sr.txn_date, sr.row_num),
             CASE WHEN v_gender = 'male' THEN 0 ELSE -999999999 END)::numeric AS running_balance
  FROM _stmt_rows sr ORDER BY sr.txn_date, sr.row_num;
END;
$$;
