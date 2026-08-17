-- Fix gift and group tip RPCs to only credit Indian women (non-Indian women earn ₹0)
-- Men are ALWAYS charged full price regardless of woman's nationality

-- 1. process_gift_transaction: add is_indian check
CREATE OR REPLACE FUNCTION public.process_gift_transaction(
    p_sender_id uuid,
    p_receiver_id uuid,
    p_gift_id uuid,
    p_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
BEGIN
    -- Get gift details with lock
    SELECT * INTO v_gift
    FROM public.gifts
    WHERE id = p_gift_id AND is_active = true
    FOR SHARE;
    
    IF v_gift IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift not found or inactive');
    END IF;
    
    -- Check if sender is super user
    v_is_super_user := public.should_bypass_balance(p_sender_id);
    
    -- Check if receiver is Indian
    SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_receiver_is_indian
    FROM public.profiles p
    LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
    WHERE p.user_id = p_receiver_id;
    
    -- Lock sender's wallet
    SELECT id, balance INTO v_wallet_id, v_balance
    FROM public.wallets
    WHERE user_id = p_sender_id
    FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;
    
    -- Check balance (skip for super users)
    IF NOT v_is_super_user AND v_balance < v_gift.price THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
    
    -- 50% share for Indian women only; non-Indian women get ₹0
    v_women_share := CASE WHEN v_receiver_is_indian THEN v_gift.price * 0.5 ELSE 0 END;
    
    -- Calculate new balance
    IF v_is_super_user THEN
        v_new_balance := v_balance;
    ELSE
        v_new_balance := v_balance - v_gift.price;
    END IF;
    
    -- Debit wallet (atomic) - always debit full price from man
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create wallet transaction record for sender
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, status
    ) VALUES (
        v_wallet_id, p_sender_id, 'debit', v_gift.price,
        'Gift: ' || v_gift.name || ' (sent)', 'completed'
    ) RETURNING id INTO v_transaction_id;
    
    -- Credit woman's earnings ONLY if Indian (50% of gift value)
    IF v_women_share > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (p_receiver_id, v_women_share, 'gift', 'Gift received: ' || v_gift.name || ' (50% share)');
    END IF;
    
    -- Create gift transaction record
    INSERT INTO public.gift_transactions (
        sender_id, receiver_id, gift_id, price_paid, currency, message, status
    ) VALUES (
        p_sender_id, p_receiver_id, p_gift_id, v_gift.price, v_gift.currency, p_message, 'completed'
    ) RETURNING id INTO v_gift_transaction_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'gift_transaction_id', v_gift_transaction_id,
        'wallet_transaction_id', v_transaction_id,
        'previous_balance', v_balance,
        'new_balance', v_new_balance,
        'gift_name', v_gift.name,
        'gift_emoji', v_gift.emoji,
        'gift_price', v_gift.price,
        'women_share', v_women_share,
        'receiver_is_indian', v_receiver_is_indian,
        'super_user_bypass', v_is_super_user
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 2. process_group_tip: add is_indian check for host
CREATE OR REPLACE FUNCTION public.process_group_tip(
  p_sender_id UUID,
  p_group_id UUID,
  p_gift_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
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
BEGIN
  -- Get gift details
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found');
  END IF;

  -- Get group details
  SELECT * INTO v_group FROM public.private_groups WHERE id = p_group_id AND is_active = true FOR SHARE;
  IF v_group IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group not found');
  END IF;

  -- Get the current host
  v_host_id := v_group.current_host_id;
  IF v_host_id IS NULL THEN
    v_host_id := v_group.owner_id;
  END IF;

  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive tip');
  END IF;

  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send tip to yourself');
  END IF;

  -- Check if host is Indian
  SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_host_is_indian
  FROM public.profiles p
  LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
  WHERE p.user_id = v_host_id;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- Lock sender's wallet
  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- 50% goes to host ONLY if Indian; non-Indian host gets ₹0
  v_women_share := CASE WHEN v_host_is_indian THEN v_gift.price * 0.5 ELSE 0 END;

  -- Debit sender's wallet (full amount always)
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  -- Create wallet transaction for sender (debit full tip)
  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price, 
    'Group tip: ' || v_gift.emoji || ' ' || v_gift.name || ' in ' || v_group.name || ' (₹' || v_gift.price || ')', 
    'completed');

  -- Credit host via women_earnings ONLY if Indian
  IF v_women_share > 0 THEN
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (v_host_id, v_women_share, 'gift', 
      'Group tip (50%): ' || v_gift.emoji || ' ' || v_gift.name || ' in ' || v_group.name || ' - ₹' || v_women_share);
  END IF;

  -- Create gift transaction record
  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, v_gift.currency, 'Group tip in ' || v_group.name, 'completed');

  RETURN jsonb_build_object(
    'success', true,
    'gift_name', v_gift.name,
    'gift_emoji', v_gift.emoji,
    'amount_paid', v_gift.price,
    'women_share', v_women_share,
    'new_balance', v_new_balance,
    'host_id', v_host_id,
    'host_is_indian', v_host_is_indian
  );
END;
$$;