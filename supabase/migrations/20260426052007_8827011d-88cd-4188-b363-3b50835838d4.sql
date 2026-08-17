
-- 1. get_ledger_statement: reads wallet_transactions, maps to legacy debit/credit columns for UI compat
CREATE OR REPLACE FUNCTION public.get_ledger_statement(
  p_user_id uuid, p_from_date text DEFAULT NULL, p_to_date text DEFAULT NULL
)
RETURNS TABLE(
  id uuid, session_id text, transaction_type text, debit numeric, credit numeric,
  description text, reference_id text, counterparty_id text, running_balance numeric,
  created_at timestamptz, duration_seconds integer, rate_per_minute numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  WITH ordered AS (
    SELECT
      t.id,
      t.session_id::text AS session_id,
      t.transaction_type,
      CASE WHEN t.type = 'debit' THEN t.amount ELSE 0 END AS debit,
      CASE WHEN t.type = 'credit' THEN t.amount ELSE 0 END AS credit,
      t.description,
      t.reference_id,
      NULL::text AS counterparty_id,
      t.created_at,
      COALESCE(t.duration_seconds, 0)::integer AS duration_seconds,
      t.rate_per_minute,
      SUM(CASE WHEN t.type='credit' THEN t.amount ELSE -t.amount END) 
        OVER (ORDER BY t.created_at, t.id) AS running_balance
    FROM public.wallet_transactions t
    WHERE t.user_id = p_user_id
      AND (p_from_date IS NULL OR t.created_at >= p_from_date::date)
      AND (p_to_date IS NULL OR t.created_at < (p_to_date::date + INTERVAL '1 day'))
  )
  SELECT
    o.id, o.session_id, o.transaction_type, o.debit, o.credit, o.description,
    o.reference_id, o.counterparty_id, o.running_balance, o.created_at,
    o.duration_seconds, o.rate_per_minute
  FROM ordered o
  ORDER BY o.created_at DESC, o.id DESC;
END; $$;

-- 2. get_men_wallet_balance
CREATE OR REPLACE FUNCTION public.get_men_wallet_balance(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_balance numeric := 0; v_currency text := 'INR'; v_recharges numeric := 0; v_spending numeric := 0;
BEGIN
  SELECT COALESCE(balance,0), COALESCE(currency,'INR') INTO v_balance, v_currency
  FROM wallets WHERE user_id = p_user_id;

  SELECT COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN type='debit'  THEN amount ELSE 0 END), 0)
  INTO v_recharges, v_spending
  FROM wallet_transactions WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'balance', v_balance, 'currency', v_currency,
    'total_recharges', v_recharges, 'total_spending', v_spending
  );
END; $$;

-- 3. get_women_wallet_balance
CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_balance numeric := 0; v_earnings numeric := 0; v_debits numeric := 0;
  v_pending numeric := 0; v_today numeric := 0; v_today_start timestamptz;
BEGIN
  v_today_start := date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata';

  SELECT COALESCE(balance,0) INTO v_balance FROM wallets WHERE user_id = p_user_id;

  SELECT COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN type='debit'  THEN amount ELSE 0 END), 0)
  INTO v_earnings, v_debits
  FROM wallet_transactions WHERE user_id = p_user_id;

  SELECT COALESCE(SUM(amount),0) INTO v_pending
  FROM withdrawal_requests WHERE user_id = p_user_id AND status='pending';

  SELECT COALESCE(SUM(amount),0) INTO v_today
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type='credit' AND created_at >= v_today_start;

  RETURN jsonb_build_object(
    'total_earnings', v_earnings, 'total_debits', v_debits,
    'pending_withdrawals', v_pending, 'today_earnings', v_today,
    'available_balance', v_balance
  );
END; $$;
