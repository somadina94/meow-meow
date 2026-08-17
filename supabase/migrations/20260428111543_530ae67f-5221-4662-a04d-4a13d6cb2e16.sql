
-- ─────────────────────────────────────────────────────────────────────────────
-- 1) AUDIO billing — require explicit idempotency, exact pro-rated amount
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_audio_billing(
  p_session_id text, p_man_id uuid, p_woman_id uuid,
  p_minutes numeric, p_idempotency text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_pricing record; v_man_charge numeric; v_woman_earn numeric;
  v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_idem text; v_idem_w text; v_session_uuid uuid;
BEGIN
  -- HARD GATE: caller MUST pass a unique idempotency key (per-minute).
  IF p_idempotency IS NULL OR length(p_idempotency) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'idempotency_key_required');
  END IF;

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_man_charge := ROUND(p_minutes * COALESCE(v_pricing.audio_rate_per_minute, 6.00), 2);
  v_woman_earn := ROUND(p_minutes * COALESCE(v_pricing.audio_women_earning_rate, 3.00), 2);
  v_idem   := p_idempotency;
  v_idem_w := v_idem || ':earn';
  v_session_uuid := CASE WHEN p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN p_session_id::uuid ELSE NULL END;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
  END IF;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
  IF COALESCE(v_man_balance, 0) < v_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance', 'session_ended', true);
  END IF;

  UPDATE public.wallets SET balance = balance - v_man_charge, updated_at = NOW()
  WHERE id = v_man_wallet_id RETURNING balance INTO v_man_balance;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, amount, description, session_id,
    balance_after, idempotency_key, status, duration_seconds, rate_per_minute
  ) VALUES (
    v_man_wallet_id, p_man_id, 'debit', 'audio_call_charge', v_man_charge,
    'Audio Call: ' || ROUND(p_minutes,2) || ' min @ ₹' || COALESCE(v_pricing.audio_rate_per_minute,6.00) || '/min',
    v_session_uuid, v_man_balance, v_idem, 'completed',
    ROUND(p_minutes*60)::int, COALESCE(v_pricing.audio_rate_per_minute,6.00)
  );

  IF v_woman_earn > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_woman_earn, updated_at = NOW()
      WHERE id = v_woman_wallet_id RETURNING balance INTO v_woman_balance;
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, session_id,
        balance_after, idempotency_key, status, duration_seconds, rate_per_minute
      ) VALUES (
        v_woman_wallet_id, p_woman_id, 'credit', 'audio_call_earning', v_woman_earn,
        'Audio Call Earning: ' || ROUND(p_minutes,2) || ' min @ ₹' || COALESCE(v_pricing.audio_women_earning_rate,3.00) || '/min',
        v_session_uuid, v_woman_balance, v_idem_w, 'completed',
        ROUND(p_minutes*60)::int, COALESCE(v_pricing.audio_women_earning_rate,3.00)
      );
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', v_man_charge, 'earned', v_woman_earn, 'man_charged', v_man_charge, 'woman_earned', v_woman_earn);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) VIDEO billing — same fixes as audio
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_video_billing_v2(
  p_session_id text, p_man_id uuid, p_woman_id uuid,
  p_minutes numeric, p_idempotency text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_pricing record; v_man_charge numeric; v_woman_earn numeric;
  v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_idem text; v_idem_w text; v_session_uuid uuid;
BEGIN
  IF p_idempotency IS NULL OR length(p_idempotency) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'idempotency_key_required');
  END IF;

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_man_charge := ROUND(p_minutes * COALESCE(v_pricing.video_rate_per_minute, 8.00), 2);
  v_woman_earn := ROUND(p_minutes * COALESCE(v_pricing.video_women_earning_rate, 4.00), 2);
  v_idem   := p_idempotency;
  v_idem_w := v_idem || ':earn';
  v_session_uuid := CASE WHEN p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN p_session_id::uuid ELSE NULL END;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
  END IF;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
  IF COALESCE(v_man_balance, 0) < v_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance', 'session_ended', true);
  END IF;

  UPDATE public.wallets SET balance = balance - v_man_charge, updated_at = NOW()
  WHERE id = v_man_wallet_id RETURNING balance INTO v_man_balance;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, amount, description, session_id,
    balance_after, idempotency_key, status, duration_seconds, rate_per_minute
  ) VALUES (
    v_man_wallet_id, p_man_id, 'debit', 'video_call_charge', v_man_charge,
    'Video Call: ' || ROUND(p_minutes,2) || ' min @ ₹' || COALESCE(v_pricing.video_rate_per_minute,8.00) || '/min',
    v_session_uuid, v_man_balance, v_idem, 'completed',
    ROUND(p_minutes*60)::int, COALESCE(v_pricing.video_rate_per_minute,8.00)
  );

  IF v_woman_earn > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_woman_earn, updated_at = NOW()
      WHERE id = v_woman_wallet_id RETURNING balance INTO v_woman_balance;
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, session_id,
        balance_after, idempotency_key, status, duration_seconds, rate_per_minute
      ) VALUES (
        v_woman_wallet_id, p_woman_id, 'credit', 'video_call_earning', v_woman_earn,
        'Video Call Earning: ' || ROUND(p_minutes,2) || ' min @ ₹' || COALESCE(v_pricing.video_women_earning_rate,4.00) || '/min',
        v_session_uuid, v_woman_balance, v_idem_w, 'completed',
        ROUND(p_minutes*60)::int, COALESCE(v_pricing.video_women_earning_rate,4.00)
      );
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', v_man_charge, 'earned', v_woman_earn, 'man_charged', v_man_charge, 'woman_earned', v_woman_earn);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) CHAT billing — bind idempotency to last_activity_at (avoid duplicate skip),
--    super-user still credits Indian women.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_chat_billing(
  p_session_id uuid, p_minutes numeric
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_session RECORD; v_pricing RECORD;
  v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_charge numeric; v_earn numeric;
  v_is_super boolean; v_lock_check integer;
  v_idem_key text; v_idem_key_w text;
  v_woman_indian boolean := false;
BEGIN
  SELECT * INTO v_session FROM public.active_chat_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Session not found'); END IF;

  -- Atomic claim: only first heartbeat for this last_activity_at value proceeds.
  UPDATE public.active_chat_sessions SET last_activity_at = now()
  WHERE id = p_session_id AND last_activity_at = v_session.last_activity_at;
  GET DIAGNOSTICS v_lock_check = ROW_COUNT;
  IF v_lock_check = 0 THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
  END IF;

  -- Bind idempotency to the timestamp we just claimed (unique per heartbeat tick).
  v_idem_key   := 'chat:' || p_session_id::text || ':' || extract(epoch from v_session.last_activity_at)::text;
  v_idem_key_w := v_idem_key || ':earn';

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
  END IF;

  v_is_super := public.should_bypass_balance(v_session.man_user_id);

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'No active pricing'); END IF;

  v_charge := ROUND(p_minutes * v_pricing.rate_per_minute, 2);
  v_earn   := ROUND(v_charge / 2.0, 2);

  -- Indian-woman gate: only Indian women earn (per spec).
  SELECT COALESCE(fp.is_indian, pr.is_indian, false) INTO v_woman_indian
  FROM public.profiles pr
  LEFT JOIN public.female_profiles fp ON fp.user_id = pr.user_id
  WHERE pr.user_id = v_session.woman_user_id;

  -- Super-user: skip man debit, but STILL credit Indian woman.
  IF NOT v_is_super THEN
    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets WHERE user_id = v_session.man_user_id FOR UPDATE;
    IF v_man_balance IS NULL OR v_man_balance < v_charge THEN
      UPDATE public.active_chat_sessions SET status='ended', ended_at=now(), end_reason='insufficient_funds' WHERE id=p_session_id;
      RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'session_ended', true);
    END IF;
    UPDATE public.wallets SET balance = balance - v_charge, updated_at = now()
    WHERE id = v_man_wallet_id RETURNING balance INTO v_man_balance;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, amount, description, session_id,
      balance_after, idempotency_key, status, duration_seconds, rate_per_minute
    ) VALUES (
      v_man_wallet_id, v_session.man_user_id, 'debit', 'chat_charge', v_charge,
      'Chat: ' || ROUND(p_minutes,2) || ' min @ ₹' || v_pricing.rate_per_minute || '/min',
      p_session_id, v_man_balance, v_idem_key, 'completed',
      ROUND(p_minutes * 60)::int, v_pricing.rate_per_minute
    );
  END IF;

  IF v_earn > 0 AND v_woman_indian THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_earn, updated_at = now()
      WHERE id = v_woman_wallet_id RETURNING balance INTO v_woman_balance;
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, session_id,
        balance_after, idempotency_key, status, duration_seconds, rate_per_minute
      ) VALUES (
        v_woman_wallet_id, v_session.woman_user_id, 'credit', 'chat_earning', v_earn,
        'Chat Earning: ' || ROUND(p_minutes,2) || ' min (½ of ₹' || v_charge || ')',
        p_session_id, v_woman_balance, v_idem_key_w, 'completed',
        ROUND(p_minutes * 60)::int, ROUND(v_pricing.rate_per_minute/2.0, 2)
      );
    END IF;
  END IF;

  UPDATE public.active_chat_sessions
  SET total_minutes = total_minutes + p_minutes,
      total_earned  = total_earned  + (CASE WHEN v_woman_indian THEN v_earn ELSE 0 END)
  WHERE id = p_session_id;

  RETURN jsonb_build_object(
    'success', true,
    'super_user', v_is_super,
    'charged', CASE WHEN v_is_super THEN 0 ELSE v_charge END,
    'earned',  CASE WHEN v_woman_indian THEN v_earn ELSE 0 END,
    'idempotency_key', v_idem_key
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4) GROUP CALL billing — require explicit idempotency, host-bound earn key.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_group_billing_v2(
  p_group_id text, p_session_id text, p_host_id uuid,
  p_man_ids uuid[], p_minutes numeric, p_idempotency text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_pricing record; v_rate_per_man numeric; v_earn_per_man numeric;
  v_man_id uuid; v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_total_earned numeric := 0; v_active_count int := 0;
  v_removed_men uuid[] := '{}'; v_idem text; v_idem_man text; v_idem_woman text;
  v_session_uuid uuid;
BEGIN
  IF p_idempotency IS NULL OR length(p_idempotency) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'idempotency_key_required');
  END IF;

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_rate_per_man := ROUND(p_minutes * COALESCE(v_pricing.group_call_rate_per_minute, 4.00), 2);
  v_earn_per_man := ROUND(p_minutes * COALESCE(v_pricing.group_call_women_earning_rate, 0.50), 2);
  v_idem := p_idempotency;
  v_session_uuid := CASE WHEN p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN p_session_id::uuid ELSE NULL END;

  FOREACH v_man_id IN ARRAY p_man_ids LOOP
    v_idem_man := v_idem || ':man:' || v_man_id::text;
    IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_man) THEN CONTINUE; END IF;

    SELECT id, balance INTO v_man_wallet_id, v_man_balance FROM public.wallets WHERE user_id = v_man_id FOR UPDATE;
    IF v_man_wallet_id IS NULL OR COALESCE(v_man_balance,0) < v_rate_per_man THEN
      v_removed_men := array_append(v_removed_men, v_man_id); CONTINUE; END IF;

    UPDATE public.wallets SET balance = balance - v_rate_per_man, updated_at = NOW()
    WHERE id = v_man_wallet_id RETURNING balance INTO v_man_balance;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, amount, description, session_id,
      balance_after, idempotency_key, status, duration_seconds, rate_per_minute
    ) VALUES (
      v_man_wallet_id, v_man_id, 'debit', 'group_call_charge', v_rate_per_man,
      'Group Call: ' || ROUND(p_minutes,2) || ' min @ ₹' || COALESCE(v_pricing.group_call_rate_per_minute,4.00) || '/min',
      v_session_uuid, v_man_balance, v_idem_man, 'completed',
      ROUND(p_minutes*60)::int, COALESCE(v_pricing.group_call_rate_per_minute,4.00)
    );
    v_total_earned := v_total_earned + v_earn_per_man;
    v_active_count := v_active_count + 1;
  END LOOP;

  IF v_total_earned > 0 THEN
    v_idem_woman := v_idem || ':host:' || p_host_id::text;
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance FROM public.wallets WHERE user_id = p_host_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_woman) THEN
      UPDATE public.wallets SET balance = balance + v_total_earned, updated_at = NOW()
      WHERE id = v_woman_wallet_id RETURNING balance INTO v_woman_balance;
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, session_id,
        balance_after, idempotency_key, status, duration_seconds, rate_per_minute
      ) VALUES (
        v_woman_wallet_id, p_host_id, 'credit', 'group_call_earning', v_total_earned,
        'Group Call Earning: ' || ROUND(p_minutes,2) || ' min × ' || v_active_count || ' men',
        v_session_uuid, v_woman_balance, v_idem_woman, 'completed',
        ROUND(p_minutes*60)::int, COALESCE(v_pricing.group_call_women_earning_rate,0.50)
      );
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'active_count', v_active_count,
    'host_earned', v_total_earned, 'removed_men', v_removed_men);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5) GIFT — millisecond-precision idempotency + 2-second double-tap guard
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_gift_transaction(
  p_sender_id uuid, p_receiver_id uuid, p_gift_id uuid, p_message text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_gift RECORD; v_wallet_id uuid; v_balance numeric; v_new_balance numeric;
  v_transaction_id uuid; v_gift_transaction_id uuid; v_is_super boolean;
  v_women_share numeric; v_woman_wallet_id uuid; v_woman_balance numeric;
  v_idem_man text; v_idem_woman text;
BEGIN
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Gift not found'); END IF;

  -- DOUBLE-TAP GUARD: same sender → same receiver → same gift within last 2 seconds.
  IF EXISTS (
    SELECT 1 FROM public.gift_transactions
    WHERE sender_id = p_sender_id AND receiver_id = p_receiver_id
      AND gift_id = p_gift_id AND created_at > now() - interval '2 seconds'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_send_detected');
  END IF;

  v_is_super := public.should_bypass_balance(p_sender_id);
  v_women_share := ROUND(v_gift.price * 0.5, 2);

  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Wallet not found'); END IF;
  IF NOT v_is_super AND v_balance < v_gift.price THEN RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance'); END IF;

  v_new_balance := CASE WHEN v_is_super THEN v_balance ELSE v_balance - v_gift.price END;
  -- Millisecond-precision key.
  v_idem_man   := 'gift:' || p_sender_id::text || ':' || p_gift_id::text || ':' || (extract(epoch from clock_timestamp())*1000)::bigint::text;
  v_idem_woman := v_idem_man || ':earn';

  UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, amount, description, balance_after, idempotency_key, status
  ) VALUES (
    v_wallet_id, p_sender_id, 'debit', 'gift_charge', v_gift.price,
    'Gift: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_gift.price,
    v_new_balance, v_idem_man, 'completed'
  ) RETURNING id INTO v_transaction_id;

  IF v_women_share > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance FROM public.wallets WHERE user_id = p_receiver_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL THEN
      v_woman_balance := v_woman_balance + v_women_share;
      UPDATE public.wallets SET balance = v_woman_balance, updated_at = now() WHERE id = v_woman_wallet_id;
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, balance_after, idempotency_key, status
      ) VALUES (
        v_woman_wallet_id, p_receiver_id, 'credit', 'gift_earning', v_women_share,
        'Gift Received: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_women_share || ' (50% of ₹' || v_gift.price || ')',
        v_woman_balance, v_idem_woman, 'completed'
      );
    END IF;
  END IF;

  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, p_receiver_id, p_gift_id, v_gift.price, v_gift.currency, p_message, 'completed')
  RETURNING id INTO v_gift_transaction_id;

  RETURN jsonb_build_object(
    'success', true, 'gift_transaction_id', v_gift_transaction_id,
    'wallet_transaction_id', v_transaction_id, 'previous_balance', v_balance,
    'new_balance', v_new_balance, 'gift_name', v_gift.name, 'gift_emoji', v_gift.emoji,
    'gift_price', v_gift.price, 'women_share', v_women_share, 'super_user_bypass', v_is_super
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6) GROUP TIP — deterministic idempotency (per-second bucket) blocks dup taps
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_group_tip(
  p_sender_id uuid, p_group_id uuid, p_gift_id uuid
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_gift RECORD; v_group RECORD;
  v_wallet_id uuid; v_balance numeric; v_new_balance numeric;
  v_women_share numeric; v_host_id uuid; v_is_super_user boolean;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_txn_id uuid; v_idem_charge text; v_idem_earn text; v_bucket bigint;
BEGIN
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Gift not found'); END IF;
  SELECT * INTO v_group FROM public.private_groups WHERE id = p_group_id AND is_active = true FOR SHARE;
  IF v_group IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Group not found'); END IF;

  SELECT joined_host_id INTO v_host_id FROM public.group_memberships
   WHERE group_id = p_group_id AND user_id = p_sender_id
   ORDER BY joined_at DESC NULLS LAST LIMIT 1;
  IF v_host_id IS NULL THEN
    SELECT host_id INTO v_host_id FROM public.group_active_hosts
     WHERE group_id = p_group_id AND is_active = true ORDER BY started_at DESC LIMIT 1;
  END IF;
  IF v_host_id IS NULL THEN v_host_id := COALESCE(v_group.current_host_id, v_group.owner_id); END IF;
  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive tip');
  END IF;
  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send tip to yourself');
  END IF;

  -- Deterministic 5-second bucket: same sender+group+gift inside same bucket = dup.
  v_bucket := (extract(epoch from now())/5)::bigint;
  v_idem_charge := 'tip:' || p_sender_id::text || ':' || p_group_id::text || ':' || p_gift_id::text || ':' || v_bucket::text;
  v_idem_earn   := v_idem_charge || ':earn';

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_charge) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_send_detected');
  END IF;

  v_is_super_user := public.should_bypass_balance(p_sender_id);
  v_women_share := ROUND(v_gift.price * 0.5, 2);

  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Wallet not found'); END IF;
  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE v_new_balance := v_balance; END IF;

  v_txn_id := gen_random_uuid();

  INSERT INTO public.wallet_transactions (
    id, wallet_id, user_id, type, transaction_type, amount, description,
    balance_after, status, idempotency_key, reference_id
  ) VALUES (
    v_txn_id, v_wallet_id, p_sender_id, 'debit', 'tip_charge', v_gift.price,
    'Group Tip: '||v_gift.emoji||' '||v_gift.name||' in '||v_group.name||' — ₹'||v_gift.price,
    v_new_balance, 'completed', v_idem_charge, p_gift_id::text
  );

  IF v_women_share > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
      FROM public.wallets WHERE user_id = v_host_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_earn) THEN
      v_woman_balance := v_woman_balance + v_women_share;
      UPDATE public.wallets SET balance = v_woman_balance, updated_at = now() WHERE id = v_woman_wallet_id;
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description,
        balance_after, status, idempotency_key, reference_id
      ) VALUES (
        v_woman_wallet_id, v_host_id, 'credit', 'tip_earning', v_women_share,
        'Group Tip Received: '||v_gift.emoji||' '||v_gift.name||' — ₹'||v_women_share||' (50% of ₹'||v_gift.price||')',
        v_woman_balance, 'completed', v_idem_earn, p_gift_id::text
      );
    END IF;
  END IF;

  RETURN jsonb_build_object('success',true,'sender_charged',v_gift.price,
    'host_earned',v_women_share,'host_id',v_host_id,'txn_id',v_txn_id);
END; $$;
