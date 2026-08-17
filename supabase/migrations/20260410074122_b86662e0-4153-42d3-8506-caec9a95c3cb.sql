
-- Simplify get_men_wallet_balance: wallets = balance, ledger_transactions = totals
CREATE OR REPLACE FUNCTION public.get_men_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance numeric := 0;
  v_currency text := 'INR';
  v_total_recharges numeric := 0;
  v_total_spending numeric := 0;
BEGIN
  SELECT COALESCE(balance, 0), COALESCE(currency, 'INR')
  INTO v_balance, v_currency
  FROM wallets WHERE user_id = p_user_id;

  SELECT COALESCE(SUM(credit), 0), COALESCE(SUM(debit), 0)
  INTO v_total_recharges, v_total_spending
  FROM ledger_transactions
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'balance', v_balance,
    'currency', v_currency,
    'total_recharges', v_total_recharges,
    'total_spending', v_total_spending
  );
END;
$$;

-- Simplify get_women_wallet_balance: wallets = balance, ledger_transactions = totals
CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
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
  v_today_start := date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata';

  SELECT COALESCE(balance, 0) INTO v_wallet_balance FROM wallets WHERE user_id = p_user_id;

  SELECT COALESCE(SUM(credit), 0), COALESCE(SUM(debit), 0)
  INTO v_total_earnings, v_total_debits
  FROM ledger_transactions
  WHERE user_id = p_user_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM withdrawal_requests WHERE user_id = p_user_id AND status = 'pending';

  SELECT COALESCE(SUM(credit), 0) INTO v_today_earnings
  FROM ledger_transactions
  WHERE user_id = p_user_id AND created_at >= v_today_start;

  RETURN jsonb_build_object(
    'total_earnings', v_total_earnings,
    'total_debits', v_total_debits,
    'pending_withdrawals', v_pending_withdrawals,
    'today_earnings', v_today_earnings,
    'available_balance', v_wallet_balance
  );
END;
$$;
