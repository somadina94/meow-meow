
-- ============================================================================
-- 1. BACKFILL: give every NULL idempotency_key row a deterministic key based on id
-- ============================================================================
UPDATE public.wallet_transactions
SET idempotency_key = 'legacy:' || id::text
WHERE idempotency_key IS NULL;

-- ============================================================================
-- 2. UNIFY GIFT/TIP NAMING: rename historical gift_debit→gift_charge, gift_credit→gift_earning
-- ============================================================================
UPDATE public.wallet_transactions SET transaction_type = 'gift_charge'
  WHERE transaction_type = 'gift_debit';
UPDATE public.wallet_transactions SET transaction_type = 'gift_earning'
  WHERE transaction_type = 'gift_credit';

-- ============================================================================
-- 3. ENFORCE NOT NULL idempotency_key going forward
-- ============================================================================
ALTER TABLE public.wallet_transactions
  ALTER COLUMN idempotency_key SET NOT NULL;

-- Unique index to absolutely prevent any future double-billing
CREATE UNIQUE INDEX IF NOT EXISTS ux_wallet_transactions_idempotency_key
  ON public.wallet_transactions (idempotency_key);

-- ============================================================================
-- 4. Helper: deterministic UUID from any text key (for session_id coercion)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.text_to_uuid(p_text text)
RETURNS uuid
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_text IS NULL THEN NULL
    WHEN p_text ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      THEN p_text::uuid
    ELSE (
      substr(md5(p_text), 1, 8) || '-' ||
      substr(md5(p_text), 9, 4) || '-' ||
      substr(md5(p_text), 13, 4) || '-' ||
      substr(md5(p_text), 17, 4) || '-' ||
      substr(md5(p_text), 21, 12)
    )::uuid
  END;
$$;

-- ============================================================================
-- 5. DROP LEGACY process_call_billing (superseded)
-- ============================================================================
DROP FUNCTION IF EXISTS public.process_call_billing(text, text);

-- ============================================================================
-- 6. process_audio_billing — fix session_id coercion, remove women_earnings dual-write
-- ============================================================================
CREATE OR REPLACE FUNCTION public.process_audio_billing(
  p_session_id text, p_man_id uuid, p_woman_id uuid, p_minutes numeric, p_idempotency text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
  v_session_uuid := public.text_to_uuid(p_session_id);

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
    reference_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute
  ) VALUES (
    v_man_wallet_id, p_man_id, 'debit', 'audio_call_charge', v_man_charge,
    'Audio Call: ' || ROUND(p_minutes,2) || ' min @ ₹' || COALESCE(v_pricing.audio_rate_per_minute,6.00) || '/min',
    v_session_uuid, p_session_id, v_man_balance, v_idem, 'completed',
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
        reference_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute
      ) VALUES (
        v_woman_wallet_id, p_woman_id, 'credit', 'audio_call_earning', v_woman_earn,
        'Audio Call Earning: ' || ROUND(p_minutes,2) || ' min @ ₹' || COALESCE(v_pricing.audio_women_earning_rate,3.00) || '/min',
        v_session_uuid, p_session_id, v_woman_balance, v_idem_w, 'completed',
        ROUND(p_minutes*60)::int, COALESCE(v_pricing.audio_women_earning_rate,3.00)
      );
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', v_man_charge, 'earned', v_woman_earn,
    'man_charged', v_man_charge, 'woman_earned', v_woman_earn, 'woman_is_indian', v_woman_indian);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ============================================================================
-- 7. process_video_billing_v2 — fix session_id coercion, remove women_earnings dual-write
-- ============================================================================
CREATE OR REPLACE FUNCTION public.process_video_billing_v2(
  p_session_id text, p_man_id uuid, p_woman_id uuid, p_minutes numeric, p_idempotency text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
  v_session_uuid := public.text_to_uuid(p_session_id);

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
    reference_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute
  ) VALUES (
    v_man_wallet_id, p_man_id, 'debit', 'video_call_charge', v_man_charge,
    'Video Call: ' || ROUND(p_minutes,2) || ' min @ ₹' || COALESCE(v_pricing.video_rate_per_minute,8.00) || '/min',
    v_session_uuid, p_session_id, v_man_balance, v_idem, 'completed',
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
        reference_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute
      ) VALUES (
        v_woman_wallet_id, p_woman_id, 'credit', 'video_call_earning', v_woman_earn,
        'Video Call Earning: ' || ROUND(p_minutes,2) || ' min @ ₹' || COALESCE(v_pricing.video_women_earning_rate,4.00) || '/min',
        v_session_uuid, p_session_id, v_woman_balance, v_idem_w, 'completed',
        ROUND(p_minutes*60)::int, COALESCE(v_pricing.video_women_earning_rate,4.00)
      );
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', v_man_charge, 'earned', v_woman_earn,
    'man_charged', v_man_charge, 'woman_earned', v_woman_earn, 'woman_is_indian', v_woman_indian);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ============================================================================
-- 8. process_gift_billing — remove women_earnings dual-write
-- ============================================================================
CREATE OR REPLACE FUNCTION public.process_gift_billing(
  p_man_id uuid, p_woman_id uuid, p_gift_value numeric,
  p_gift_name text DEFAULT 'Gift', p_idempotency text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_pricing record; v_woman_pct numeric; v_woman_earn numeric;
  v_platform_take numeric;
  v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_woman_indian boolean := false; v_is_super boolean;
  v_idem_man text; v_idem_woman text;
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
    UPDATE public.wallets SET balance = balance - p_gift_value, updated_at = now()
     WHERE id = v_man_wallet_id RETURNING balance INTO v_man_balance;
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
      UPDATE public.wallets SET balance = balance + v_woman_earn, updated_at = now()
       WHERE id = v_woman_wallet_id RETURNING balance INTO v_woman_balance;
      INSERT INTO public.wallet_transactions
        (wallet_id, user_id, type, transaction_type, amount, description,
         balance_after, idempotency_key, status)
      VALUES
        (v_woman_wallet_id, p_woman_id, 'credit', 'gift_earning', v_woman_earn,
         p_gift_name || ': ₹' || v_woman_earn || ' (' || v_woman_pct || '% of ₹' || p_gift_value || ')',
         v_woman_balance, v_idem_woman, 'completed');
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true,
    'man_charged', CASE WHEN v_is_super THEN 0 ELSE p_gift_value END,
    'woman_earned', CASE WHEN v_woman_indian THEN v_woman_earn ELSE 0 END,
    'platform_earned', v_platform_take, 'woman_is_indian', v_woman_indian, 'super_user', v_is_super);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ============================================================================
-- 9. process_gift_transaction — Indian gating + deterministic idempotency
-- ============================================================================
CREATE OR REPLACE FUNCTION public.process_gift_transaction(
  p_sender_id uuid, p_receiver_id uuid, p_gift_id uuid, p_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_gift RECORD; v_wallet_id uuid; v_balance numeric; v_new_balance numeric;
  v_transaction_id uuid; v_gift_transaction_id uuid; v_is_super boolean;
  v_women_share numeric; v_woman_wallet_id uuid; v_woman_balance numeric;
  v_idem_man text; v_idem_woman text; v_woman_indian boolean := false;
BEGIN
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Gift not found'); END IF;

  IF EXISTS (
    SELECT 1 FROM public.gift_transactions
    WHERE sender_id = p_sender_id AND receiver_id = p_receiver_id
      AND gift_id = p_gift_id AND created_at > now() - interval '2 seconds'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_send_detected');
  END IF;

  v_is_super := public.should_bypass_balance(p_sender_id);
  v_women_share := ROUND(v_gift.price * 0.5, 2);

  SELECT COALESCE(
    (SELECT fp.is_indian FROM public.female_profiles fp WHERE fp.user_id = p_receiver_id LIMIT 1),
    (SELECT pr.is_indian FROM public.profiles pr WHERE pr.user_id = p_receiver_id LIMIT 1),
    false
  ) INTO v_woman_indian;

  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Wallet not found'); END IF;
  IF NOT v_is_super AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  v_new_balance := CASE WHEN v_is_super THEN v_balance ELSE v_balance - v_gift.price END;
  v_idem_man   := 'gift_m:' || p_sender_id::text || ':' || p_gift_id::text || ':' || (extract(epoch from clock_timestamp())*1000)::bigint::text;
  v_idem_woman := 'gift_w:' || replace(v_idem_man, 'gift_m:', '');

  UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, amount, description, balance_after, idempotency_key, status
  ) VALUES (
    v_wallet_id, p_sender_id, 'debit', 'gift_charge',
    CASE WHEN v_is_super THEN 0 ELSE v_gift.price END,
    'Gift: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_gift.price,
    v_new_balance, v_idem_man, 'completed'
  ) RETURNING id INTO v_transaction_id;

  IF v_woman_indian AND v_women_share > 0 THEN
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
    'gift_price', v_gift.price, 'women_share', CASE WHEN v_woman_indian THEN v_women_share ELSE 0 END,
    'super_user_bypass', v_is_super, 'woman_is_indian', v_woman_indian
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ============================================================================
-- 10. process_chat_billing — fix session_id link via reference (already UUID, OK), remove ledger dual-write — already clean, no change
--     Just update ledger_bill_session to remove women_earnings/safe_ledger_insert dual-writes
-- ============================================================================
CREATE OR REPLACE FUNCTION public.ledger_bill_session(
  p_session_id uuid, p_session_type text, p_man_id uuid, p_woman_id uuid,
  p_minute_number integer, p_man_charge numeric, p_woman_earn numeric, p_duration_seconds integer DEFAULT 60
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_idem_key text; v_idem_key_woman text;
  v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet uuid; v_woman_balance numeric;
  v_woman_indian boolean := false;
  v_actual_man_charge numeric; v_actual_woman_earn numeric;
  v_fraction numeric;
BEGIN
  v_fraction := GREATEST(p_duration_seconds, 0)::numeric / 60.0;
  v_actual_man_charge := ROUND(p_man_charge * v_fraction, 2);
  v_actual_woman_earn := ROUND(p_woman_earn * v_fraction, 2);

  v_idem_key := p_session_type || ':' || p_session_id::text || ':min:' || p_minute_number::text;
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'idempotency_key', v_idem_key);
  END IF;

  SELECT COALESCE(fp.is_indian, pr.is_indian, false) INTO v_woman_indian
  FROM public.profiles pr LEFT JOIN public.female_profiles fp ON fp.user_id = pr.user_id
  WHERE pr.user_id = p_woman_id;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
  IF v_man_balance IS NULL OR v_man_balance < v_actual_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  UPDATE public.wallets SET balance = balance - v_actual_man_charge, updated_at = now()
   WHERE id = v_man_wallet_id RETURNING balance INTO v_man_balance;

  INSERT INTO public.wallet_transactions (user_id, wallet_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
  VALUES (p_man_id, v_man_wallet_id, 'debit', p_session_type || '_charge', v_actual_man_charge,
    initcap(replace(p_session_type,'_',' ')) || ': ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_man_charge || '/min',
    p_session_id, v_man_balance, v_idem_key, 'completed',
    p_duration_seconds, p_man_charge);

  IF v_woman_indian AND v_actual_woman_earn > 0 THEN
    SELECT id, balance INTO v_woman_wallet, v_woman_balance FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF v_woman_wallet IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_actual_woman_earn, updated_at = now()
       WHERE id = v_woman_wallet RETURNING balance INTO v_woman_balance;

      v_idem_key_woman := p_session_type || ':' || p_session_id::text || ':earn:' || p_minute_number::text;
      INSERT INTO public.wallet_transactions (user_id, wallet_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
      VALUES (p_woman_id, v_woman_wallet, 'credit', p_session_type || '_earning', v_actual_woman_earn,
        initcap(replace(p_session_type,'_',' ')) || ' Earning: ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_woman_earn || '/min',
        p_session_id, v_woman_balance, v_idem_key_woman, 'completed',
        p_duration_seconds, p_woman_earn);
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'idempotency_key', v_idem_key,
    'man_charged', v_actual_man_charge, 'woman_earned', v_actual_woman_earn);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'idempotency_key', v_idem_key);
WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ============================================================================
-- 11. process_group_tip — add idempotency_key parameter to prevent duplicates
-- ============================================================================
DROP FUNCTION IF EXISTS public.process_group_tip(uuid, uuid, uuid, numeric, text);
DROP FUNCTION IF EXISTS public.process_group_tip(uuid, uuid, uuid, numeric, text, text);

CREATE OR REPLACE FUNCTION public.process_group_tip(
  p_man_id uuid, p_host_id uuid, p_group_id uuid, p_tip_value numeric,
  p_gift_name text DEFAULT 'Gift', p_idempotency text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_woman_share numeric; v_platform_take numeric;
  v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_woman_indian boolean := false; v_is_super boolean;
  v_idem_man text; v_idem_woman text;
BEGIN
  IF p_idempotency IS NULL OR length(p_idempotency) < 8 THEN
    p_idempotency := 'tip:' || p_man_id::text || ':' || p_group_id::text || ':' || (extract(epoch from clock_timestamp())*1000)::bigint::text;
  END IF;
  v_idem_man   := 'tip_m:' || p_idempotency;
  v_idem_woman := 'tip_w:' || p_idempotency;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_man) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
  END IF;

  v_woman_share := ROUND(p_tip_value * 0.5, 2);
  v_platform_take := p_tip_value - v_woman_share;

  SELECT COALESCE(
    (SELECT fp.is_indian FROM public.female_profiles fp WHERE fp.user_id = p_host_id LIMIT 1),
    (SELECT pr.is_indian FROM public.profiles pr WHERE pr.user_id = p_host_id LIMIT 1),
    false
  ) INTO v_woman_indian;

  v_is_super := public.should_bypass_balance(p_man_id);

  SELECT id, balance INTO v_man_wallet_id, v_man_balance
  FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
  IF v_man_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found');
  END IF;
  IF NOT v_is_super AND COALESCE(v_man_balance, 0) < p_tip_value THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance');
  END IF;

  IF NOT v_is_super THEN
    UPDATE public.wallets SET balance = balance - p_tip_value, updated_at = now()
     WHERE id = v_man_wallet_id RETURNING balance INTO v_man_balance;
  END IF;

  INSERT INTO public.wallet_transactions
    (wallet_id, user_id, type, transaction_type, amount, description, session_id,
     balance_after, idempotency_key, status)
  VALUES
    (v_man_wallet_id, p_man_id, 'debit', 'tip_charge',
     CASE WHEN v_is_super THEN 0 ELSE p_tip_value END,
     'Group Tip: ' || p_gift_name || ' — ₹' || p_tip_value,
     p_group_id, v_man_balance, v_idem_man, 'completed');

  IF v_woman_indian AND v_woman_share > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets WHERE user_id = p_host_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_woman_share, updated_at = now()
       WHERE id = v_woman_wallet_id RETURNING balance INTO v_woman_balance;
      INSERT INTO public.wallet_transactions
        (wallet_id, user_id, type, transaction_type, amount, description, session_id,
         balance_after, idempotency_key, status)
      VALUES
        (v_woman_wallet_id, p_host_id, 'credit', 'tip_earning', v_woman_share,
         'Group Tip Received: ' || p_gift_name || ' — ₹' || v_woman_share || ' (50% of ₹' || p_tip_value || ')',
         p_group_id, v_woman_balance, v_idem_woman, 'completed');
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true,
    'man_charged', CASE WHEN v_is_super THEN 0 ELSE p_tip_value END,
    'woman_earned', CASE WHEN v_woman_indian THEN v_woman_share ELSE 0 END,
    'platform_earned', v_platform_take, 'woman_is_indian', v_woman_indian, 'super_user', v_is_super);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;
