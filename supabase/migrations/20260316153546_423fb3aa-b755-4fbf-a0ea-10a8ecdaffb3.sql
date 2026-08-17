
CREATE OR REPLACE FUNCTION public.admin_deduct_wallet(
  p_user_id uuid,
  p_amount numeric,
  p_reason text,
  p_admin_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_balance numeric;
  v_new_balance numeric;
  v_wallet_exists boolean;
BEGIN
  -- Lock the wallet row to prevent concurrent modifications
  SELECT balance INTO v_old_balance
  FROM users_wallet
  WHERE user_id = p_user_id
  FOR UPDATE;

  v_wallet_exists := FOUND;

  IF NOT v_wallet_exists THEN
    RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
  END IF;

  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Deduction amount must be positive';
  END IF;

  IF p_amount > v_old_balance THEN
    RAISE EXCEPTION 'Insufficient balance. Current: %, Requested: %', v_old_balance, p_amount;
  END IF;

  v_new_balance := v_old_balance - p_amount;

  -- Update wallet balance
  UPDATE users_wallet
  SET balance = v_new_balance, updated_at = now()
  WHERE user_id = p_user_id;

  -- Insert ledger transaction (append-only)
  INSERT INTO ledger_transactions (user_id, transaction_type, debit, credit, description, reference_id)
  VALUES (p_user_id, 'admin_penalty', p_amount, 0, 'Admin penalty: ' || p_reason, 'PENALTY-' || extract(epoch from now())::bigint);

  -- Insert notification
  INSERT INTO notifications (user_id, title, message, type)
  VALUES (p_user_id, 'Wallet Deduction', '₹' || p_amount::text || ' has been deducted from your wallet. Reason: ' || p_reason, 'system');

  -- Insert audit log
  INSERT INTO audit_logs (admin_id, action, action_type, resource_type, resource_id, details)
  VALUES (
    p_admin_id,
    'Wallet Deduction: ₹' || p_amount::text,
    'update',
    'wallet',
    p_user_id::text,
    'Deducted ₹' || p_amount::text || ' from user. Reason: ' || p_reason || '. Previous balance: ₹' || v_old_balance::text || '. New balance: ₹' || v_new_balance::text
  );

  RETURN jsonb_build_object(
    'success', true,
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'amount', p_amount
  );
END;
$$;
