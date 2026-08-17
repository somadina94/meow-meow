
CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_earnings numeric := 0;
  v_total_debits numeric := 0;
  v_pending_withdrawals numeric := 0;
  v_today_earnings numeric := 0;
  v_available_balance numeric := 0;
  v_today_start timestamptz;
  v_today_end timestamptz;
BEGIN
  -- Calculate today boundaries in UTC (client handles timezone)
  v_today_start := date_trunc('day', now());
  v_today_end := v_today_start + interval '1 day' - interval '1 millisecond';

  -- Total earnings (no row limit - server-side aggregation)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_earnings
  FROM women_earnings
  WHERE user_id = p_user_id;

  -- Total debits from wallet_transactions
  SELECT COALESCE(SUM(amount), 0) INTO v_total_debits
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'debit';

  -- Pending + approved withdrawals
  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM withdrawal_requests
  WHERE user_id = p_user_id AND status IN ('pending', 'approved');

  -- Today's earnings
  SELECT COALESCE(SUM(amount), 0) INTO v_today_earnings
  FROM women_earnings
  WHERE user_id = p_user_id
    AND created_at >= v_today_start
    AND created_at <= v_today_end;

  v_available_balance := v_total_earnings - v_total_debits - v_pending_withdrawals;

  RETURN jsonb_build_object(
    'total_earnings', v_total_earnings,
    'total_debits', v_total_debits,
    'pending_withdrawals', v_pending_withdrawals,
    'today_earnings', v_today_earnings,
    'available_balance', v_available_balance
  );
END;
$$;
