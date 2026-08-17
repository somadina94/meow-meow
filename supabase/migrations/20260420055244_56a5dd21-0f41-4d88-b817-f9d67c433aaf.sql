-- ─────────────────────────────────────────────────────────────────────────
-- 1) Fix ledger_bill_session: tag woman earning as <session_type>_earning
--    so it appears in the Statement screen alongside men's *_charge rows.
--    This is the canonical per-minute billing engine for chat/audio/video.
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.ledger_bill_session(
  p_session_id uuid, p_session_type text, p_man_id uuid, p_woman_id uuid,
  p_man_charge numeric, p_woman_earn numeric, p_minute_number integer
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_idem_key text;
  v_idem_key_woman text;
  v_man_wallet_id uuid;
  v_man_balance numeric;
  v_woman_wallet uuid;
BEGIN
  v_idem_key := p_session_type || ':' || p_session_id::text || ':min:' || p_minute_number::text;
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'idempotency_key', v_idem_key);
  END IF;

  IF ROUND(p_woman_earn, 2) <> ROUND(p_man_charge / 2.0, 2) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Half-rule violation');
  END IF;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance
  FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
  IF v_man_balance IS NULL OR v_man_balance < p_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance',
      'balance', COALESCE(v_man_balance, 0), 'required', p_man_charge);
  END IF;

  UPDATE public.wallets SET balance = balance - p_man_charge, updated_at = now() WHERE id = v_man_wallet_id;

  INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description,
    session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
  VALUES (p_man_id, 'debit', p_session_type || '_charge', p_man_charge,
    initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_man_charge || '/min',
    p_session_id, (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id), v_idem_key, 'completed',
    60, p_man_charge);

  PERFORM public.safe_ledger_insert(
    p_man_id, p_session_id, p_session_type || '_charge',
    p_man_charge, 0, p_man_charge, 60, p_woman_id,
    v_idem_key, initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_man_charge || '/min', now()
  );

  IF p_woman_earn > 0 THEN
    SELECT id INTO v_woman_wallet FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF v_woman_wallet IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + p_woman_earn, updated_at = now() WHERE id = v_woman_wallet;
    END IF;

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, rate_per_minute, minutes_billed, created_at)
    VALUES (p_woman_id, p_woman_earn, p_session_type,
      initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min (½ of ₹' || p_man_charge || ')',
      p_woman_earn, 1, now());

    v_idem_key_woman := p_session_type || ':' || p_session_id::text || ':earn:' || p_minute_number::text;
    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description,
      session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
    VALUES (p_woman_id, 'credit', p_session_type || '_earning', p_woman_earn,
      initcap(replace(p_session_type,'_',' ')) || ' Earning: min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min (½ of ₹' || p_man_charge || ')',
      p_session_id, (SELECT balance FROM public.wallets WHERE id = v_woman_wallet), v_idem_key_woman, 'completed',
      60, p_woman_earn);

    -- FIX: tag as <session_type>_earning (was generic 'earning') so Statement displays it
    PERFORM public.safe_ledger_insert(
      p_woman_id, p_session_id, p_session_type || '_earning',
      0, p_woman_earn, p_woman_earn, 60, p_man_id,
      v_idem_key_woman,
      initcap(replace(p_session_type,'_',' ')) || ' Earning: min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min', now()
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', p_man_charge,
    'earned', p_woman_earn, 'minute_number', p_minute_number, 'idempotency_key', v_idem_key);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2) Same fix for the second ledger_bill_session overload (text session_id,
--    duration_seconds support — used by partial-minute billing).
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.ledger_bill_session(
  p_session_id text, p_session_type text, p_man_id uuid, p_woman_id uuid,
  p_minute_number integer, p_man_charge numeric, p_woman_earn numeric,
  p_duration_seconds integer DEFAULT 60
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_idem_key text;
  v_idem_key_woman text;
  v_man_wallet_id uuid;
  v_man_balance numeric;
  v_woman_wallet uuid;
  v_fraction numeric;
  v_actual_charge numeric;
  v_actual_earn numeric;
  v_session_uuid uuid;
BEGIN
  v_fraction := GREATEST(p_duration_seconds, 0)::numeric / 60.0;
  v_actual_charge := ROUND(p_man_charge * v_fraction, 2);
  v_actual_earn := ROUND(p_woman_earn * v_fraction, 2);

  v_idem_key := p_session_type || ':' || p_session_id || ':min:' || p_minute_number::text;
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'idempotency_key', v_idem_key);
  END IF;

  BEGIN v_session_uuid := p_session_id::uuid; EXCEPTION WHEN OTHERS THEN v_session_uuid := NULL; END;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance
  FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
  IF v_man_balance IS NULL OR v_man_balance < v_actual_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance',
      'balance', COALESCE(v_man_balance, 0), 'required', v_actual_charge);
  END IF;

  UPDATE public.wallets SET balance = balance - v_actual_charge, updated_at = now() WHERE id = v_man_wallet_id;

  INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description,
    session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
  VALUES (p_man_id, 'debit', p_session_type || '_charge', v_actual_charge,
    initcap(replace(p_session_type,'_',' ')) || ': ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_man_charge || '/min',
    v_session_uuid, (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id), v_idem_key, 'completed',
    p_duration_seconds, p_man_charge);

  PERFORM public.safe_ledger_insert(
    p_man_id, v_session_uuid, p_session_type || '_charge',
    v_actual_charge, 0, p_man_charge, p_duration_seconds, p_woman_id,
    v_idem_key,
    initcap(replace(p_session_type,'_',' ')) || ': ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_man_charge || '/min', now()
  );

  IF v_actual_earn > 0 THEN
    SELECT id INTO v_woman_wallet FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF v_woman_wallet IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_actual_earn, updated_at = now() WHERE id = v_woman_wallet;
    END IF;

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, rate_per_minute, minutes_billed, created_at)
    VALUES (p_woman_id, v_actual_earn, p_session_type,
      initcap(replace(p_session_type,'_',' ')) || ' Earning: ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's',
      p_woman_earn, ROUND(v_fraction, 2), now());

    v_idem_key_woman := p_session_type || ':' || p_session_id || ':earn:' || p_minute_number::text;
    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description,
      session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
    VALUES (p_woman_id, 'credit', p_session_type || '_earning', v_actual_earn,
      initcap(replace(p_session_type,'_',' ')) || ' Earning: ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_woman_earn || '/min',
      v_session_uuid, (SELECT balance FROM public.wallets WHERE id = v_woman_wallet), v_idem_key_woman, 'completed',
      p_duration_seconds, p_woman_earn);

    -- FIX: tag as <session_type>_earning (was generic 'earning') so Statement displays it
    PERFORM public.safe_ledger_insert(
      p_woman_id, v_session_uuid, p_session_type || '_earning',
      0, v_actual_earn, p_woman_earn, p_duration_seconds, p_man_id,
      v_idem_key_woman,
      initcap(replace(p_session_type,'_',' ')) || ' Earning: ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's', now()
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', v_actual_charge,
    'earned', v_actual_earn, 'minute_number', p_minute_number, 'idempotency_key', v_idem_key);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- ─────────────────────────────────────────────────────────────────────────
-- 3) Backfill: re-tag historical women earnings rows that were inserted with
--    the generic 'earning' type so they appear in past Statement views.
-- ─────────────────────────────────────────────────────────────────────────

UPDATE public.ledger_transactions
   SET transaction_type = 'chat_earning'
 WHERE transaction_type = 'earning'
   AND (description ILIKE 'Chat earning%' OR description ILIKE 'Chat:%' OR description ILIKE 'Chat Earning%');

UPDATE public.ledger_transactions
   SET transaction_type = 'audio_call_earning'
 WHERE transaction_type = 'earning'
   AND (description ILIKE 'Audio%earning%' OR description ILIKE 'Audio call%earning%' OR description ILIKE 'Audio Call%');

UPDATE public.ledger_transactions
   SET transaction_type = 'video_call_earning'
 WHERE transaction_type = 'earning'
   AND (description ILIKE 'Video%earning%' OR description ILIKE 'Video call%earning%' OR description ILIKE 'Video Call%');

-- ─────────────────────────────────────────────────────────────────────────
-- 4) Disable the legacy duplicate process_video_billing(uuid, integer)
--    that wrote to wallets but bypassed ledger_transactions. The end-of-call
--    process_call_billing path is the SSOT for video/audio calls.
--    We keep the function signature (clients still call it) but make it a
--    no-op that returns duplicate_skipped to prevent any double-debit.
-- ─────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.process_video_billing(p_session_id uuid, p_minutes integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Deprecated: per-minute video billing replaced by end-of-call process_call_billing.
  -- Returning duplicate_skipped keeps clients functional without double-charging.
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true,
    'deprecated', true, 'note', 'Use process_call_billing at call end (SSOT = ledger_transactions).');
END;
$function$;

CREATE OR REPLACE FUNCTION public.process_video_billing(p_session_id uuid, p_minutes numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true,
    'deprecated', true, 'note', 'Use process_call_billing at call end (SSOT = ledger_transactions).');
END;
$function$;