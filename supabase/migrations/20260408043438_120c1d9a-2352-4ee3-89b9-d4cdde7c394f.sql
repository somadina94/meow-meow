
-- Fix get_women_wallet_balance: use IST for today_start
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
  -- Use IST midnight for "today" calculation
  v_today_start := date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata';

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
    UNION ALL
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

  -- Today's earnings using IST midnight
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

-- Fix get_men_wallet_balance: return currency field
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

  RETURN jsonb_build_object(
    'balance', v_balance,
    'currency', v_currency,
    'total_recharges', v_total_recharges,
    'total_spending', v_total_spending
  );
END;
$$;
