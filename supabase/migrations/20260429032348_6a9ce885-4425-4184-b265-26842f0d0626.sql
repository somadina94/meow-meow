-- Tighten execute permissions for wallet statement/balance/reconciliation RPCs.
REVOKE ALL ON FUNCTION public.get_ledger_statement(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_men_wallet_balance(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_women_wallet_balance(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reconcile_wallet_balance(uuid) FROM PUBLIC, anon;

CREATE OR REPLACE FUNCTION public.reconcile_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_balance numeric := 0;
  v_computed_balance numeric := 0;
  v_diff numeric := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Missing user_id');
  END IF;

  IF auth.role() <> 'service_role' AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Not allowed to reconcile this wallet';
  END IF;

  SELECT COALESCE(w.balance, 0)
  INTO v_current_balance
  FROM public.wallets w
  WHERE w.user_id = p_user_id;

  SELECT GREATEST(COALESCE(SUM(CASE
    WHEN wt.status = 'completed' AND wt.type = 'credit' THEN wt.amount
    WHEN wt.status = 'completed' AND wt.type = 'debit' THEN -wt.amount
    ELSE 0
  END), 0), 0)
  INTO v_computed_balance
  FROM public.wallet_transactions wt
  WHERE wt.user_id = p_user_id;

  UPDATE public.wallets
  SET balance = v_computed_balance,
      updated_at = now()
  WHERE user_id = p_user_id;

  v_diff := v_current_balance - v_computed_balance;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', p_user_id,
    'previous_balance', v_current_balance,
    'computed_balance', v_computed_balance,
    'difference', v_diff,
    'wallet_balance', v_computed_balance,
    'in_sync', true
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_ledger_statement(uuid, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_men_wallet_balance(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_women_wallet_balance(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reconcile_wallet_balance(uuid) TO authenticated, service_role;
