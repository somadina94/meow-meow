
CREATE OR REPLACE FUNCTION public.get_ledger_statement(
  p_user_id uuid,
  p_from_date timestamptz DEFAULT NULL,
  p_to_date timestamptz DEFAULT NULL
)
RETURNS TABLE(
  id uuid,
  created_at timestamptz,
  transaction_type text,
  session_id uuid,
  counterparty_id uuid,
  debit numeric,
  credit numeric,
  running_balance numeric,
  description text,
  reference_id text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_balance numeric;
  v_ledger_net numeric;
  v_offset numeric;
BEGIN
  -- Get the real wallet balance (source of truth)
  SELECT COALESCE(w.balance, 0) INTO v_wallet_balance
  FROM wallets w WHERE w.user_id = p_user_id;

  IF v_wallet_balance IS NULL THEN
    v_wallet_balance := 0;
  END IF;

  -- Get the net sum of ALL ledger transactions for this user
  SELECT COALESCE(SUM(lt.credit - lt.debit), 0) INTO v_ledger_net
  FROM ledger_transactions lt WHERE lt.user_id = p_user_id;

  -- Offset = difference between real balance and ledger-computed balance
  v_offset := v_wallet_balance - v_ledger_net;

  RETURN QUERY
  SELECT
    lt.id,
    lt.created_at,
    lt.transaction_type,
    lt.session_id,
    lt.counterparty_id,
    lt.debit,
    lt.credit,
    v_offset + SUM(lt.credit - lt.debit) OVER (
      PARTITION BY lt.user_id ORDER BY lt.created_at
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance,
    lt.description,
    lt.reference_id
  FROM ledger_transactions lt
  WHERE lt.user_id = p_user_id
    AND (p_from_date IS NULL OR lt.created_at >= p_from_date)
    AND (p_to_date IS NULL OR lt.created_at <= p_to_date)
  ORDER BY lt.created_at;
END;
$$;
