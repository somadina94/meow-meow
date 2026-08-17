CREATE OR REPLACE FUNCTION public.process_chat_billing(
  p_session_id uuid,
  p_minutes numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session RECORD;
  v_pricing RECORD;
  v_man_wallet_id uuid;
  v_man_balance numeric := 0;
  v_woman_wallet_id uuid;
  v_woman_balance numeric := 0;
  v_man_rate numeric := 0;
  v_woman_rate numeric := 0;
  v_elapsed_seconds numeric := 0;
  v_billable_seconds numeric := 0;
  v_display_seconds integer := 0;
  v_billable_minutes numeric := 0;
  v_charge numeric := 0;
  v_earn numeric := 0;
  v_is_super boolean := false;
  v_idem_key text;
  v_idem_key_w text;
  v_woman_indian boolean := false;
  v_claimed_at timestamptz;
  v_billed_at timestamptz;
  v_should_end boolean := false;
  v_metadata jsonb;
BEGIN
  SELECT * INTO v_session
  FROM public.active_chat_sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Session not found');
  END IF;

  IF v_session.status <> 'active' THEN
    RETURN jsonb_build_object('success', true, 'billing_paused', true, 'charged', 0, 'earned', 0, 'status', v_session.status);
  END IF;

  v_claimed_at := v_session.last_activity_at;
  v_billed_at := clock_timestamp();
  v_elapsed_seconds := GREATEST(0, EXTRACT(EPOCH FROM (v_billed_at - v_claimed_at)));
  v_billable_seconds := v_elapsed_seconds;
  v_idem_key := 'chat:' || p_session_id::text || ':' || EXTRACT(EPOCH FROM v_claimed_at)::text;
  v_idem_key_w := v_idem_key || ':earn';

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0, 'idempotency_key', v_idem_key);
  END IF;

  IF v_billable_seconds < 0.001 THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'too_soon', true, 'charged', 0, 'earned', 0, 'elapsed_seconds', ROUND(v_elapsed_seconds, 6), 'idempotency_key', v_idem_key);
  END IF;

  SELECT * INTO v_pricing
  FROM public.chat_pricing
  WHERE is_active = true
  ORDER BY updated_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
  END IF;

  v_man_rate := COALESCE(v_pricing.rate_per_minute, 4.00);
  v_woman_rate := COALESCE(v_pricing.women_earning_rate, ROUND(v_man_rate / 2.0, 2));
  v_billable_minutes := v_billable_seconds / 60.0;
  v_charge := ROUND(v_billable_minutes * v_man_rate, 2);
  v_earn := ROUND(v_billable_minutes * v_woman_rate, 2);
  v_is_super := public.should_bypass_balance(v_session.man_user_id);

  SELECT COALESCE(
    (SELECT fp.is_indian FROM public.female_profiles fp WHERE fp.user_id = v_session.woman_user_id LIMIT 1),
    (SELECT pr.is_indian FROM public.profiles pr WHERE pr.user_id = v_session.woman_user_id LIMIT 1),
    false
  ) INTO v_woman_indian;

  IF NOT v_is_super THEN
    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;

    IF v_man_wallet_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Man wallet not found');
    END IF;

    IF v_man_balance <= 0 THEN
      UPDATE public.active_chat_sessions
      SET status = 'ended', ended_at = v_billed_at, end_reason = 'insufficient_funds', updated_at = v_billed_at
      WHERE id = p_session_id;
      RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'session_ended', true, 'charged', 0, 'earned', 0);
    END IF;

    IF v_charge > v_man_balance THEN
      v_charge := ROUND(v_man_balance, 2);
      v_billable_minutes := v_charge / NULLIF(v_man_rate, 0);
      v_billable_seconds := v_billable_minutes * 60.0;
      v_earn := ROUND(v_billable_minutes * v_woman_rate, 2);
      v_should_end := true;
    END IF;
  END IF;

  IF v_billable_seconds < 0.001 OR (NOT v_is_super AND v_charge <= 0) THEN
    UPDATE public.active_chat_sessions
    SET status = 'ended', ended_at = v_billed_at, end_reason = 'insufficient_funds', updated_at = v_billed_at
    WHERE id = p_session_id;
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'session_ended', true, 'charged', 0, 'earned', 0);
  END IF;

  v_display_seconds := GREATEST(1, ROUND(v_billable_seconds)::integer);

  v_metadata := jsonb_build_object(
    'service', 'chat',
    'session_id', p_session_id,
    'chat_id', v_session.chat_id,
    'man_user_id', v_session.man_user_id,
    'woman_user_id', v_session.woman_user_id,
    'claimed_at', v_claimed_at,
    'billed_at', v_billed_at,
    'elapsed_seconds_exact', ROUND(v_elapsed_seconds, 6),
    'billed_seconds_exact', ROUND(v_billable_seconds, 6),
    'display_seconds', v_display_seconds,
    'billed_minutes_exact', ROUND(v_billable_minutes, 8),
    'man_rate_per_minute', v_man_rate,
    'woman_rate_per_minute', v_woman_rate,
    'man_amount', CASE WHEN v_is_super THEN 0 ELSE v_charge END,
    'woman_amount', CASE WHEN v_woman_indian THEN v_earn ELSE 0 END,
    'woman_is_indian', v_woman_indian,
    'super_user', v_is_super,
    'pricing_id', v_pricing.id,
    'currency', COALESCE(v_pricing.currency, 'INR'),
    'idempotency_key', v_idem_key,
    'partial_balance_settlement', v_should_end
  );

  IF NOT v_is_super THEN
    UPDATE public.wallets
    SET balance = balance - v_charge, updated_at = v_billed_at
    WHERE id = v_man_wallet_id
    RETURNING balance INTO v_man_balance;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, amount, description, reference_id, session_id,
      session_type, balance_after, idempotency_key, status, duration_seconds, rate_per_minute, billing_metadata
    ) VALUES (
      v_man_wallet_id, v_session.man_user_id, 'debit', 'chat_charge', v_charge,
      'Chat billing: ' || ROUND(v_billable_seconds, 3) || ' sec @ ₹' || to_char(v_man_rate, 'FM999999990.00') || '/min; woman rate ₹' || to_char(v_woman_rate, 'FM999999990.00') || '/min',
      v_idem_key, p_session_id, 'chat', v_man_balance, v_idem_key, 'completed', v_display_seconds, v_man_rate, v_metadata
    );
  END IF;

  IF v_earn > 0 AND v_woman_indian THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets
    WHERE user_id = v_session.woman_user_id
    FOR UPDATE;

    IF v_woman_wallet_id IS NOT NULL THEN
      UPDATE public.wallets
      SET balance = balance + v_earn, updated_at = v_billed_at
      WHERE id = v_woman_wallet_id
      RETURNING balance INTO v_woman_balance;

      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, reference_id, session_id,
        session_type, balance_after, idempotency_key, status, duration_seconds, rate_per_minute, billing_metadata
      ) VALUES (
        v_woman_wallet_id, v_session.woman_user_id, 'credit', 'chat_earning', v_earn,
        'Chat earning: ' || ROUND(v_billable_seconds, 3) || ' sec @ ₹' || to_char(v_woman_rate, 'FM999999990.00') || '/min; man rate ₹' || to_char(v_man_rate, 'FM999999990.00') || '/min',
        v_idem_key_w, p_session_id, 'chat', v_woman_balance, v_idem_key_w, 'completed', v_display_seconds, v_woman_rate, v_metadata || jsonb_build_object('idempotency_key', v_idem_key_w)
      );
    END IF;
  END IF;

  UPDATE public.active_chat_sessions
  SET last_activity_at = v_billed_at,
      total_minutes = total_minutes + v_billable_minutes,
      total_earned = total_earned + (CASE WHEN v_woman_indian THEN v_earn ELSE 0 END),
      status = CASE WHEN v_should_end THEN 'ended' ELSE status END,
      ended_at = CASE WHEN v_should_end THEN v_billed_at ELSE ended_at END,
      end_reason = CASE WHEN v_should_end THEN 'insufficient_funds' ELSE end_reason END,
      updated_at = v_billed_at
  WHERE id = p_session_id;

  RETURN jsonb_build_object(
    'success', true,
    'super_user', v_is_super,
    'charged', CASE WHEN v_is_super THEN 0 ELSE v_charge END,
    'earned', CASE WHEN v_woman_indian THEN v_earn ELSE 0 END,
    'duration_seconds', v_display_seconds,
    'elapsed_seconds_exact', ROUND(v_elapsed_seconds, 6),
    'billed_seconds_exact', ROUND(v_billable_seconds, 6),
    'billable_minutes', ROUND(v_billable_minutes, 8),
    'man_rate_per_minute', v_man_rate,
    'woman_rate_per_minute', v_woman_rate,
    'woman_is_indian', v_woman_indian,
    'idempotency_key', v_idem_key,
    'session_ended', v_should_end
  );
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0, 'idempotency_key', v_idem_key);
WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.process_chat_billing(uuid, numeric) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.process_chat_billing(uuid, numeric) FROM anon;
GRANT EXECUTE ON FUNCTION public.process_chat_billing(uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_chat_billing(uuid, numeric) TO service_role;