
-- 1) Fix process_gift_transaction: credit women wallet + wallet_transactions
CREATE OR REPLACE FUNCTION public.process_gift_transaction(
  p_sender_id uuid, p_receiver_id uuid, p_gift_id uuid, p_message text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_gift RECORD;
  v_wallet_id uuid;
  v_balance numeric;
  v_new_balance numeric;
  v_transaction_id uuid;
  v_gift_transaction_id uuid;
  v_is_super_user boolean;
  v_women_share numeric;
  v_receiver_is_indian boolean := false;
  v_woman_wallet_id uuid;
  v_woman_balance numeric;
BEGIN
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found or inactive');
  END IF;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_receiver_is_indian
  FROM public.profiles p LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
  WHERE p.user_id = p_receiver_id;

  -- Lock sender wallet
  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  v_women_share := CASE WHEN v_receiver_is_indian THEN ROUND(v_gift.price * 0.5, 2) ELSE 0 END;

  IF v_is_super_user THEN
    v_new_balance := v_balance;
  ELSE
    v_new_balance := v_balance - v_gift.price;
  END IF;

  -- Debit men wallet
  UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;

  -- Men debit wallet_transaction
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, amount, description, balance_after, status
  ) VALUES (
    v_wallet_id, p_sender_id, 'debit', 'gift_charge', v_gift.price,
    'Gift: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_gift.price || ' (100% deducted)',
    v_new_balance, 'completed'
  ) RETURNING id INTO v_transaction_id;

  -- Credit women wallet + wallet_transaction (if Indian)
  IF v_women_share > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets WHERE user_id = p_receiver_id FOR UPDATE;

    IF v_woman_wallet_id IS NOT NULL THEN
      v_woman_balance := v_woman_balance + v_women_share;
      UPDATE public.wallets SET balance = v_woman_balance, updated_at = now() WHERE id = v_woman_wallet_id;

      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, balance_after, status
      ) VALUES (
        v_woman_wallet_id, p_receiver_id, 'credit', 'gift_earning', v_women_share,
        'Gift Received: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_women_share || ' (50% of ₹' || v_gift.price || ')',
        v_woman_balance, 'completed'
      );
    END IF;

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (p_receiver_id, v_women_share, 'gift', 'Gift received: ' || v_gift.name || ' (50% of ₹' || v_gift.price || ')');
  END IF;

  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, p_receiver_id, p_gift_id, v_gift.price, v_gift.currency, p_message, 'completed')
  RETURNING id INTO v_gift_transaction_id;

  RETURN jsonb_build_object(
    'success', true, 'gift_transaction_id', v_gift_transaction_id,
    'wallet_transaction_id', v_transaction_id, 'previous_balance', v_balance,
    'new_balance', v_new_balance, 'gift_name', v_gift.name, 'gift_emoji', v_gift.emoji,
    'gift_price', v_gift.price, 'women_share', v_women_share,
    'receiver_is_indian', v_receiver_is_indian, 'super_user_bypass', v_is_super_user
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- 2) Fix process_group_tip: credit women wallet + wallet_transactions
CREATE OR REPLACE FUNCTION public.process_group_tip(p_sender_id uuid, p_group_id uuid, p_gift_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_gift RECORD;
  v_group RECORD;
  v_wallet_id UUID;
  v_balance NUMERIC;
  v_new_balance NUMERIC;
  v_women_share NUMERIC;
  v_host_id UUID;
  v_is_super_user BOOLEAN;
  v_host_is_indian BOOLEAN := false;
  v_woman_wallet_id UUID;
  v_woman_balance NUMERIC;
BEGIN
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Gift not found'); END IF;

  SELECT * INTO v_group FROM public.private_groups WHERE id = p_group_id AND is_active = true FOR SHARE;
  IF v_group IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Group not found'); END IF;

  v_host_id := COALESCE(v_group.current_host_id, v_group.owner_id);
  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive tip');
  END IF;
  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send tip to yourself');
  END IF;

  SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_host_is_indian
  FROM public.profiles p LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
  WHERE p.user_id = v_host_id;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Wallet not found'); END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  v_women_share := CASE WHEN v_host_is_indian THEN ROUND(v_gift.price * 0.5, 2) ELSE 0 END;

  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  -- Men debit wallet_transaction
  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, transaction_type, amount, description, balance_after, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', 'tip_charge', v_gift.price,
    'Group Tip: ' || v_gift.emoji || ' ' || v_gift.name || ' in ' || v_group.name || ' — ₹' || v_gift.price,
    v_new_balance, 'completed');

  -- Credit women wallet + wallet_transaction (if Indian host)
  IF v_women_share > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets WHERE user_id = v_host_id FOR UPDATE;

    IF v_woman_wallet_id IS NOT NULL THEN
      v_woman_balance := v_woman_balance + v_women_share;
      UPDATE public.wallets SET balance = v_woman_balance, updated_at = now() WHERE id = v_woman_wallet_id;

      INSERT INTO public.wallet_transactions (wallet_id, user_id, type, transaction_type, amount, description, balance_after, status)
      VALUES (v_woman_wallet_id, v_host_id, 'credit', 'tip_earning', v_women_share,
        'Group Tip Received: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_women_share || ' (50% of ₹' || v_gift.price || ')',
        v_woman_balance, 'completed');
    END IF;

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (v_host_id, v_women_share, 'gift',
      'Group tip (50%): ' || v_gift.emoji || ' ' || v_gift.name || ' in ' || v_group.name || ' — ₹' || v_women_share);
  END IF;

  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, v_gift.currency, 'Group tip in ' || v_group.name, 'completed');

  RETURN jsonb_build_object(
    'success', true, 'gift_name', v_gift.name, 'gift_emoji', v_gift.emoji,
    'amount_paid', v_gift.price, 'women_share', v_women_share,
    'new_balance', v_new_balance, 'host_id', v_host_id, 'host_is_indian', v_host_is_indian
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- 3) Drop old check_session_balance overload that reads from users_wallet
DROP FUNCTION IF EXISTS public.check_session_balance(uuid, text);

-- 4) Ensure the correct overload exists
CREATE OR REPLACE FUNCTION public.check_session_balance(
  p_user_id uuid, p_session_id uuid DEFAULT NULL, p_session_type text DEFAULT 'chat'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE v_balance numeric := 0; v_pricing RECORD; v_min_needed numeric;
BEGIN
  SELECT COALESCE(balance, 0) INTO v_balance FROM public.wallets WHERE user_id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('sufficient', false, 'balance', 0, 'required', 4, 'shortfall', 4, 'has_balance', false, 'error', 'Wallet not found');
  END IF;
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
  v_min_needed := CASE p_session_type
    WHEN 'video_call' THEN COALESCE(v_pricing.video_rate_per_minute, 8)
    WHEN 'audio_call' THEN COALESCE(v_pricing.audio_rate_per_minute, 6)
    WHEN 'private_group_call' THEN COALESCE(v_pricing.group_call_rate_per_minute, 4)
    ELSE COALESCE(v_pricing.rate_per_minute, 4)
  END;
  -- Require 2 minutes minimum
  v_min_needed := v_min_needed * 2;
  RETURN jsonb_build_object(
    'sufficient', v_balance >= v_min_needed, 'has_balance', v_balance >= v_min_needed,
    'balance', v_balance, 'required', v_min_needed,
    'shortfall', GREATEST(v_min_needed - v_balance, 0), 'min_required', v_min_needed
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('sufficient', false, 'has_balance', false, 'balance', 0, 'required', 4, 'shortfall', 4, 'error', SQLERRM);
END;
$function$;
