
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
  v_admin_share NUMERIC;
  v_host_id UUID;
  v_host_wallet_id UUID;
  v_is_super_user BOOLEAN;
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

  -- Get the current host - tips go to the active host, not the static owner
  v_host_id := v_group.current_host_id;
  IF v_host_id IS NULL THEN
    -- Fallback to owner_id if no current host
    v_host_id := v_group.owner_id;
  END IF;

  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive tip');
  END IF;

  -- Cannot tip yourself
  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send tip to yourself');
  END IF;

  -- Check if super user
  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- Lock sender's wallet
  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  -- Check balance
  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  -- Calculate 50/50 split
  v_women_share := v_gift.price * 0.5;
  v_admin_share := v_gift.price * 0.5;

  -- Debit sender's wallet (full amount)
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  -- Create wallet transaction for sender (debit full tip)
  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', v_gift.price, 'Group tip: ' || v_gift.name || ' (to host)', 'completed');

  -- Credit host's women_earnings (50% of tip)
  INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
  VALUES (v_host_id, v_women_share, 'gift', 'Group tip (50% share): ' || v_gift.name);

  -- Credit host's wallet with 50%
  SELECT id INTO v_host_wallet_id FROM public.wallets WHERE user_id = v_host_id FOR UPDATE;
  IF v_host_wallet_id IS NOT NULL THEN
    UPDATE public.wallets SET balance = balance + v_women_share, updated_at = now() WHERE id = v_host_wallet_id;
    
    -- Create wallet transaction for host (credit 50%)
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_host_wallet_id, v_host_id, 'credit', v_women_share, 'Group tip received (50%): ' || v_gift.name, 'completed');
  END IF;

  -- Create gift transaction record
  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, v_gift.currency, 'Group tip', 'completed');

  -- Record admin revenue (50%)
  INSERT INTO public.admin_revenue_transactions (transaction_type, amount, currency, description, man_user_id, woman_user_id, reference_id)
  VALUES ('group_tip', v_admin_share, v_gift.currency, 'Group tip admin share (50%): ' || v_gift.name, p_sender_id, v_host_id, p_group_id::text);

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
$$;
