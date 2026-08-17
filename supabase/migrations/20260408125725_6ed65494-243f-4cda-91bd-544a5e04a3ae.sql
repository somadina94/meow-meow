
-- Add missing description column to wallet_recharges
ALTER TABLE public.wallet_recharges ADD COLUMN IF NOT EXISTS description text;

-- Fix ledger_recharge function to handle the column properly
CREATE OR REPLACE FUNCTION public.ledger_recharge(
  p_user_id uuid,
  p_amount numeric,
  p_gateway text DEFAULT 'razorpay',
  p_gateway_txn_id text DEFAULT NULL,
  p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_wallet_id uuid; v_old_balance numeric; v_new_balance numeric;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive'); END IF;
  SELECT id, balance INTO v_wallet_id, v_old_balance FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN INSERT INTO public.wallets (user_id, balance, currency) VALUES (p_user_id, 0, 'INR') RETURNING id, balance INTO v_wallet_id, v_old_balance; END IF;
  v_new_balance := v_old_balance + p_amount;
  UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, balance_after, status, created_at)
  VALUES (p_user_id, 'credit', 'recharge', p_amount, COALESCE(p_description, 'Wallet recharge via ' || p_gateway), v_new_balance, 'completed', now());
  INSERT INTO public.wallet_recharges (user_id, amount, payment_gateway, gateway_transaction_id, status)
  VALUES (p_user_id, p_amount, p_gateway, p_gateway_txn_id, 'success');
  INSERT INTO public.ledger_transactions (user_id, transaction_type, credit, debit, description, reference_id)
  VALUES (p_user_id, 'recharge', p_amount, 0, COALESCE(p_description, 'Wallet recharge via ' || p_gateway), p_gateway_txn_id);
  RETURN jsonb_build_object('success', true, 'previous_balance', v_old_balance, 'new_balance', v_new_balance, 'amount_recharged', p_amount);
EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
