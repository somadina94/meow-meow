-- Fix process_chat_billing: add optimistic lock to prevent duplicate billing (matches video billing pattern)
CREATE OR REPLACE FUNCTION public.process_chat_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_admin_revenue numeric;
    v_is_super_user boolean;
    v_woman_is_indian boolean := false;
    v_lock_check integer;
BEGIN
    SELECT * INTO v_session
    FROM public.active_chat_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;

    -- Optimistic lock: update last_activity_at only if it hasn't changed (prevents duplicate billing)
    UPDATE public.active_chat_sessions
    SET last_activity_at = now()
    WHERE id = p_session_id
      AND last_activity_at = v_session.last_activity_at;

    GET DIAGNOSTICS v_lock_check = ROW_COUNT;

    IF v_lock_check = 0 THEN
        RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0);
    END IF;

    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);

    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RAISE EXCEPTION 'No active pricing configuration';
    END IF;

    -- Check if the woman is Indian
    SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_woman_is_indian
    FROM public.profiles p
    LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
    WHERE p.user_id = v_session.woman_user_id;

    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    v_earning_amount := CASE WHEN v_woman_is_indian THEN p_minutes * v_pricing.women_earning_rate ELSE 0 END;
    v_admin_revenue := v_charge_amount - v_earning_amount;

    IF v_is_super_user THEN
        UPDATE public.active_chat_sessions
        SET total_minutes = total_minutes + p_minutes
        WHERE id = p_session_id;

        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', 0
        );
    END IF;

    SELECT balance INTO v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;

    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        UPDATE public.active_chat_sessions
        SET status = 'ended',
            ended_at = now(),
            end_reason = 'insufficient_funds'
        WHERE id = p_session_id;

        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'session_ended', true
        );
    END IF;

    -- Always debit man
    PERFORM process_wallet_transaction(
        v_session.man_user_id,
        v_charge_amount,
        'debit',
        'Chat session charge - ' || p_minutes || ' minute(s)'
    );

    -- Only credit Indian women
    IF v_earning_amount > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, chat_session_id, description)
        VALUES (
            v_session.woman_user_id,
            v_earning_amount,
            'chat',
            p_session_id,
            'Chat earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.women_earning_rate || '/min'
        );
    END IF;

    -- Log admin revenue
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, session_id, description, currency
    ) VALUES (
        'chat_revenue', v_admin_revenue, v_session.man_user_id, v_session.woman_user_id,
        p_session_id, 'Chat revenue - ' || p_minutes || ' minute(s)', 'INR'
    );

    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount
    WHERE id = p_session_id;

    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount,
        'admin_revenue', v_admin_revenue,
        'woman_is_indian', v_woman_is_indian
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$function$;

-- Fix get_men_wallet_balance: use wallets.balance as single source of truth, no double-counting
-- wallets.balance is already maintained atomically by process_wallet_transaction
CREATE OR REPLACE FUNCTION public.get_men_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance numeric := 0;
  v_total_recharges numeric := 0;
  v_total_spending numeric := 0;
BEGIN
  -- wallets.balance is the single source of truth (atomically updated by all billing RPCs)
  SELECT COALESCE(balance, 0) INTO v_balance
  FROM wallets
  WHERE user_id = p_user_id;

  -- These are for display/summary only, not for calculating balance
  SELECT COALESCE(SUM(amount), 0) INTO v_total_recharges
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'credit';

  SELECT COALESCE(SUM(amount), 0) INTO v_total_spending
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'debit';

  RETURN jsonb_build_object(
    'balance', v_balance,
    'total_recharges', v_total_recharges,
    'total_spending', v_total_spending
  );
END;
$$;

-- Fix get_women_wallet_balance: ensure no double-counting of withdrawals
-- Approved/completed withdrawals already exist as debits in wallet_transactions
-- Only hold back pending (not yet processed) withdrawals
CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_earnings numeric := 0;
  v_total_debits numeric := 0;
  v_pending_withdrawals numeric := 0;
  v_today_earnings numeric := 0;
  v_available_balance numeric := 0;
  v_today_start timestamptz;
  v_today_end timestamptz;
BEGIN
  v_today_start := date_trunc('day', now());
  v_today_end := v_today_start + interval '1 day' - interval '1 millisecond';

  -- Total earnings from women_earnings (server-side, bypasses row limit)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_earnings
  FROM women_earnings
  WHERE user_id = p_user_id;

  -- Total debits (includes completed withdrawals)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_debits
  FROM wallet_transactions
  WHERE user_id = p_user_id AND type = 'debit';

  -- Only pending withdrawals (approved/completed already recorded as debits)
  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM withdrawal_requests
  WHERE user_id = p_user_id AND status = 'pending';

  -- Today's earnings
  SELECT COALESCE(SUM(amount), 0) INTO v_today_earnings
  FROM women_earnings
  WHERE user_id = p_user_id
    AND created_at >= v_today_start
    AND created_at <= v_today_end;

  v_available_balance := v_total_earnings - v_total_debits - v_pending_withdrawals;

  RETURN jsonb_build_object(
    'total_earnings', v_total_earnings,
    'total_debits', v_total_debits,
    'pending_withdrawals', v_pending_withdrawals,
    'today_earnings', v_today_earnings,
    'available_balance', v_available_balance
  );
END;
$$;