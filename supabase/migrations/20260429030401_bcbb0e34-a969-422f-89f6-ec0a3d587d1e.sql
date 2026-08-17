
-- ============================================================
-- 1. Idempotency hardening for women_earnings
-- ============================================================
ALTER TABLE public.women_earnings
  ADD COLUMN IF NOT EXISTS idempotency_key text;

-- (unique partial index already exists: idx_women_earnings_idempotency)

-- ============================================================
-- 2. process_gift_billing → wallet_transactions SoT
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_gift_billing(
  p_man_id uuid,
  p_woman_id uuid,
  p_gift_value numeric,
  p_gift_name text DEFAULT 'Gift',
  p_idempotency text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_pricing       record;
  v_woman_pct     numeric;
  v_woman_earn    numeric;
  v_platform_take numeric;
  v_man_wallet_id uuid;
  v_man_balance   numeric;
  v_woman_wallet_id uuid;
  v_woman_balance numeric;
  v_woman_indian  boolean := false;
  v_is_super      boolean;
  v_idem_man      text;
  v_idem_woman    text;
BEGIN
  IF p_idempotency IS NULL OR length(p_idempotency) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'idempotency_key_required');
  END IF;

  v_idem_man   := 'gift_m:' || p_idempotency;
  v_idem_woman := 'gift_w:' || p_idempotency;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_man) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
  END IF;

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_woman_pct     := COALESCE(v_pricing.gift_women_percent, 50.00);
  v_woman_earn    := ROUND(p_gift_value * v_woman_pct / 100.0, 2);
  v_platform_take := p_gift_value - v_woman_earn;

  SELECT COALESCE(
    (SELECT fp.is_indian FROM public.female_profiles fp WHERE fp.user_id = p_woman_id LIMIT 1),
    (SELECT pr.is_indian FROM public.profiles pr WHERE pr.user_id = p_woman_id LIMIT 1),
    false
  ) INTO v_woman_indian;

  v_is_super := public.should_bypass_balance(p_man_id);

  SELECT id, balance INTO v_man_wallet_id, v_man_balance
  FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;

  IF v_man_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found');
  END IF;

  IF NOT v_is_super AND COALESCE(v_man_balance, 0) < p_gift_value THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance');
  END IF;

  IF NOT v_is_super THEN
    UPDATE public.wallets
       SET balance = balance - p_gift_value, updated_at = now()
     WHERE id = v_man_wallet_id
     RETURNING balance INTO v_man_balance;
  END IF;

  INSERT INTO public.wallet_transactions
    (wallet_id, user_id, type, transaction_type, amount, description,
     balance_after, idempotency_key, status)
  VALUES
    (v_man_wallet_id, p_man_id, 'debit', 'gift_charge',
     CASE WHEN v_is_super THEN 0 ELSE p_gift_value END,
     p_gift_name || ': ₹' || p_gift_value || ' sent',
     v_man_balance, v_idem_man, 'completed');

  IF v_woman_indian AND v_woman_earn > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;

    IF v_woman_wallet_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_woman) THEN
      UPDATE public.wallets
         SET balance = balance + v_woman_earn, updated_at = now()
       WHERE id = v_woman_wallet_id
       RETURNING balance INTO v_woman_balance;

      INSERT INTO public.wallet_transactions
        (wallet_id, user_id, type, transaction_type, amount, description,
         balance_after, idempotency_key, status)
      VALUES
        (v_woman_wallet_id, p_woman_id, 'credit', 'gift_earning', v_woman_earn,
         p_gift_name || ': ₹' || v_woman_earn || ' (' || v_woman_pct || '% of ₹' || p_gift_value || ')',
         v_woman_balance, v_idem_woman, 'completed');

      INSERT INTO public.women_earnings
        (user_id, amount, earning_type, description, idempotency_key, created_at)
      VALUES
        (p_woman_id, v_woman_earn, 'gift',
         p_gift_name || ': ₹' || v_woman_earn,
         v_idem_woman, now());
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'man_charged', CASE WHEN v_is_super THEN 0 ELSE p_gift_value END,
    'woman_earned', CASE WHEN v_woman_indian THEN v_woman_earn ELSE 0 END,
    'platform_earned', v_platform_take,
    'woman_is_indian', v_woman_indian,
    'super_user', v_is_super
  );
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- 3. process_audio_billing — Indian gate + women_earnings audit
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_audio_billing(
  p_session_id text,
  p_man_id uuid,
  p_woman_id uuid,
  p_minutes numeric,
  p_idempotency text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_pricing record; v_man_charge numeric; v_woman_earn numeric;
  v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_idem text; v_idem_w text; v_session_uuid uuid;
  v_woman_indian boolean := false;
BEGIN
  IF p_idempotency IS NULL OR length(p_idempotency) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'idempotency_key_required');
  END IF;

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_man_charge := ROUND(p_minutes * COALESCE(v_pricing.audio_rate_per_minute, 6.00), 2);

  SELECT COALESCE(
    (SELECT fp.is_indian FROM public.female_profiles fp WHERE fp.user_id = p_woman_id LIMIT 1),
    (SELECT pr.is_indian FROM public.profiles pr WHERE pr.user_id = p_woman_id LIMIT 1),
    false
  ) INTO v_woman_indian;

  v_woman_earn := CASE WHEN v_woman_indian
                       THEN ROUND(p_minutes * COALESCE(v_pricing.audio_women_earning_rate, 3.00), 2)
                       ELSE 0 END;

  v_idem   := 'audio_m:' || p_idempotency;
  v_idem_w := 'audio_w:' || p_idempotency;
  v_session_uuid := CASE WHEN p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                         THEN p_session_id::uuid ELSE NULL END;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
  END IF;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance
  FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
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
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_w) THEN
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

      INSERT INTO public.women_earnings
        (user_id, amount, earning_type, description, idempotency_key, created_at)
      VALUES (p_woman_id, v_woman_earn, 'audio_call',
              'Audio: ' || ROUND(p_minutes,2) || ' min', v_idem_w, now());
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', v_man_charge, 'earned', v_woman_earn,
    'man_charged', v_man_charge, 'woman_earned', v_woman_earn, 'woman_is_indian', v_woman_indian);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- 4. process_video_billing_v2 — Indian gate + audit
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_video_billing_v2(
  p_session_id text,
  p_man_id uuid,
  p_woman_id uuid,
  p_minutes numeric,
  p_idempotency text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_pricing record; v_man_charge numeric; v_woman_earn numeric;
  v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_idem text; v_idem_w text; v_session_uuid uuid;
  v_woman_indian boolean := false;
BEGIN
  IF p_idempotency IS NULL OR length(p_idempotency) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'idempotency_key_required');
  END IF;

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_man_charge := ROUND(p_minutes * COALESCE(v_pricing.video_rate_per_minute, 8.00), 2);

  SELECT COALESCE(
    (SELECT fp.is_indian FROM public.female_profiles fp WHERE fp.user_id = p_woman_id LIMIT 1),
    (SELECT pr.is_indian FROM public.profiles pr WHERE pr.user_id = p_woman_id LIMIT 1),
    false
  ) INTO v_woman_indian;

  v_woman_earn := CASE WHEN v_woman_indian
                       THEN ROUND(p_minutes * COALESCE(v_pricing.video_women_earning_rate, 4.00), 2)
                       ELSE 0 END;

  v_idem   := 'video_m:' || p_idempotency;
  v_idem_w := 'video_w:' || p_idempotency;
  v_session_uuid := CASE WHEN p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                         THEN p_session_id::uuid ELSE NULL END;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
  END IF;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance
  FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
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
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_w) THEN
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

      INSERT INTO public.women_earnings
        (user_id, amount, earning_type, description, idempotency_key, created_at)
      VALUES (p_woman_id, v_woman_earn, 'video_call',
              'Video: ' || ROUND(p_minutes,2) || ' min', v_idem_w, now());
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', v_man_charge, 'earned', v_woman_earn,
    'man_charged', v_man_charge, 'woman_earned', v_woman_earn, 'woman_is_indian', v_woman_indian);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- 5. process_group_billing_v2 — correct labels + Indian gate
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_group_billing_v2(
  p_group_id text,
  p_session_id text,
  p_host_id uuid,
  p_man_ids uuid[],
  p_minutes numeric,
  p_idempotency text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_pricing record; v_rate_per_man numeric; v_earn_per_man numeric;
  v_man_id uuid; v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_total_earned numeric := 0; v_active_count int := 0;
  v_removed_men uuid[] := '{}'; v_idem text; v_idem_man text; v_idem_woman text;
  v_session_uuid uuid;
  v_host_indian boolean := false;
BEGIN
  IF p_idempotency IS NULL OR length(p_idempotency) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'idempotency_key_required');
  END IF;

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_rate_per_man := ROUND(p_minutes * COALESCE(v_pricing.group_call_rate_per_minute, 4.00), 2);
  v_earn_per_man := ROUND(p_minutes * COALESCE(v_pricing.group_call_women_earning_rate, 0.50), 2);
  v_idem := p_idempotency;
  v_session_uuid := CASE WHEN p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                         THEN p_session_id::uuid ELSE NULL END;

  SELECT COALESCE(
    (SELECT fp.is_indian FROM public.female_profiles fp WHERE fp.user_id = p_host_id LIMIT 1),
    (SELECT pr.is_indian FROM public.profiles pr WHERE pr.user_id = p_host_id LIMIT 1),
    false
  ) INTO v_host_indian;

  FOREACH v_man_id IN ARRAY p_man_ids LOOP
    v_idem_man := 'pgrp_m:' || v_idem || ':' || v_man_id::text;
    IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_man) THEN
      v_active_count := v_active_count + 1;
      IF v_host_indian THEN v_total_earned := v_total_earned + v_earn_per_man; END IF;
      CONTINUE;
    END IF;

    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets WHERE user_id = v_man_id FOR UPDATE;

    IF v_man_wallet_id IS NULL OR COALESCE(v_man_balance, 0) < v_rate_per_man THEN
      v_removed_men := array_append(v_removed_men, v_man_id);
      CONTINUE;
    END IF;

    UPDATE public.wallets SET balance = balance - v_rate_per_man, updated_at = NOW()
     WHERE id = v_man_wallet_id RETURNING balance INTO v_man_balance;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, amount, description, session_id,
      balance_after, idempotency_key, status, duration_seconds, rate_per_minute
    ) VALUES (
      v_man_wallet_id, v_man_id, 'debit', 'private_group_call_charge', v_rate_per_man,
      'Private Group Call: ' || ROUND(p_minutes,2) || ' min @ ₹' || COALESCE(v_pricing.group_call_rate_per_minute,4.00) || '/min',
      v_session_uuid, v_man_balance, v_idem_man, 'completed',
      ROUND(p_minutes*60)::int, COALESCE(v_pricing.group_call_rate_per_minute,4.00)
    );

    v_active_count := v_active_count + 1;
    IF v_host_indian THEN v_total_earned := v_total_earned + v_earn_per_man; END IF;
  END LOOP;

  IF v_host_indian AND v_total_earned > 0 THEN
    v_idem_woman := 'pgrp_w:' || v_idem || ':' || p_host_id::text;
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets WHERE user_id = p_host_id FOR UPDATE;

    IF v_woman_wallet_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_woman) THEN
      UPDATE public.wallets SET balance = balance + v_total_earned, updated_at = NOW()
       WHERE id = v_woman_wallet_id RETURNING balance INTO v_woman_balance;
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, session_id,
        balance_after, idempotency_key, status, duration_seconds, rate_per_minute
      ) VALUES (
        v_woman_wallet_id, p_host_id, 'credit', 'private_group_call_earning', v_total_earned,
        'Private Group Call Earning: ' || ROUND(p_minutes,2) || ' min × ' || v_active_count || ' men',
        v_session_uuid, v_woman_balance, v_idem_woman, 'completed',
        ROUND(p_minutes*60)::int, COALESCE(v_pricing.group_call_women_earning_rate,0.50)
      );

      INSERT INTO public.women_earnings
        (user_id, amount, earning_type, description, idempotency_key, created_at)
      VALUES (p_host_id, v_total_earned, 'group_call',
              'Private Group: ' || v_active_count || ' men × ' || ROUND(p_minutes,2) || ' min',
              v_idem_woman, now());
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'active_count', v_active_count,
    'host_earned', CASE WHEN v_host_indian THEN v_total_earned ELSE 0 END,
    'host_is_indian', v_host_indian,
    'removed_men', v_removed_men);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- 6. Backfill historical women_earnings → wallet_transactions
-- ============================================================
INSERT INTO public.wallet_transactions
  (user_id, type, transaction_type, amount, description, session_id,
   balance_after, idempotency_key, status, created_at)
SELECT
  we.user_id,
  'credit',
  CASE we.earning_type
    WHEN 'chat'        THEN 'chat_earning'
    WHEN 'audio_call'  THEN 'audio_call_earning'
    WHEN 'video_call'  THEN 'video_call_earning'
    WHEN 'group_call'  THEN 'private_group_call_earning'
    WHEN 'gift'        THEN 'gift_earning'
    ELSE we.earning_type || '_earning'
  END,
  we.amount,
  COALESCE(we.description, we.earning_type || ' earning (backfill)'),
  COALESCE(we.chat_session_id, we.video_session_id, we.private_call_id),
  NULL,
  'backfill:we:' || we.id::text,
  'completed',
  we.created_at
FROM public.women_earnings we
WHERE NOT EXISTS (
  SELECT 1 FROM public.wallet_transactions wt
  WHERE wt.idempotency_key = 'backfill:we:' || we.id::text
)
AND (we.idempotency_key IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.wallet_transactions wt2
       WHERE wt2.idempotency_key = we.idempotency_key
     ));

-- ============================================================
-- 7. Permissions
-- ============================================================
REVOKE ALL ON FUNCTION public.process_gift_billing(uuid, uuid, numeric, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.process_gift_billing(uuid, uuid, numeric, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.process_audio_billing(text, uuid, uuid, numeric, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.process_audio_billing(text, uuid, uuid, numeric, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.process_video_billing_v2(text, uuid, uuid, numeric, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.process_video_billing_v2(text, uuid, uuid, numeric, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.process_group_billing_v2(text, text, uuid, uuid[], numeric, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.process_group_billing_v2(text, text, uuid, uuid[], numeric, text) TO authenticated, service_role;
