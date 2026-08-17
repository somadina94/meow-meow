CREATE OR REPLACE FUNCTION public.atomic_wallet_debit(
  p_wallet_id uuid,
  p_amount numeric
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_balance numeric;
BEGIN
  UPDATE wallets
  SET balance = balance - p_amount
  WHERE id = p_wallet_id AND balance >= p_amount
  RETURNING balance INTO v_new_balance;

  IF NOT FOUND THEN
    RETURN -1; -- insufficient balance
  END IF;

  RETURN v_new_balance;
END;
$$;

CREATE OR REPLACE FUNCTION public.atomic_wallet_credit(
  p_wallet_id uuid,
  p_amount numeric
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_balance numeric;
BEGIN
  UPDATE wallets
  SET balance = balance + p_amount
  WHERE id = p_wallet_id
  RETURNING balance INTO v_new_balance;

  RETURN COALESCE(v_new_balance, -1);
END;
$$;