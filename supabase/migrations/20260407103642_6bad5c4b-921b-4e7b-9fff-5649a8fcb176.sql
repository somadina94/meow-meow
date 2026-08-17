
-- Fix get_men_wallet_balance to read from both tables
CREATE OR REPLACE FUNCTION public.get_men_wallet_balance(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_balance numeric := 0;
  v_total_recharges numeric := 0;
  v_total_spending numeric := 0;
BEGIN
  SELECT COALESCE(balance, 0) INTO v_balance FROM wallets WHERE user_id = p_user_id;

  SELECT COALESCE(SUM(cr), 0), COALESCE(SUM(db), 0)
  INTO v_total_recharges, v_total_spending
  FROM (
    SELECT credit AS cr, debit AS db FROM ledger_transactions WHERE user_id = p_user_id
    UNION ALL
    SELECT
      CASE WHEN type = 'credit' THEN amount ELSE 0 END,
      CASE WHEN type = 'debit' THEN amount ELSE 0 END
    FROM wallet_transactions
    WHERE user_id = p_user_id AND status = 'completed'
      AND (idempotency_key IS NULL OR NOT EXISTS (
        SELECT 1 FROM ledger_transactions lt WHERE lt.user_id = p_user_id AND lt.reference_id = wallet_transactions.idempotency_key
      ))
  ) combined;

  RETURN jsonb_build_object('balance', v_balance, 'total_recharges', v_total_recharges, 'total_spending', v_total_spending);
END;
$function$;

-- Fix get_women_wallet_balance to use wallets table as source of truth
CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
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
    SELECT credit AS cr, debit AS db FROM ledger_transactions WHERE user_id = p_user_id
    UNION ALL
    SELECT
      CASE WHEN type = 'credit' THEN amount ELSE 0 END,
      CASE WHEN type = 'debit' THEN amount ELSE 0 END
    FROM wallet_transactions
    WHERE user_id = p_user_id AND status = 'completed'
      AND (idempotency_key IS NULL OR NOT EXISTS (
        SELECT 1 FROM ledger_transactions lt WHERE lt.user_id = p_user_id AND lt.reference_id = wallet_transactions.idempotency_key
      ))
  ) combined;

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM withdrawal_requests WHERE user_id = p_user_id AND status = 'pending';

  SELECT COALESCE(SUM(credit), 0) INTO v_today_earnings
  FROM ledger_transactions WHERE user_id = p_user_id AND created_at >= v_today_start;

  v_today_earnings := v_today_earnings + COALESCE((
    SELECT SUM(amount) FROM wallet_transactions
    WHERE user_id = p_user_id AND type = 'credit' AND status = 'completed' AND created_at >= v_today_start
      AND (idempotency_key IS NULL OR NOT EXISTS (
        SELECT 1 FROM ledger_transactions lt WHERE lt.user_id = p_user_id AND lt.reference_id = wallet_transactions.idempotency_key
      ))
  ), 0);

  RETURN jsonb_build_object(
    'total_earnings', v_total_earnings,
    'total_debits', v_total_debits,
    'pending_withdrawals', v_pending_withdrawals,
    'today_earnings', v_today_earnings,
    'available_balance', v_wallet_balance
  );
END;
$function$;
