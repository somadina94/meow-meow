CREATE OR REPLACE FUNCTION public.get_men_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_balance numeric := 0;
  v_currency text := 'INR';
  v_recharges numeric := 0;
  v_spending numeric := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('balance', 0, 'currency', 'INR', 'total_recharges', 0, 'total_spending', 0);
  END IF;

  IF auth.role() <> 'service_role' AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Not allowed to view this wallet';
  END IF;

  SELECT COALESCE(w.currency, 'INR') INTO v_currency
  FROM public.wallets w
  WHERE w.user_id = p_user_id;

  SELECT
    COALESCE(SUM(CASE WHEN u.type = 'credit' THEN u.amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN u.type = 'debit' THEN u.amount ELSE 0 END), 0),
    GREATEST(COALESCE(SUM(CASE WHEN u.type = 'credit' THEN u.amount WHEN u.type = 'debit' THEN -u.amount ELSE 0 END), 0), 0)
  INTO v_recharges, v_spending, v_balance
  FROM (
    SELECT type, amount, status FROM public.wallet_transactions WHERE user_id = p_user_id
    UNION ALL
    SELECT type, amount, status FROM public.wallet_transactions_archive WHERE user_id = p_user_id
  ) u
  WHERE u.status = 'completed';

  RETURN jsonb_build_object(
    'balance', v_balance,
    'currency', COALESCE(v_currency, 'INR'),
    'total_recharges', v_recharges,
    'total_spending', v_spending
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_balance numeric := 0;
  v_earnings numeric := 0;
  v_debits numeric := 0;
  v_pending numeric := 0;
  v_today numeric := 0;
  v_today_start timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('total_earnings', 0, 'total_debits', 0, 'pending_withdrawals', 0, 'today_earnings', 0, 'available_balance', 0);
  END IF;

  IF auth.role() <> 'service_role' AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Not allowed to view this wallet';
  END IF;

  v_today_start := date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata';

  SELECT
    COALESCE(SUM(CASE WHEN u.type = 'credit' THEN u.amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN u.type = 'debit' THEN u.amount ELSE 0 END), 0),
    GREATEST(COALESCE(SUM(CASE WHEN u.type = 'credit' THEN u.amount WHEN u.type = 'debit' THEN -u.amount ELSE 0 END), 0), 0),
    COALESCE(SUM(CASE WHEN u.type = 'credit' AND u.created_at >= v_today_start THEN u.amount ELSE 0 END), 0)
  INTO v_earnings, v_debits, v_balance, v_today
  FROM (
    SELECT type, amount, status, created_at FROM public.wallet_transactions WHERE user_id = p_user_id
    UNION ALL
    SELECT type, amount, status, created_at FROM public.wallet_transactions_archive WHERE user_id = p_user_id
  ) u
  WHERE u.status = 'completed';

  SELECT COALESCE(SUM(wr.amount), 0)
  INTO v_pending
  FROM public.withdrawal_requests wr
  WHERE wr.user_id = p_user_id
    AND wr.status = 'pending';

  RETURN jsonb_build_object(
    'total_earnings', v_earnings,
    'total_debits', v_debits,
    'pending_withdrawals', v_pending,
    'today_earnings', v_today,
    'available_balance', v_balance
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_men_wallet_balance(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_women_wallet_balance(uuid) TO authenticated, service_role;