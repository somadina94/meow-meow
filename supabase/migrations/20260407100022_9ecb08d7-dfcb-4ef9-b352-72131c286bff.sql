
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
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = v_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1;
  END IF;

  SELECT closing_balance INTO v_opening_balance
  FROM public.monthly_statements
  WHERE user_id = v_user_id AND year = v_prev_year AND month = v_prev_month;

  IF v_opening_balance IS NULL THEN
    IF v_gender = 'male' THEN
      SELECT COALESCE(SUM(credit) - SUM(debit), 0) INTO v_opening_balance
      FROM public.ledger_transactions
      WHERE user_id = v_user_id AND created_at < v_period_start;
    ELSE
      SELECT COALESCE(
        (SELECT COALESCE(SUM(amount), 0) FROM public.women_earnings
         WHERE user_id = v_user_id AND created_at < v_period_start)
        -
        (SELECT COALESCE(SUM(amount), 0) FROM public.withdrawal_requests
         WHERE user_id = v_user_id AND status = 'approved' AND processed_at < v_period_start)
      , 0) INTO v_opening_balance;
    END IF;
  END IF;

  IF v_gender = 'male' THEN
    SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
    INTO v_total_debit, v_total_credit
    FROM public.ledger_transactions
    WHERE user_id = v_user_id
      AND created_at >= v_period_start AND created_at < v_period_end;
  ELSE
    SELECT COALESCE(SUM(amount), 0) INTO v_total_credit
    FROM public.women_earnings
    WHERE user_id = v_user_id
      AND created_at >= v_period_start AND created_at < v_period_end;

    SELECT COALESCE(SUM(amount), 0) INTO v_total_debit
    FROM public.withdrawal_requests
    WHERE user_id = v_user_id
      AND status = 'approved'
      AND processed_at >= v_period_start AND processed_at < v_period_end;
  END IF;

  v_closing_balance := v_opening_balance + v_total_credit - v_total_debit;

  RETURN jsonb_build_object(
    'success',         true,
    'gender',          v_gender,
    'year',            p_year,
    'month',           p_month,
    'opening_balance', v_opening_balance,
    'total_debit',     v_total_debit,
    'total_credit',    v_total_credit,
    'closing_balance', v_closing_balance
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_statement_detail(p_year integer, p_month integer)
RETURNS TABLE(
  txn_date timestamptz,
  transaction_id text,
  session_id text,
  txn_type text,
  description text,
  duration_seconds integer,
  rate_per_minute numeric,
  debit numeric,
  credit numeric,
  running_balance numeric
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
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  SELECT p.gender INTO v_gender FROM public.profiles p WHERE p.user_id = v_user_id;
  IF NOT FOUND THEN RETURN; END IF;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1;
  END IF;

  SELECT ms.closing_balance INTO v_opening
  FROM public.monthly_statements ms
  WHERE ms.user_id = v_user_id AND ms.year = v_prev_year AND ms.month = v_prev_month;

  IF v_opening IS NULL THEN
    IF v_gender = 'male' THEN
      SELECT COALESCE(SUM(lt.credit) - SUM(lt.debit), 0) INTO v_opening
      FROM public.ledger_transactions lt
      WHERE lt.user_id = v_user_id AND lt.created_at < v_period_start;
    ELSE
      SELECT COALESCE(
        (SELECT COALESCE(SUM(we.amount), 0) FROM public.women_earnings we
         WHERE we.user_id = v_user_id AND we.created_at < v_period_start)
        -
        (SELECT COALESCE(SUM(wr.amount), 0) FROM public.withdrawal_requests wr
         WHERE wr.user_id = v_user_id AND wr.status = 'approved' AND wr.processed_at < v_period_start)
      , 0) INTO v_opening;
    END IF;
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS _stmt_rows (
    row_num         serial,
    txn_date        timestamptz,
    transaction_id  text,
    session_id      text,
    txn_type        text,
    description     text,
    duration_seconds integer,
    rate_per_minute numeric,
    debit           numeric NOT NULL DEFAULT 0,
    credit          numeric NOT NULL DEFAULT 0
  ) ON COMMIT DROP;

  TRUNCATE _stmt_rows;

  IF v_gender = 'male' THEN
    INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit)
    SELECT
      lt.created_at, lt.id::text, lt.session_id::text, lt.transaction_type, lt.description,
      lt.duration_seconds, lt.rate_per_minute, lt.debit, lt.credit
    FROM public.ledger_transactions lt
    WHERE lt.user_id = v_user_id
      AND lt.created_at >= v_period_start AND lt.created_at < v_period_end
    ORDER BY lt.created_at, lt.id;
  ELSE
    INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit)
    SELECT
      we.created_at, we.id::text,
      COALESCE(we.chat_session_id, we.video_session_id, we.private_call_id, we.group_id)::text,
      we.earning_type, we.description,
      CASE WHEN we.minutes_billed IS NOT NULL THEN (we.minutes_billed * 60)::integer ELSE NULL END,
      we.rate_per_minute, 0, we.amount
    FROM public.women_earnings we
    WHERE we.user_id = v_user_id
      AND we.created_at >= v_period_start AND we.created_at < v_period_end;

    INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit)
    SELECT
      wr.processed_at, wr.id::text, NULL, 'withdrawal',
      'Withdrawal to bank (' || COALESCE(wr.payment_method, 'bank') || ')',
      NULL, NULL, wr.amount, 0
    FROM public.withdrawal_requests wr
    WHERE wr.user_id = v_user_id
      AND wr.status = 'approved'
      AND wr.processed_at >= v_period_start AND wr.processed_at < v_period_end;
  END IF;

  RETURN QUERY
  SELECT
    sr.txn_date, sr.transaction_id, sr.session_id, sr.txn_type, sr.description,
    sr.duration_seconds, sr.rate_per_minute, sr.debit, sr.credit,
    (v_opening + SUM(sr.credit - sr.debit) OVER (ORDER BY sr.txn_date, sr.row_num))::numeric AS running_balance
  FROM _stmt_rows sr
  ORDER BY sr.txn_date, sr.row_num;
END;
$$;
