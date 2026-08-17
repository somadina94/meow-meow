
CREATE OR REPLACE FUNCTION public.purchase_golden_badge(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_wallet_id uuid;
  v_badge_price numeric := 1000;
  v_expires_at timestamp with time zone;
  v_is_indian boolean;
  v_gender text;
  v_existing_badge boolean;
  v_total_earnings numeric;
  v_total_withdrawals numeric;
  v_effective_balance numeric;
BEGIN
  -- Verify user is an Indian woman
  SELECT gender, is_indian, has_golden_badge
  INTO v_gender, v_is_indian, v_existing_badge
  FROM profiles WHERE user_id = p_user_id;

  IF LOWER(COALESCE(v_gender, '')) != 'female' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Golden Badge is only available for women');
  END IF;

  IF NOT COALESCE(v_is_indian, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Golden Badge is only available for Indian women');
  END IF;

  -- Check if already has active badge
  IF COALESCE(v_existing_badge, false) THEN
    IF EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = p_user_id 
      AND golden_badge_expires_at > now()
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'You already have an active Golden Badge');
    END IF;
  END IF;

  -- Calculate effective balance: total earnings - total debits from wallet_transactions
  SELECT COALESCE(SUM(amount), 0) INTO v_total_earnings
  FROM women_earnings WHERE user_id = p_user_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_withdrawals
  FROM wallet_transactions WHERE user_id = p_user_id AND type = 'debit';

  v_effective_balance := v_total_earnings - v_total_withdrawals;

  IF v_effective_balance < v_badge_price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance. You need ₹1000. Your balance: ₹' || v_effective_balance);
  END IF;

  -- Ensure wallet exists
  SELECT id INTO v_wallet_id FROM wallets WHERE user_id = p_user_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, balance, currency)
    VALUES (p_user_id, 0, 'INR')
    RETURNING id INTO v_wallet_id;
  END IF;

  -- Set expiry to 30 days from now
  v_expires_at := now() + interval '30 days';

  -- Record the debit transaction (this reduces the effective balance)
  INSERT INTO wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_user_id, 'debit', v_badge_price, 'Golden Badge Purchase (1 Month)', 'completed');

  -- Update profiles
  UPDATE profiles 
  SET has_golden_badge = true, golden_badge_expires_at = v_expires_at, updated_at = now()
  WHERE user_id = p_user_id;

  UPDATE female_profiles
  SET has_golden_badge = true, golden_badge_expires_at = v_expires_at, updated_at = now()
  WHERE user_id = p_user_id;

  -- Record subscription
  INSERT INTO golden_badge_subscriptions (user_id, amount, expires_at)
  VALUES (p_user_id, v_badge_price, v_expires_at);

  -- Log admin revenue
  INSERT INTO admin_revenue_transactions (transaction_type, amount, woman_user_id, description, currency)
  VALUES ('golden_badge', v_badge_price, p_user_id, 'Golden Badge purchase', 'INR');

  RETURN jsonb_build_object(
    'success', true,
    'expires_at', v_expires_at,
    'new_balance', v_effective_balance - v_badge_price
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;
