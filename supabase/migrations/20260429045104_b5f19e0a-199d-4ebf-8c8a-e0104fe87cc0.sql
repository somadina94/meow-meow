-- =====================================================================
-- UNIFY ALL FINANCIAL FLOWS ON wallet_transactions (Single Source of Truth)
-- =====================================================================

-- 1) Drop legacy / duplicate functions
DROP FUNCTION IF EXISTS public.process_withdrawal(uuid, numeric, text, text, text, text);
DROP FUNCTION IF EXISTS public.process_withdrawal_request(uuid, numeric, text, jsonb);
DROP FUNCTION IF EXISTS public.bill_session_minute(uuid, text, numeric, uuid, uuid, integer);

-- 2) Canonical session billing — mirrors to wallet_transactions
CREATE OR REPLACE FUNCTION public.bill_session_minute(
  p_session_id uuid,
  p_session_type text,
  p_minutes numeric,
  p_man_id uuid,
  p_woman_id uuid,
  p_man_count integer DEFAULT 1,
  p_minute_index integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_pricing jsonb;
  v_man_wallet RECORD;
  v_woman_wallet RECORD;
  v_man_rate numeric(10,2);
  v_woman_rate numeric(10,2);
  v_charge numeric(10,2);
  v_earn numeric(10,2);
  v_man_balance_after numeric(10,2);
  v_woman_balance_after numeric(10,2);
  v_idem_key text;
  v_idem_earn text;
  v_is_super boolean := false;
  v_minute_idx integer;
  v_label text;
BEGIN
  IF p_session_type NOT IN ('chat','audio_call','video_call','private_group_call') THEN
    RETURN jsonb_build_object('success',false,'error','Invalid session_type');
  END IF;
  IF p_minutes <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','minutes must be > 0');
  END IF;

  v_minute_idx := COALESCE(p_minute_index,
    FLOOR(EXTRACT(EPOCH FROM date_trunc('minute', now())) / 60)::integer);

  v_idem_key  := 'session|' || p_session_id::text || '|' || p_session_type
                  || '|' || p_man_id::text || '|' || v_minute_idx::text;
  v_idem_earn := 'session_earn|' || p_session_id::text || '|' || p_session_type
                  || '|' || COALESCE(p_woman_id::text,'na')
                  || '|' || p_man_id::text || '|' || v_minute_idx::text;

  -- Atomic dedupe via wallet_transactions UNIQUE(idempotency_key) — the SoT
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
  END IF;

  v_pricing := public.get_unified_pricing();
  v_man_rate := CASE p_session_type
    WHEN 'chat'               THEN (v_pricing->>'chat_man_rate')::numeric
    WHEN 'audio_call'         THEN (v_pricing->>'audio_man_rate')::numeric
    WHEN 'video_call'         THEN (v_pricing->>'video_man_rate')::numeric
    WHEN 'private_group_call' THEN (v_pricing->>'group_man_rate')::numeric
  END;
  v_woman_rate := CASE p_session_type
    WHEN 'chat'               THEN (v_pricing->>'chat_woman_rate')::numeric
    WHEN 'audio_call'         THEN (v_pricing->>'audio_woman_rate')::numeric
    WHEN 'video_call'         THEN (v_pricing->>'video_woman_rate')::numeric
    WHEN 'private_group_call' THEN (v_pricing->>'group_woman_rate')::numeric
  END;

  v_charge := ROUND(v_man_rate * p_minutes, 2);
  v_earn   := ROUND(v_woman_rate * p_minutes * GREATEST(p_man_count,1), 2);
  v_label  := initcap(replace(p_session_type,'_',' '));

  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id IN (SELECT user_id FROM public.profiles WHERE id = p_man_id)
      AND role IN ('admin','super_user')
  ) INTO v_is_super;

  -- ------- MAN DEBIT -------
  IF NOT v_is_super THEN
    SELECT * INTO v_man_wallet FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success',false,'error','Wallet not found');
    END IF;
    IF v_man_wallet.balance < v_charge THEN
      RETURN jsonb_build_object('success',false,'error','Insufficient balance',
        'balance',v_man_wallet.balance,'required',v_charge);
    END IF;
    v_man_balance_after := v_man_wallet.balance - v_charge;
    UPDATE public.wallets SET balance = v_man_balance_after, updated_at = now()
      WHERE id = v_man_wallet.id;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type, session_id,
      amount, balance_after, duration_seconds, rate_per_minute,
      description, idempotency_key, status
    ) VALUES (
      v_man_wallet.id, p_man_id, 'debit', p_session_type, p_session_type, p_session_id,
      v_charge, v_man_balance_after, ROUND(p_minutes * 60)::int, v_man_rate,
      v_label || ' — ' || p_minutes || ' min @ ₹' || v_man_rate || '/min',
      v_idem_key, 'completed'
    )
    ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  -- ------- WOMAN CREDIT (earnings) -------
  IF v_earn > 0 AND p_woman_id IS NOT NULL THEN
    SELECT * INTO v_woman_wallet FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF NOT FOUND THEN
      INSERT INTO public.wallets (user_id, gender, balance, currency)
      VALUES (p_woman_id, 'female', 0, 'INR')
      RETURNING * INTO v_woman_wallet;
    END IF;
    v_woman_balance_after := v_woman_wallet.balance + v_earn;
    UPDATE public.wallets SET balance = v_woman_balance_after, updated_at = now()
      WHERE id = v_woman_wallet.id;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type, session_id,
      amount, balance_after, duration_seconds, rate_per_minute,
      description, idempotency_key, status
    ) VALUES (
      v_woman_wallet.id, p_woman_id, 'credit',
      p_session_type || '_earning', p_session_type, p_session_id,
      v_earn, v_woman_balance_after, ROUND(p_minutes * 60)::int, v_woman_rate,
      v_label || ' earnings — ' || p_minutes || ' min @ ₹' || v_woman_rate || '/min',
      v_idem_earn, 'completed'
    )
    ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'success',true,'session_type',p_session_type,
    'charged',CASE WHEN v_is_super THEN 0 ELSE v_charge END,
    'earned',v_earn,'man_rate',v_man_rate,'woman_rate',v_woman_rate,
    'minutes',p_minutes,'super_user_skip',v_is_super,
    'minute_index',v_minute_idx
  );
END;
$function$;

-- 3) Canonical gift / tip — mirrors both sides into wallet_transactions
CREATE OR REPLACE FUNCTION public.bill_gift_or_tip(
  p_man_id uuid,
  p_woman_id uuid,
  p_amount numeric,
  p_type text,
  p_description text DEFAULT NULL,
  p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_pricing jsonb; v_man_wallet RECORD; v_woman_wallet RECORD;
  v_pct numeric(5,2); v_woman_credit numeric(10,2);
  v_man_balance_after numeric(10,2); v_woman_balance_after numeric(10,2);
  v_is_super boolean := false;
  v_idem_man text;
  v_idem_woman text;
  v_ref text;
BEGIN
  IF p_type NOT IN ('gift','tip') THEN
    RETURN jsonb_build_object('success',false,'error','type must be gift or tip');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','amount must be > 0');
  END IF;

  v_ref := COALESCE(NULLIF(p_reference_id, ''), gen_random_uuid()::text);
  v_idem_man   := p_type || '|' || p_man_id::text || '|' || COALESCE(p_woman_id::text,'') || '|' || v_ref;
  v_idem_woman := p_type || '_earn|' || COALESCE(p_woman_id::text,'') || '|' || p_man_id::text || '|' || v_ref;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_man) THEN
    RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
  END IF;

  v_pricing := public.get_unified_pricing();
  v_pct := CASE p_type
    WHEN 'gift' THEN (v_pricing->>'gift_woman_pct')::numeric
    ELSE (v_pricing->>'tip_woman_pct')::numeric
  END;
  v_woman_credit := ROUND(p_amount * v_pct / 100.0, 2);

  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id IN (SELECT user_id FROM public.profiles WHERE id = p_man_id)
      AND role IN ('admin','super_user')
  ) INTO v_is_super;

  IF NOT v_is_super THEN
    SELECT * INTO v_man_wallet FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success',false,'error','Wallet not found');
    END IF;
    IF v_man_wallet.balance < p_amount THEN
      RETURN jsonb_build_object('success',false,'error','Insufficient balance',
        'balance',v_man_wallet.balance,'required',p_amount);
    END IF;
    v_man_balance_after := v_man_wallet.balance - p_amount;
    UPDATE public.wallets SET balance = v_man_balance_after, updated_at = now()
      WHERE id = v_man_wallet.id;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type,
      amount, balance_after, description, reference_id, idempotency_key, status
    ) VALUES (
      v_man_wallet.id, p_man_id, 'debit', p_type, p_type,
      p_amount, v_man_balance_after,
      COALESCE(p_description, initcap(p_type) || ' sent — ₹' || p_amount),
      v_ref, v_idem_man, 'completed'
    )
    ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  IF v_woman_credit > 0 AND p_woman_id IS NOT NULL THEN
    SELECT * INTO v_woman_wallet FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF NOT FOUND THEN
      INSERT INTO public.wallets (user_id, gender, balance, currency)
      VALUES (p_woman_id, 'female', 0, 'INR')
      RETURNING * INTO v_woman_wallet;
    END IF;
    v_woman_balance_after := v_woman_wallet.balance + v_woman_credit;
    UPDATE public.wallets SET balance = v_woman_balance_after, updated_at = now()
      WHERE id = v_woman_wallet.id;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type,
      amount, balance_after, description, reference_id, idempotency_key, status
    ) VALUES (
      v_woman_wallet.id, p_woman_id, 'credit',
      p_type || '_earning', p_type,
      v_woman_credit, v_woman_balance_after,
      COALESCE(p_description, initcap(p_type) || ' received — ' || v_pct || '% of ₹' || p_amount),
      v_ref, v_idem_woman, 'completed'
    )
    ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'success',true,'type',p_type,
    'charged',CASE WHEN v_is_super THEN 0 ELSE p_amount END,
    'woman_credit',v_woman_credit,'woman_pct',v_pct,
    'idempotency_key',v_idem_man
  );
END;
$function$;

-- 4) Canonical women withdrawal — wallet_transactions only
CREATE OR REPLACE FUNCTION public.ledger_withdrawal(
  p_user_id uuid,
  p_amount numeric,
  p_payment_method text DEFAULT 'upi',
  p_payment_details jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_wallet RECORD;
  v_pending numeric := 0;
  v_available numeric;
  v_min_withdrawal numeric := 100;
  v_request_id uuid;
  v_fee_pct numeric := 5.00;
  v_fee_amount numeric;
  v_net_payout numeric;
  v_balance_after numeric;
  v_idem text;
  v_idem_fee text;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
  END IF;

  SELECT min_withdrawal_balance, COALESCE(withdrawal_fee_percent, 5.00)
    INTO v_min_withdrawal, v_fee_pct
  FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
  v_min_withdrawal := COALESCE(v_min_withdrawal, 100);
  v_fee_pct := COALESCE(v_fee_pct, 5.00);

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  SELECT COALESCE(SUM(amount),0) INTO v_pending
    FROM public.withdrawal_requests
    WHERE user_id = p_user_id AND status = 'pending';
  v_available := v_wallet.balance - v_pending;

  IF p_amount < v_min_withdrawal THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum withdrawal is ₹' || v_min_withdrawal);
  END IF;
  IF p_amount > v_available THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance. Available: ₹' || v_available);
  END IF;

  v_fee_amount := ROUND(p_amount * v_fee_pct / 100.0, 2);
  v_net_payout := p_amount - v_fee_amount;
  v_balance_after := v_wallet.balance - p_amount;

  UPDATE public.wallets SET balance = v_balance_after, updated_at = now()
   WHERE id = v_wallet.id;

  INSERT INTO public.withdrawal_requests (user_id, amount, payment_method, payment_details, status)
  VALUES (p_user_id, v_net_payout, p_payment_method, p_payment_details, 'pending')
  RETURNING id INTO v_request_id;

  v_idem     := 'withdrawal|' || v_request_id::text;
  v_idem_fee := 'withdrawal_fee|' || v_request_id::text;

  -- Net payout debit
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, session_type,
    amount, balance_after, description, reference_id, idempotency_key, status
  ) VALUES (
    v_wallet.id, p_user_id, 'debit', 'withdrawal', 'wallet',
    v_net_payout, v_balance_after,
    'Withdrawal payout (₹' || p_amount || ' − ' || v_fee_pct || '% fee ₹' || v_fee_amount || ')',
    v_request_id::text, v_idem, 'completed'
  )
  ON CONFLICT (idempotency_key) DO NOTHING;

  -- Fee debit
  IF v_fee_amount > 0 THEN
    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type,
      amount, balance_after, description, reference_id, idempotency_key, status
    ) VALUES (
      v_wallet.id, p_user_id, 'debit', 'withdrawal_fee', 'wallet',
      v_fee_amount, v_balance_after,
      'Withdrawal platform fee (' || v_fee_pct || '% of ₹' || p_amount || ')',
      v_request_id::text, v_idem_fee, 'completed'
    )
    ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  RETURN jsonb_build_object('success', true, 'request_id', v_request_id,
    'requested_amount', p_amount, 'fee_percent', v_fee_pct, 'fee_amount', v_fee_amount,
    'net_payout', v_net_payout, 'available_balance', v_available - p_amount,
    'new_balance', v_balance_after);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;