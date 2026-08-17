-- Fix get_my_statement_summary: anchor closing balance to wallets table for current month
CREATE OR REPLACE FUNCTION public.get_my_statement_summary(p_year integer, p_month integer)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
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
  v_prev_year       integer;
  v_prev_month      integer;
  v_six_months_ago  timestamptz;
  v_is_current_month boolean;
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

  -- Check if this is the current month
  v_is_current_month := (date_trunc('month', now()) = v_period_start);

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1; END IF;

  -- Try monthly_statements for opening balance
  SELECT closing_balance INTO v_opening_balance FROM public.monthly_statements
  WHERE user_id = v_user_id AND year = v_prev_year AND month = v_prev_month;

  -- Fallback: compute from ALL sources before period
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

  -- CRITICAL: For current month, anchor closing balance to wallets table (single source of truth)
  IF v_is_current_month THEN
    SELECT COALESCE(w.balance, 0) INTO v_wallet_balance FROM public.wallets w WHERE w.user_id = v_user_id;
    IF v_wallet_balance IS NULL THEN v_wallet_balance := 0; END IF;
    v_closing_balance := v_wallet_balance;
    -- Back-calculate opening balance so the equation holds: opening = closing - credit + debit
    v_opening_balance := v_closing_balance - v_total_credit + v_total_debit;
    IF v_gender = 'male' AND v_opening_balance < 0 THEN v_opening_balance := 0; END IF;
  ELSE
    v_closing_balance := v_opening_balance + v_total_credit - v_total_debit;
    IF v_gender = 'male' AND v_closing_balance < 0 THEN v_closing_balance := 0; END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'gender', v_gender, 'year', p_year, 'month', p_month,
    'opening_balance', v_opening_balance, 'total_debit', v_total_debit,
    'total_credit', v_total_credit, 'closing_balance', v_closing_balance);
END;
$$;

-- Fix get_women_wallet_balance: include women_earnings and platform_ledger in total earnings
CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_balance numeric := 0;
  v_total_earnings numeric := 0;
  v_total_debits numeric := 0;
  v_pending_withdrawals numeric := 0;
  v_today_earnings numeric := 0;
  v_today_start timestamptz;
BEGIN
  v_today_start := date_trunc('day', now());

  SELECT COALESCE(balance, 0) INTO v_wallet_balance FROM wallets WHERE user_id = p_user_id;

  SELECT COALESCE(SUM(cr), 0), COALESCE(SUM(db), 0)
  INTO v_total_earnings, v_total_debits
  FROM (
    -- Source 1: ledger_transactions
    SELECT credit AS cr, debit AS db FROM ledger_transactions WHERE user_id = p_user_id
    UNION ALL
    -- Source 2: wallet_transactions (deduped against ledger)
    SELECT
      CASE WHEN type = 'credit' THEN amount ELSE 0 END,
      CASE WHEN type = 'debit' THEN amount ELSE 0 END
    FROM wallet_transactions
    WHERE user_id = p_user_id AND status = 'completed'
      AND (idempotency_key IS NULL OR NOT EXISTS (
        SELECT 1 FROM ledger_transactions lt WHERE lt.user_id = p_user_id AND lt.reference_id = wallet_transactions.idempotency_key
      ))
    UNION ALL
    -- Source 3: platform_ledger (deduped against wallet_transactions and ledger)
    SELECT pl.credit, pl.debit FROM platform_ledger pl
    WHERE pl.user_id = p_user_id
      AND NOT EXISTS (
        SELECT 1 FROM wallet_transactions wt
        WHERE wt.user_id = p_user_id AND wt.idempotency_key = pl.idempotency_key
          AND pl.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM ledger_transactions lt
        WHERE lt.user_id = p_user_id AND lt.reference_id = pl.idempotency_key
          AND pl.idempotency_key IS NOT NULL
      )
    UNION ALL
    -- Source 4: women_earnings (deduped against all others)
    SELECT we.amount, 0 FROM women_earnings we
    WHERE we.user_id = p_user_id
      AND NOT EXISTS (
        SELECT 1 FROM wallet_transactions wt
        WHERE wt.user_id = p_user_id AND wt.idempotency_key = we.idempotency_key
          AND we.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM platform_ledger pl
        WHERE pl.user_id = p_user_id AND pl.idempotency_key = we.idempotency_key
          AND we.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM ledger_transactions lt
        WHERE lt.user_id = p_user_id AND lt.reference_id = we.idempotency_key
          AND we.idempotency_key IS NOT NULL
      )
  ) combined;

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM withdrawal_requests WHERE user_id = p_user_id AND status = 'pending';

  -- Today's earnings from all sources (deduped)
  SELECT COALESCE(SUM(cr), 0) INTO v_today_earnings
  FROM (
    SELECT credit AS cr FROM ledger_transactions WHERE user_id = p_user_id AND created_at >= v_today_start
    UNION ALL
    SELECT amount FROM wallet_transactions
    WHERE user_id = p_user_id AND type = 'credit' AND status = 'completed' AND created_at >= v_today_start
      AND (idempotency_key IS NULL OR NOT EXISTS (
        SELECT 1 FROM ledger_transactions lt WHERE lt.user_id = p_user_id AND lt.reference_id = wallet_transactions.idempotency_key
      ))
    UNION ALL
    SELECT we.amount FROM women_earnings we
    WHERE we.user_id = p_user_id AND we.created_at >= v_today_start
      AND NOT EXISTS (
        SELECT 1 FROM wallet_transactions wt
        WHERE wt.user_id = p_user_id AND wt.idempotency_key = we.idempotency_key
          AND we.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM ledger_transactions lt
        WHERE lt.user_id = p_user_id AND lt.reference_id = we.idempotency_key
          AND we.idempotency_key IS NOT NULL
      )
  ) today_combined;

  RETURN jsonb_build_object(
    'total_earnings', v_total_earnings,
    'total_debits', v_total_debits,
    'pending_withdrawals', v_pending_withdrawals,
    'today_earnings', v_today_earnings,
    'available_balance', v_wallet_balance
  );
END;
$$;