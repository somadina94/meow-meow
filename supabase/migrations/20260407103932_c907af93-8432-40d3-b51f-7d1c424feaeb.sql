
-- 1. Cleanup function: delete transaction records older than 6 months
CREATE OR REPLACE FUNCTION public.cleanup_old_transactions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Delete wallet_transactions older than 6 months
  DELETE FROM public.wallet_transactions
  WHERE created_at < now() - interval '6 months';

  -- Delete ledger_transactions older than 6 months
  DELETE FROM public.ledger_transactions
  WHERE created_at < now() - interval '6 months';

  -- Delete platform_ledger older than 6 months
  DELETE FROM public.platform_ledger
  WHERE created_at_ist < (now() AT TIME ZONE 'Asia/Kolkata') - interval '6 months';
END;
$$;

-- 2. Trigger to prevent men's wallet balance going negative
CREATE OR REPLACE FUNCTION public.enforce_men_nonnegative_balance()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_gender text;
BEGIN
  IF NEW.balance < 0 THEN
    SELECT gender INTO v_gender FROM public.profiles WHERE user_id = NEW.user_id;
    IF v_gender = 'male' THEN
      NEW.balance := 0;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_men_nonneg ON public.wallets;
CREATE TRIGGER trg_enforce_men_nonneg
  BEFORE UPDATE ON public.wallets
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_men_nonnegative_balance();

-- 3. Update get_my_statement_summary to floor men's opening balance at 0
CREATE OR REPLACE FUNCTION public.get_my_statement_summary(p_year integer, p_month integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

  -- Enforce 6-month window
  v_six_months_ago := date_trunc('month', now() - interval '5 months');
  IF v_period_start < v_six_months_ago THEN
    RETURN jsonb_build_object('success', false, 'error', 'Statements are available for the last 6 months only');
  END IF;

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1; END IF;

  -- Try monthly_statements first for opening balance
  SELECT closing_balance INTO v_opening_balance FROM public.monthly_statements
  WHERE user_id = v_user_id AND year = v_prev_year AND month = v_prev_month;

  -- Fallback: compute from all prior transactions
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

  -- Men's balance never negative: floor opening at 0
  IF v_gender = 'male' AND v_opening_balance < 0 THEN
    v_opening_balance := 0;
  END IF;

  -- Current period totals
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

  -- Men's closing also never negative
  IF v_gender = 'male' AND v_closing_balance < 0 THEN
    v_closing_balance := 0;
  END IF;

  RETURN jsonb_build_object('success', true, 'gender', v_gender, 'year', p_year, 'month', p_month,
    'opening_balance', v_opening_balance, 'total_debit', v_total_debit, 'total_credit', v_total_credit, 'closing_balance', v_closing_balance);
END;
$$;

-- 4. Update get_my_statement_detail with same 6-month and non-negative guards
CREATE OR REPLACE FUNCTION public.get_my_statement_detail(p_year integer, p_month integer)
RETURNS TABLE(txn_date timestamp with time zone, transaction_id text, session_id text, txn_type text, description text, duration_seconds integer, rate_per_minute numeric, debit numeric, credit numeric, running_balance numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

  -- Enforce 6-month window
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
        AND idempotency_key IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM public.ledger_transactions lt
          WHERE lt.user_id = v_user_id AND lt.reference_id = wallet_transactions.idempotency_key
        )
    ) combined;
  END IF;

  -- Men's opening balance never negative
  IF v_gender = 'male' AND v_opening < 0 THEN
    v_opening := 0;
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS _stmt_rows (
    row_num serial, txn_date timestamptz, transaction_id text, session_id text,
    txn_type text, description text, duration_seconds integer, rate_per_minute numeric,
    debit numeric NOT NULL DEFAULT 0, credit numeric NOT NULL DEFAULT 0
  ) ON COMMIT DROP;
  TRUNCATE _stmt_rows;

  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit)
  SELECT lt.created_at, lt.id::text, lt.session_id::text,
    lt.transaction_type, lt.description, lt.duration_seconds, lt.rate_per_minute,
    lt.debit, lt.credit
  FROM public.ledger_transactions lt
  WHERE lt.user_id = v_user_id AND lt.created_at >= v_period_start AND lt.created_at < v_period_end
  ORDER BY lt.created_at, lt.id;

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
    GREATEST(v_opening + SUM(sr.credit - sr.debit) OVER (ORDER BY sr.txn_date, sr.row_num), 
             CASE WHEN v_gender = 'male' THEN 0 ELSE -999999999 END)::numeric AS running_balance
  FROM _stmt_rows sr ORDER BY sr.txn_date, sr.row_num;
END;
$$;
