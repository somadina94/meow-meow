CREATE OR REPLACE FUNCTION public.process_group_tip(p_sender_id uuid, p_group_id uuid, p_gift_id uuid)
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
  v_host_id UUID;
  v_is_super_user BOOLEAN;
  v_woman_wallet_id UUID;
  v_woman_balance NUMERIC;
  v_txn_id UUID;
  v_ref_key text;
BEGIN
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Gift not found'); END IF;

  SELECT * INTO v_group FROM public.private_groups WHERE id = p_group_id AND is_active = true FOR SHARE;
  IF v_group IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Group not found'); END IF;

  -- Multi-host support: prefer the specific host the sender joined, then current_host_id, then owner
  SELECT joined_host_id INTO v_host_id
  FROM public.group_memberships
  WHERE group_id = p_group_id AND user_id = p_sender_id
  ORDER BY joined_at DESC NULLS LAST
  LIMIT 1;

  IF v_host_id IS NULL THEN
    -- Fallback: any currently active host in this group
    SELECT host_id INTO v_host_id
    FROM public.group_active_hosts
    WHERE group_id = p_group_id AND is_active = true
    ORDER BY started_at DESC
    LIMIT 1;
  END IF;

  IF v_host_id IS NULL THEN
    v_host_id := COALESCE(v_group.current_host_id, v_group.owner_id);
  END IF;

  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive tip');
  END IF;
  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send tip to yourself');
  END IF;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- All users are Indian — always 50% share
  v_women_share := ROUND(v_gift.price * 0.5, 2);

  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Wallet not found'); END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE
    v_new_balance := v_balance;
  END IF;

  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, transaction_type, amount, description, balance_after, status)
  VALUES (v_wallet_id, p_sender_id, 'debit', 'tip_charge', v_gift.price,
    'Group Tip: ' || v_gift.emoji || ' ' || v_gift.name || ' in ' || v_group.name || ' — ₹' || v_gift.price,
    v_new_balance, 'completed')
  RETURNING id INTO v_txn_id;

  v_ref_key := 'tip:' || v_txn_id::text;
  PERFORM public.safe_ledger_insert(
    p_sender_id, p_group_id, 'tip_charge',
    v_gift.price, 0, v_gift.price, 0, v_host_id,
    v_ref_key, 'Group Tip: ' || v_gift.emoji || ' ' || v_gift.name || ' in ' || v_group.name || ' (₹' || v_gift.price || ')', now()
  );

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

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, rate_per_minute, minutes_billed)
    VALUES (v_host_id, v_women_share, 'gift',
      'Group tip (50%): ' || v_gift.emoji || ' ' || v_gift.name || ' in ' || v_group.name || ' — ₹' || v_women_share,
      NULL, NULL);

    v_ref_key := 'tip_earn:' || v_txn_id::text;
    PERFORM public.safe_ledger_insert(
      v_host_id, p_group_id, 'tip_earning',
      0, v_women_share, v_women_share, 0, p_sender_id,
      v_ref_key, 'Group Tip Received: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_women_share || ' (50%)', now()
    );
  END IF;

  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, v_host_id, p_gift_id, v_gift.price, v_gift.currency, 'Group tip in ' || v_group.name, 'completed');

  RETURN jsonb_build_object(
    'success', true, 'gift_name', v_gift.name, 'gift_emoji', v_gift.emoji,
    'amount_paid', v_gift.price, 'women_share', v_women_share,
    'new_balance', v_new_balance, 'host_id', v_host_id
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;