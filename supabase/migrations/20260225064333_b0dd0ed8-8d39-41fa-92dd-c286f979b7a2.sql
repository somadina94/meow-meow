-- Fix group gift credit target: always credit active host, never placeholder owner_id

CREATE OR REPLACE FUNCTION public.process_group_gift(
  p_sender_id uuid,
  p_group_id uuid,
  p_gift_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_gift RECORD;
  v_group RECORD;
  v_wallet_id UUID;
  v_balance NUMERIC;
  v_new_balance NUMERIC;
  v_women_share NUMERIC;
  v_admin_share NUMERIC;
  v_is_super_user BOOLEAN;
  v_host_id UUID;
BEGIN
  -- Get group details with lock
  SELECT * INTO v_group
  FROM public.private_groups
  WHERE id = p_group_id AND is_active = true
  FOR UPDATE;

  IF v_group IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group not found');
  END IF;

  -- Resolve active host first, fallback to owner for legacy compatibility
  v_host_id := COALESCE(v_group.current_host_id, v_group.owner_id);

  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive gift');
  END IF;

  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send gift to yourself');
  END IF;

  -- Get gift details
  SELECT * INTO v_gift
  FROM public.gifts
  WHERE id = p_gift_id AND is_active = true
  FOR SHARE;

  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found');
  END IF;

  -- Check if gift meets minimum requirement
  IF v_gift.price < v_group.min_gift_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift does not meet minimum requirement of ' || v_group.min_gift_amount);
  END IF;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- Lock sender wallet
  SELECT id, balance INTO v_wallet_id, v_balance
  FROM public.wallets
  WHERE user_id = p_sender_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  v_women_share := v_gift.price * 0.5;
  v_admin_share := v_gift.price * 0.5;

  -- Debit sender
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price, 'Group access gift: ' || v_gift.name, 'completed');

  -- Credit host earnings to drive statement/history views
  INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
  VALUES (v_host_id, v_women_share, 'gift', 'Group access gift (50% share): ' || v_gift.name);

  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, v_gift.currency, 'Group access gift', 'completed');

  INSERT INTO public.group_memberships (group_id, user_id, gift_amount_paid, has_access)
  VALUES (p_group_id, p_sender_id, v_gift.price, true)
  ON CONFLICT (group_id, user_id)
  DO UPDATE SET has_access = true, gift_amount_paid = EXCLUDED.gift_amount_paid;

  UPDATE public.private_groups
  SET participant_count = participant_count + 1
  WHERE id = p_group_id;

  RETURN jsonb_build_object(
    'success', true,
    'gift_name', v_gift.name,
    'gift_emoji', v_gift.emoji,
    'amount_paid', v_gift.price,
    'women_share', v_women_share,
    'admin_share', v_admin_share,
    'new_balance', v_new_balance,
    'host_id', v_host_id
  );
END;
$function$;

-- Apply same host resolution fix to video-access group gifts
CREATE OR REPLACE FUNCTION public.process_group_video_gift(
  p_sender_id uuid,
  p_group_id uuid,
  p_gift_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_group RECORD;
  v_gift RECORD;
  v_wallet_id uuid;
  v_balance numeric;
  v_new_balance numeric;
  v_women_share numeric;
  v_access_expires timestamp with time zone;
  v_is_super_user boolean;
  v_current_members integer;
  v_already_member boolean;
  v_host_id uuid;
BEGIN
  SELECT * INTO v_group
  FROM public.private_groups
  WHERE id = p_group_id AND is_active = true
  FOR UPDATE;

  IF v_group IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group not found or inactive');
  END IF;

  v_host_id := COALESCE(v_group.current_host_id, v_group.owner_id);

  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive gift');
  END IF;

  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send gift to yourself');
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.group_memberships
    WHERE group_id = p_group_id AND user_id = p_sender_id
  ) INTO v_already_member;

  IF NOT v_already_member THEN
    SELECT COUNT(*) INTO v_current_members
    FROM public.group_memberships
    WHERE group_id = p_group_id AND user_id != v_host_id;

    IF v_current_members >= 150 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Group is full (150 men limit reached)');
    END IF;
  END IF;

  SELECT * INTO v_gift
  FROM public.gifts
  WHERE id = p_gift_id AND is_active = true;

  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found');
  END IF;

  IF v_gift.price < v_group.min_gift_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift amount is below minimum required: ₹' || v_group.min_gift_amount);
  END IF;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  SELECT id, balance INTO v_wallet_id, v_balance
  FROM public.wallets
  WHERE user_id = p_sender_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  v_women_share := v_gift.price * 0.5;
  v_access_expires := now() + interval '30 minutes';

  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;

    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price,
            'Group video gift: ' || v_gift.emoji || ' ' || v_gift.name, 'completed');
  ELSE
    v_new_balance := v_balance;
  END IF;

  INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
  VALUES (v_host_id, v_women_share, 'gift',
          'Group video gift: ' || v_gift.emoji || ' from video access');

  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, status, message)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, 'completed',
          'Video call access for group: ' || v_group.name);

  INSERT INTO public.group_video_access (group_id, user_id, gift_id, gift_amount, access_expires_at)
  VALUES (p_group_id, p_sender_id, p_gift_id, v_gift.price, v_access_expires);

  IF NOT v_already_member THEN
    INSERT INTO public.group_memberships (group_id, user_id, has_access, gift_amount_paid)
    VALUES (p_group_id, p_sender_id, true, v_gift.price)
    ON CONFLICT (group_id, user_id)
    DO UPDATE SET has_access = true, gift_amount_paid = v_gift.price;

    UPDATE public.private_groups
    SET participant_count = participant_count + 1
    WHERE id = p_group_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'gift_name', v_gift.name,
    'gift_emoji', v_gift.emoji,
    'gift_price', v_gift.price,
    'women_share', v_women_share,
    'new_balance', v_new_balance,
    'access_expires_at', v_access_expires,
    'access_duration_minutes', 30,
    'group_language', v_group.owner_language,
    'host_id', v_host_id
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;