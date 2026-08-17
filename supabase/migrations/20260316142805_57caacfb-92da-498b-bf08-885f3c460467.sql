-- Fix: check_session_balance references non-existent column men_rate_per_min
-- Need to drop and recreate since parameter names differ
DROP FUNCTION IF EXISTS public.check_session_balance(uuid, uuid);

CREATE FUNCTION public.check_session_balance(p_user_id uuid, p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet RECORD;
  v_pricing RECORD;
  v_min_balance numeric;
BEGIN
  IF p_user_id IS NULL OR p_session_id IS NULL THEN
    RETURN jsonb_build_object('has_balance', false, 'error', 'Invalid session parameters');
  END IF;
  SELECT balance INTO v_wallet FROM public.wallets WHERE user_id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('has_balance', false, 'balance', 0, 'error', 'Wallet not found. Please contact support.');
  END IF;
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
  v_min_balance := CASE WHEN v_pricing IS NOT NULL THEN v_pricing.rate_per_minute ELSE 2 END;
  RETURN jsonb_build_object('has_balance', v_wallet.balance >= v_min_balance, 'balance', v_wallet.balance, 'min_required', v_min_balance);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('has_balance', false, 'error', 'Unable to check balance. Please refresh and try again.');
END;
$$;