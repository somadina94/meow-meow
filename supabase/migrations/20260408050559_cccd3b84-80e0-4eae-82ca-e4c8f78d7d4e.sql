
CREATE OR REPLACE FUNCTION public.process_call_billing(
  p_call_id text,
  p_call_type text DEFAULT 'video'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
  -- Get the session (accept both 'completed' and 'ended')
  SELECT * INTO v_session
  FROM public.video_call_sessions
  WHERE call_id = p_call_id AND status IN ('completed', 'ended');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Session not found or not in completed/ended status');
  END IF;

  -- Idempotency: if already billed, return existing
  IF v_session.total_earned > 0 OR v_session.total_minutes > 0 THEN
    RETURN jsonb_build_object(
      'success', true, 'already_billed', true,
      'total_minutes', v_session.total_minutes,
      'man_charged', v_session.total_minutes * v_session.rate_per_minute,
      'woman_earned', v_session.total_earned
    );
  END IF;

  -- Validate timestamps
  IF v_session.started_at IS NULL OR v_session.ended_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Missing start or end timestamp');
  END IF;

  -- Exact duration
  v_seconds := EXTRACT(EPOCH FROM (v_session.ended_at - v_session.started_at))::integer;
  v_minutes := v_seconds / 60.0;

  IF v_minutes <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid call duration');
  END IF;

  -- Get pricing
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
  -- Half-rule: women earn exactly 50%
  v_woman_earn := ROUND(v_man_charge / 2.0, 2);

  v_idem_key := p_call_type || '_call:' || p_call_id;
  v_idem_key_w := p_call_type || '_call_earn:' || p_call_id;

  -- Idempotency check on wallet_transactions
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
    END IF;

    -- Women earnings record
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, rate_per_minute, minutes_billed)
    VALUES (v_session.woman_user_id, v_woman_earn, p_call_type || '_call',
      initcap(p_call_type) || ' call earning: ' || ROUND(v_minutes, 1) || ' min @ ₹' || ROUND(v_rate/2.0,2) || '/min (½ of ₹' || v_rate || ')',
      ROUND(v_rate / 2.0, 2), v_minutes);
  END IF;

  -- 3. Ledger transactions (backward compat)
  INSERT INTO public.ledger_transactions
    (user_id, transaction_type, debit, description, reference_id, session_id, counterparty_id, duration_seconds, rate_per_minute)
  VALUES
    (v_session.man_user_id, p_call_type || '_call_charge', v_man_charge,
     initcap(p_call_type) || ' call ' || ROUND(v_minutes, 1) || ' min @ ₹' || v_rate || '/min',
     p_call_id, v_session.id, v_session.woman_user_id, v_seconds, v_rate);

  INSERT INTO public.ledger_transactions
    (user_id, transaction_type, credit, description, reference_id, session_id, counterparty_id, duration_seconds, rate_per_minute)
  VALUES
    (v_session.woman_user_id, p_call_type || '_call_earning', v_woman_earn,
     initcap(p_call_type) || ' call earnings ' || ROUND(v_minutes, 1) || ' min @ ₹' || ROUND(v_rate/2.0,2) || '/min',
     p_call_id, v_session.id, v_session.man_user_id, v_seconds, ROUND(v_rate/2.0, 2));

  -- 4. Platform ledger entries
  PERFORM public.safe_ledger_insert(
    v_session.man_user_id, v_session.id, p_call_type || '_call_charge',
    v_man_charge, 0, v_rate, v_seconds, v_session.woman_user_id,
    v_idem_key, initcap(p_call_type) || ' Call: ' || ROUND(v_minutes, 1) || ' min @ ₹' || v_rate || '/min', now()
  );
  PERFORM public.safe_ledger_insert(
    v_session.woman_user_id, v_session.id, p_call_type || '_call_earning',
    0, v_woman_earn, ROUND(v_rate/2.0,2), v_seconds, v_session.man_user_id,
    v_idem_key_w, initcap(p_call_type) || ' Call Earning: ' || ROUND(v_minutes, 1) || ' min (½ of ₹' || v_man_charge || ')', now()
  );

  -- 5. Update session totals
  UPDATE public.video_call_sessions SET
    total_minutes = v_minutes,
    total_earned = v_woman_earn,
    rate_per_minute = v_rate
  WHERE call_id = p_call_id;

  RETURN jsonb_build_object(
    'success', true, 'already_billed', false,
    'total_minutes', v_minutes, 'duration_seconds', v_seconds,
    'man_charged', v_man_charge, 'woman_earned', v_woman_earn,
    'rate_per_minute', v_rate
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
