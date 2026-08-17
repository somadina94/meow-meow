
-- 1. Update min_withdrawal_balance in chat_pricing
UPDATE public.chat_pricing SET min_withdrawal_balance = 100 WHERE is_active = true;

-- 2. Replace ledger_withdrawal to include 5% fee deduction
CREATE OR REPLACE FUNCTION public.ledger_withdrawal(
  p_user_id uuid,
  p_amount numeric,
  p_payment_method text DEFAULT 'upi',
  p_payment_details jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_id uuid;
  v_balance numeric;
  v_pending numeric := 0;
  v_available numeric;
  v_min_withdrawal numeric := 100;
  v_request_id uuid;
  v_fee_rate numeric := 0.05;  -- 5% platform fee
  v_fee_amount numeric;
  v_net_payout numeric;
BEGIN
  -- Validate amount
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
  END IF;

  -- Get min withdrawal from pricing table
  SELECT min_withdrawal_balance INTO v_min_withdrawal
  FROM public.chat_pricing WHERE is_active = true
  ORDER BY updated_at DESC LIMIT 1;
  v_min_withdrawal := COALESCE(v_min_withdrawal, 100);

  -- Lock wallet row
  SELECT id, balance INTO v_wallet_id, v_balance
  FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  -- Calculate pending withdrawals
  SELECT COALESCE(SUM(amount), 0) INTO v_pending
  FROM public.withdrawal_requests
  WHERE user_id = p_user_id AND status = 'pending';

  v_available := v_balance - v_pending;

  -- Check minimum withdrawal
  IF p_amount < v_min_withdrawal THEN
    RETURN jsonb_build_object('success', false, 'error',
      'Minimum withdrawal is ₹' || v_min_withdrawal);
  END IF;

  -- Check sufficient balance
  IF p_amount > v_available THEN
    RETURN jsonb_build_object('success', false, 'error',
      'Insufficient balance. Available: ₹' || v_available);
  END IF;

  -- Calculate 5% fee
  v_fee_amount := ROUND(p_amount * v_fee_rate, 2);
  v_net_payout := p_amount - v_fee_amount;

  -- Deduct FULL amount from wallet (amount requested)
  UPDATE public.wallets
  SET balance = balance - p_amount
  WHERE id = v_wallet_id AND balance >= p_amount;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance for withdrawal');
  END IF;

  -- Record the withdrawal payout ledger entry (net amount women receives)
  INSERT INTO public.ledger_transactions (user_id, transaction_type, debit, description, reference_id)
  VALUES (p_user_id, 'withdrawal', v_net_payout,
    'Withdrawal payout (₹' || p_amount || ' - 5% fee ₹' || v_fee_amount || ')', NULL);

  -- Record the 5% fee as a separate ledger entry
  INSERT INTO public.ledger_transactions (user_id, transaction_type, debit, description)
  VALUES (p_user_id, 'withdrawal_fee', v_fee_amount,
    'Withdrawal platform fee (5% of ₹' || p_amount || ')');

  -- Record admin revenue for the fee
  INSERT INTO public.admin_revenue_transactions (amount, transaction_type, woman_user_id, description)
  VALUES (v_fee_amount, 'withdrawal_fee', p_user_id,
    'Withdrawal fee 5% on ₹' || p_amount);

  -- Create withdrawal request with net payout amount
  INSERT INTO public.withdrawal_requests (user_id, amount, payment_method, payment_details, status)
  VALUES (p_user_id, v_net_payout, p_payment_method, p_payment_details, 'pending')
  RETURNING id INTO v_request_id;

  RETURN jsonb_build_object(
    'success', true,
    'request_id', v_request_id,
    'requested_amount', p_amount,
    'fee_percent', 5,
    'fee_amount', v_fee_amount,
    'net_payout', v_net_payout,
    'available_balance', v_available - p_amount
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
