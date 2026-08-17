
CREATE OR REPLACE FUNCTION public.get_men_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance numeric := 0;
  v_total_recharges numeric := 0;
  v_total_spending numeric := 0;
BEGIN
  -- Get current wallet balance (source of truth for men)
  SELECT COALESCE(balance, 0) INTO v_balance
  FROM wallets
  WHERE user_id = p_user_id;

  -- Total credits (recharges)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_recharges
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'credit';

  -- Total debits (spending on chats, video, gifts)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_spending
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'debit';

  RETURN jsonb_build_object(
    'balance', v_balance,
    'total_recharges', v_total_recharges,
    'total_spending', v_total_spending
  );
END;
$$;
