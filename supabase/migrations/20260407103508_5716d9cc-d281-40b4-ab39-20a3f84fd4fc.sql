
-- 1) Updated get_my_statement_summary: reads from BOTH tables
CREATE OR REPLACE FUNCTION public.get_my_statement_summary(p_year integer, p_month integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
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
BEGIN
  IF v_user_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Not authenticated'); END IF;

  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = v_user_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Profile not found'); END IF;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1; END IF;

  -- Try monthly_statements first for opening balance
  SELECT closing_balance INTO v_opening_balance FROM public.monthly_statements
  WHERE user_id = v_user_id AND year = v_prev_year AND month = v_prev_month;

  -- Fallback: compute from all prior transactions in both tables
  IF v_opening_balance IS NULL THEN
    SELECT COALESCE(SUM(credit - debit), 0) INTO v_opening_balance
    FROM (
      SELECT credit, debit FROM public.ledger_transactions
      WHERE user_id = v_user_id AND created_at < v_period_start
      UNION ALL
      SELECT
        CASE WHEN type = 'credit' THEN amount ELSE 0 END AS credit,
        CASE WHEN type = 'debit' THEN amount ELSE 0 END AS debit
      FROM public.wallet_transactions
      WHERE user_id = v_user_id AND created_at < v_period_start AND status = 'completed'
        AND idempotency_key IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM public.ledger_transactions lt
          WHERE lt.user_id = v_user_id AND lt.reference_id = wallet_transactions.idempotency_key
        )
    ) combined;
  END IF;

  -- Current period totals from both tables
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
      AND idempotency_key IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.ledger_transactions lt
        WHERE lt.user_id = v_user_id AND lt.reference_id = wallet_transactions.idempotency_key
      )
  ) combined;

  v_closing_balance := v_opening_balance + v_total_credit - v_total_debit;

  RETURN jsonb_build_object('success', true, 'gender', v_gender, 'year', p_year, 'month', p_month,
    'opening_balance', v_opening_balance, 'total_debit', v_total_debit, 'total_credit', v_total_credit, 'closing_balance', v_closing_balance);
END;
$function$;

-- 2) Updated get_my_statement_detail: reads from BOTH tables with dedup
CREATE OR REPLACE FUNCTION public.get_my_statement_detail(p_year integer, p_month integer)
RETURNS TABLE(txn_date timestamptz, transaction_id text, session_id text, txn_type text, description text, duration_seconds integer, rate_per_minute numeric, debit numeric, credit numeric, running_balance numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_user_id        uuid := auth.uid();
  v_period_start   timestamptz;
  v_period_end     timestamptz;
  v_opening        numeric(12,2) := 0;
  v_prev_year      integer;
  v_prev_month     integer;
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

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
        AND idempotency_key IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM public.ledger_transactions lt
          WHERE lt.user_id = v_user_id AND lt.reference_id = wallet_transactions.idempotency_key
        )
    ) combined;
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS _stmt_rows (
    row_num serial, txn_date timestamptz, transaction_id text, session_id text,
    txn_type text, description text, duration_seconds integer, rate_per_minute numeric,
    debit numeric NOT NULL DEFAULT 0, credit numeric NOT NULL DEFAULT 0
  ) ON COMMIT DROP;
  TRUNCATE _stmt_rows;

  -- Insert from ledger_transactions (primary source with rich data)
  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit)
  SELECT lt.created_at, lt.id::text, lt.session_id::text,
    lt.transaction_type, lt.description, lt.duration_seconds, lt.rate_per_minute,
    lt.debit, lt.credit
  FROM public.ledger_transactions lt
  WHERE lt.user_id = v_user_id AND lt.created_at >= v_period_start AND lt.created_at < v_period_end
  ORDER BY lt.created_at, lt.id;

  -- Insert from wallet_transactions (only entries NOT already in ledger)
  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit)
  SELECT wt.created_at, wt.id::text, wt.session_id::text,
    COALESCE(wt.transaction_type, wt.type), wt.description, wt.duration_seconds, wt.rate_per_minute,
    CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END,
    CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END
  FROM public.wallet_transactions wt
  WHERE wt.user_id = v_user_id AND wt.created_at >= v_period_start AND wt.created_at < v_period_end AND wt.status = 'completed'
    AND (wt.idempotency_key IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.ledger_transactions lt
      WHERE lt.user_id = v_user_id AND lt.reference_id = wt.idempotency_key
    ))
  ORDER BY wt.created_at, wt.id;

  RETURN QUERY
  SELECT sr.txn_date, sr.transaction_id, sr.session_id, sr.txn_type, sr.description,
    sr.duration_seconds, sr.rate_per_minute, sr.debit, sr.credit,
    (v_opening + SUM(sr.credit - sr.debit) OVER (ORDER BY sr.txn_date, sr.row_num))::numeric AS running_balance
  FROM _stmt_rows sr ORDER BY sr.txn_date, sr.row_num;
END;
$function$;

-- 3) Admin RPC to reconcile wallet balance from transaction history
CREATE OR REPLACE FUNCTION public.reconcile_wallet_balance(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_current_balance numeric;
  v_computed_balance numeric;
  v_diff numeric;
BEGIN
  SELECT balance INTO v_current_balance FROM public.wallets WHERE user_id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  SELECT COALESCE(SUM(credit - debit), 0) INTO v_computed_balance
  FROM (
    SELECT credit, debit FROM public.ledger_transactions WHERE user_id = p_user_id
    UNION ALL
    SELECT
      CASE WHEN type = 'credit' THEN amount ELSE 0 END,
      CASE WHEN type = 'debit' THEN amount ELSE 0 END
    FROM public.wallet_transactions
    WHERE user_id = p_user_id AND status = 'completed'
      AND (idempotency_key IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.ledger_transactions lt
        WHERE lt.user_id = p_user_id AND lt.reference_id = wallet_transactions.idempotency_key
      ))
  ) combined;

  v_diff := v_current_balance - v_computed_balance;

  RETURN jsonb_build_object(
    'success', true, 'user_id', p_user_id,
    'current_balance', v_current_balance,
    'computed_balance', v_computed_balance,
    'difference', v_diff,
    'in_sync', (ABS(v_diff) < 0.01)
  );
END;
$function$;
