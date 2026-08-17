
-- 1) Recreate ledger_bill_session with per-second billing support
DROP FUNCTION IF EXISTS public.ledger_bill_session(uuid,text,uuid,uuid,integer,numeric,numeric);

CREATE OR REPLACE FUNCTION public.ledger_bill_session(
  p_session_id uuid, p_session_type text, p_man_id uuid, p_woman_id uuid,
  p_minute_number integer, p_man_charge numeric, p_woman_earn numeric,
  p_duration_seconds integer DEFAULT 60
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_idem_key text;
  v_idem_key_woman text;
  v_man_wallet_id uuid;
  v_man_balance numeric;
  v_woman_wallet uuid;
  v_woman_indian boolean := false;
  v_actual_man_charge numeric;
  v_actual_woman_earn numeric;
  v_fraction numeric;
BEGIN
  -- Pro-rate the charge based on actual seconds
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
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'balance', COALESCE(v_man_balance, 0), 'required', v_actual_man_charge);
  END IF;

  UPDATE public.wallets SET balance = balance - v_actual_man_charge, updated_at = now() WHERE id = v_man_wallet_id;

  INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
  VALUES (p_man_id, 'debit', p_session_type || '_charge', v_actual_man_charge,
    initcap(replace(p_session_type,'_',' ')) || ': ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_man_charge || '/min',
    p_session_id, (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id), v_idem_key, 'completed',
    p_duration_seconds, p_man_charge);

  -- Ledger entry for man
  PERFORM public.safe_ledger_insert(p_man_id, p_session_id, p_session_type || '_charge', v_actual_man_charge, 0,
    p_man_charge, p_duration_seconds, p_woman_id, v_idem_key,
    initcap(replace(p_session_type,'_',' ')) || ': ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_man_charge || '/min',
    now());

  IF v_woman_indian AND v_actual_woman_earn > 0 THEN
    SELECT id INTO v_woman_wallet FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF v_woman_wallet IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_actual_woman_earn, updated_at = now() WHERE id = v_woman_wallet;
    END IF;

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, rate_per_minute, minutes_billed, created_at)
    VALUES (p_woman_id, v_actual_woman_earn, p_session_type,
      initcap(replace(p_session_type,'_',' ')) || ': ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_woman_earn || '/min',
      p_woman_earn, v_fraction, now());

    v_idem_key_woman := p_session_type || ':' || p_session_id::text || ':earn:' || p_minute_number::text;
    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
    VALUES (p_woman_id, 'credit', p_session_type, v_actual_woman_earn,
      initcap(replace(p_session_type,'_',' ')) || ': ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_woman_earn || '/min',
      p_session_id, (SELECT balance FROM public.wallets WHERE id = v_woman_wallet), v_idem_key_woman, 'completed',
      p_duration_seconds, p_woman_earn);

    -- Ledger entry for woman
    PERFORM public.safe_ledger_insert(p_woman_id, p_session_id, p_session_type || '_earning', 0, v_actual_woman_earn,
      p_woman_earn, p_duration_seconds, p_man_id, v_idem_key_woman,
      initcap(replace(p_session_type,'_',' ')) || ': ' || floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's @ ₹' || p_woman_earn || '/min',
      now());
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', v_actual_man_charge,
    'earned', CASE WHEN v_woman_indian THEN v_actual_woman_earn ELSE 0 END,
    'minute_number', p_minute_number, 'duration_seconds', p_duration_seconds,
    'idempotency_key', v_idem_key);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.ledger_bill_session(uuid, text, uuid, uuid, integer, numeric, numeric, integer) TO authenticated;

-- 2) Recreate ledger_bill_group_call with per-second billing support
DROP FUNCTION IF EXISTS public.ledger_bill_group_call(uuid,uuid,uuid[],integer,numeric,numeric);

CREATE OR REPLACE FUNCTION public.ledger_bill_group_call(
  p_session_id uuid, p_woman_id uuid, p_man_ids uuid[], p_minute_number integer,
  p_charge_per_man numeric, p_earn_per_man numeric,
  p_duration_seconds integer DEFAULT 60
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
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

GRANT EXECUTE ON FUNCTION public.ledger_bill_group_call(uuid, uuid, uuid[], integer, numeric, numeric, integer) TO authenticated;
