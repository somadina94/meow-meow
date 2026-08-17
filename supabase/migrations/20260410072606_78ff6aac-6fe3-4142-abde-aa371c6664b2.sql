-- Fix ledger_bill_session to also write to ledger_transactions
CREATE OR REPLACE FUNCTION public.ledger_bill_session(
  p_session_id uuid, p_session_type text, p_man_id uuid, p_woman_id uuid,
  p_man_charge numeric, p_woman_earn numeric, p_minute_number integer,
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
BEGIN
  v_idem_key := p_session_type || ':' || p_session_id::text || ':min:' || p_minute_number::text;
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'idempotency_key', v_idem_key);
  END IF;

  IF ROUND(p_woman_earn, 2) <> ROUND(p_man_charge / 2.0, 2) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Half-rule violation');
  END IF;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
  IF v_man_balance IS NULL OR v_man_balance < p_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'balance', COALESCE(v_man_balance, 0), 'required', p_man_charge);
  END IF;

  UPDATE public.wallets SET balance = balance - p_man_charge, updated_at = now() WHERE id = v_man_wallet_id;

  INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
  VALUES (p_man_id, 'debit', p_session_type || '_charge', p_man_charge,
    initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_man_charge || '/min',
    p_session_id, (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id), v_idem_key, 'completed',
    COALESCE(p_duration_seconds, 60), p_man_charge);

  -- Write to ledger_transactions for statement visibility (man debit)
  INSERT INTO public.ledger_transactions (user_id, session_id, transaction_type, debit, credit, rate_per_minute, duration_seconds, counterparty_id, reference_id, description)
  VALUES (p_man_id, p_session_id, p_session_type || '_charge', p_man_charge, 0, p_man_charge, COALESCE(p_duration_seconds, 60), p_woman_id, v_idem_key,
    initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_man_charge || '/min');

  PERFORM public.safe_ledger_insert(
    p_man_id, p_session_id, p_session_type || '_charge',
    p_man_charge, 0, p_man_charge, COALESCE(p_duration_seconds, 60), p_woman_id,
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
    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
    VALUES (p_woman_id, 'credit', p_session_type || '_earning', p_woman_earn,
      initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min (½ of ₹' || p_man_charge || ')',
      p_session_id, (SELECT balance FROM public.wallets WHERE id = v_woman_wallet), v_idem_key_woman, 'completed',
      COALESCE(p_duration_seconds, 60), p_woman_earn);

    -- Write to ledger_transactions for statement visibility (woman earning)
    INSERT INTO public.ledger_transactions (user_id, session_id, transaction_type, debit, credit, rate_per_minute, duration_seconds, counterparty_id, reference_id, description)
    VALUES (p_woman_id, p_session_id, p_session_type || '_earning', 0, p_woman_earn, p_woman_earn, COALESCE(p_duration_seconds, 60), p_man_id, v_idem_key_woman,
      initcap(replace(p_session_type,'_',' ')) || ' earning: min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min');

    PERFORM public.safe_ledger_insert(
      p_woman_id, p_session_id, 'earning',
      0, p_woman_earn, p_woman_earn, COALESCE(p_duration_seconds, 60), p_man_id,
      v_idem_key_woman, initcap(replace(p_session_type,'_',' ')) || ' earning: min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min', now()
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', p_man_charge,
    'earned', p_woman_earn,
    'minute_number', p_minute_number, 'idempotency_key', v_idem_key);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;


-- Fix process_call_billing to also write to ledger_transactions
CREATE OR REPLACE FUNCTION public.process_call_billing(p_call_id text, p_call_type text DEFAULT 'video')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_session       record;
  v_pricing       record;
  v_minutes       numeric;
  v_seconds       integer;
  v_man_charge    numeric;
  v_woman_earn    numeric;
  v_rate          numeric;
  v_man_wallet_id uuid;
  v_man_balance   numeric;
  v_woman_wallet_id uuid;
  v_woman_balance numeric;
  v_idem_key      text;
  v_idem_key_w    text;
BEGIN
  SELECT * INTO v_session
  FROM public.video_call_sessions
  WHERE call_id = p_call_id AND status IN ('completed', 'ended');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Session not found or not in completed/ended status');
  END IF;

  IF v_session.total_earned > 0 OR v_session.total_minutes > 0 THEN
    RETURN jsonb_build_object('success', true, 'already_billed', true,
      'total_minutes', v_session.total_minutes,
      'man_charged', v_session.total_minutes * v_session.rate_per_minute,
      'woman_earned', v_session.total_earned);
  END IF;

  IF v_session.started_at IS NULL OR v_session.ended_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Missing start or end timestamp');
  END IF;

  v_seconds := EXTRACT(EPOCH FROM (v_session.ended_at - v_session.started_at))::integer;
  v_minutes := v_seconds / 60.0;

  IF v_minutes <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid call duration');
  END IF;

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active pricing found');
  END IF;

  IF p_call_type = 'audio' THEN
    v_rate := v_pricing.audio_rate_per_minute;
  ELSE
    v_rate := v_pricing.video_rate_per_minute;
  END IF;

  v_man_charge := ROUND(v_minutes * v_rate, 2);
  v_woman_earn := ROUND(v_man_charge / 2.0, 2);

  v_idem_key := p_call_type || '_call:' || p_call_id;
  v_idem_key_w := p_call_type || '_call_earn:' || p_call_id;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'already_billed', true, 'idempotency_key', v_idem_key);
  END IF;

  -- 1. Debit man's wallet
  SELECT id, balance INTO v_man_wallet_id, v_man_balance
  FROM public.wallets WHERE user_id = v_session.man_user_id FOR UPDATE;

  IF v_man_wallet_id IS NOT NULL THEN
    UPDATE public.wallets SET balance = GREATEST(balance - v_man_charge, 0), updated_at = now()
    WHERE id = v_man_wallet_id;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, amount, description,
      balance_after, idempotency_key, status, duration_seconds, rate_per_minute
    ) VALUES (
      v_man_wallet_id, v_session.man_user_id, 'debit', p_call_type || '_call_charge', v_man_charge,
      initcap(p_call_type) || ' Call: ' || ROUND(v_minutes, 1) || ' min @ ₹' || v_rate || '/min',
      (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id),
      v_idem_key, 'completed', v_seconds, v_rate
    );

    -- Write to ledger_transactions for statement visibility
    INSERT INTO public.ledger_transactions (user_id, transaction_type, debit, credit, rate_per_minute, duration_seconds, counterparty_id, reference_id, description)
    VALUES (v_session.man_user_id, p_call_type || '_call_charge', v_man_charge, 0, v_rate, v_seconds, v_session.woman_user_id, v_idem_key,
      initcap(p_call_type) || ' Call: ' || ROUND(v_minutes, 1) || ' min @ ₹' || v_rate || '/min');
  END IF;

  -- 2. Credit woman's wallet
  IF v_woman_earn > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;

    IF v_woman_wallet_id IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_woman_earn, updated_at = now()
      WHERE id = v_woman_wallet_id;

      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description,
        balance_after, idempotency_key, status, duration_seconds, rate_per_minute
      ) VALUES (
        v_woman_wallet_id, v_session.woman_user_id, 'credit', p_call_type || '_call_earning', v_woman_earn,
        initcap(p_call_type) || ' Call Earning: ' || ROUND(v_minutes, 1) || ' min @ ₹' || v_woman_earn || '/min (½ of ₹' || v_man_charge || ')',
        (SELECT balance FROM public.wallets WHERE id = v_woman_wallet_id),
        v_idem_key_w, 'completed', v_seconds, ROUND(v_rate / 2.0, 2)
      );

      -- Write to ledger_transactions for statement visibility
      INSERT INTO public.ledger_transactions (user_id, transaction_type, debit, credit, rate_per_minute, duration_seconds, counterparty_id, reference_id, description)
      VALUES (v_session.woman_user_id, p_call_type || '_call_earning', 0, v_woman_earn, ROUND(v_rate / 2.0, 2), v_seconds, v_session.man_user_id, v_idem_key_w,
        initcap(p_call_type) || ' Call Earning: ' || ROUND(v_minutes, 1) || ' min @ ₹' || v_woman_earn || '/min');
    END IF;

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, rate_per_minute, minutes_billed)
    VALUES (v_session.woman_user_id, v_woman_earn, p_call_type || '_call',
      initcap(p_call_type) || ' Call Earning: ' || ROUND(v_minutes, 1) || ' min',
      ROUND(v_rate / 2.0, 2), ROUND(v_minutes, 2));
  END IF;

  -- Update session totals
  UPDATE public.video_call_sessions
  SET total_minutes = ROUND(v_minutes, 2), total_earned = v_woman_earn
  WHERE call_id = p_call_id;

  RETURN jsonb_build_object('success', true, 'minutes', ROUND(v_minutes, 2),
    'man_charged', v_man_charge, 'woman_earned', v_woman_earn,
    'rate', v_rate, 'duration_seconds', v_seconds);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;


-- Fix ledger_bill_group_call to also write to ledger_transactions
CREATE OR REPLACE FUNCTION public.ledger_bill_group_call(
  p_session_id uuid, p_woman_id uuid, p_man_ids uuid[],
  p_minute_number integer, p_charge_per_man numeric, p_earn_per_man numeric,
  p_duration_seconds integer DEFAULT 60
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_man_id uuid;
  v_ref_man text;
  v_ref_woman text;
  v_total_woman_earn numeric := 0;
  v_man_balance numeric;
  v_fraction numeric;
  v_actual_charge numeric;
  v_actual_earn numeric;
BEGIN
  v_fraction := GREATEST(p_duration_seconds, 0)::numeric / 60.0;
  v_actual_charge := ROUND(p_charge_per_man * v_fraction, 2);
  v_actual_earn := ROUND(p_earn_per_man * v_fraction, 2);

  IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE user_id = p_woman_id) THEN
    INSERT INTO public.wallets (user_id, balance, currency, gender) VALUES (p_woman_id, 0, 'INR', 'female') ON CONFLICT (user_id) DO NOTHING;
  END IF;

  FOREACH v_man_id IN ARRAY p_man_ids LOOP
    v_ref_man   := p_session_id::text || '_' || v_man_id::text || '_grp' || p_minute_number::text;
    v_ref_woman := p_session_id::text || '_' || p_woman_id::text || '_grpearn_' || v_man_id::text || '_' || p_minute_number::text;

    CONTINUE WHEN EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_ref_man);

    SELECT balance INTO v_man_balance FROM public.wallets WHERE user_id = v_man_id FOR UPDATE;
    CONTINUE WHEN v_man_balance IS NULL OR v_man_balance < v_actual_charge;

    UPDATE public.wallets SET balance = balance - v_actual_charge, updated_at = now() WHERE user_id = v_man_id;

    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
    VALUES (v_man_id, 'debit', 'group_call_charge', v_actual_charge,
      'Group Call: ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_charge_per_man || '/min',
      p_session_id, (SELECT balance FROM public.wallets WHERE user_id = v_man_id), v_ref_man, 'completed',
      p_duration_seconds, p_charge_per_man);

    -- Write to ledger_transactions for statement visibility (man debit)
    INSERT INTO public.ledger_transactions (user_id, session_id, transaction_type, debit, credit, rate_per_minute, duration_seconds, counterparty_id, reference_id, description)
    VALUES (v_man_id, p_session_id, 'group_call_charge', v_actual_charge, 0, p_charge_per_man, p_duration_seconds, p_woman_id, v_ref_man,
      'Group Call: ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_charge_per_man || '/min');

    PERFORM public.safe_ledger_insert(v_man_id, p_session_id, 'group_call_charge', v_actual_charge, 0,
      p_charge_per_man, p_duration_seconds, p_woman_id, v_ref_man,
      'Group call charge ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's', now());

    v_total_woman_earn := v_total_woman_earn + v_actual_earn;

    PERFORM public.safe_ledger_insert(p_woman_id, p_session_id, 'earning', 0, v_actual_earn,
      p_earn_per_man, p_duration_seconds, v_man_id, v_ref_woman,
      'Group call earning ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's', now());

    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
    VALUES (p_woman_id, 'credit', 'group_call_earning', v_actual_earn,
      'Group Call Earning: ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_earn_per_man || '/man',
      p_session_id, NULL, v_ref_woman, 'completed',
      p_duration_seconds, p_earn_per_man);

    -- Write to ledger_transactions for statement visibility (woman earning)
    INSERT INTO public.ledger_transactions (user_id, session_id, transaction_type, debit, credit, rate_per_minute, duration_seconds, counterparty_id, reference_id, description)
    VALUES (p_woman_id, p_session_id, 'group_call_earning', 0, v_actual_earn, p_earn_per_man, p_duration_seconds, v_man_id, v_ref_woman,
      'Group Call Earning: ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_earn_per_man || '/man');

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, group_id, man_user_id, rate_per_minute, minutes_billed, created_at)
    VALUES (p_woman_id, v_actual_earn, 'group_call',
      'Group call earning ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_earn_per_man || '/man',
      p_session_id, v_man_id, p_earn_per_man, v_fraction, now());
  END LOOP;

  IF v_total_woman_earn > 0 THEN
    UPDATE public.wallets SET balance = balance + v_total_woman_earn, updated_at = now() WHERE user_id = p_woman_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'minute', p_minute_number, 'woman_earned', v_total_woman_earn, 'duration_seconds', p_duration_seconds);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;