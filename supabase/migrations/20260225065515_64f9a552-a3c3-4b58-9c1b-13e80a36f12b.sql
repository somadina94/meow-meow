-- Fix women chat earnings not appearing in statement/history
-- Men are charged chat rate; women are credited women_earning_rate; admin receives remainder

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
BEGIN
    -- Get session with lock
    SELECT * INTO v_session
    FROM public.active_chat_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;

    -- Check if man is a super user (bypass billing)
    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);

    -- Get latest active pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RAISE EXCEPTION 'No active pricing configuration';
    END IF;

    -- Pricing split for chat
    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.women_earning_rate;
    v_admin_revenue := v_charge_amount - v_earning_amount;

    IF v_is_super_user THEN
        -- Super users don't get charged; no payout booked for bypass sessions
        UPDATE public.active_chat_sessions
        SET total_minutes = total_minutes + p_minutes,
            last_activity_at = now()
        WHERE id = p_session_id;

        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', 0
        );
    END IF;

    -- Check man's balance
    SELECT balance INTO v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;

    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        -- End session due to insufficient funds
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

    -- Debit man's wallet (₹4/min default)
    PERFORM process_wallet_transaction(
        v_session.man_user_id,
        v_charge_amount,
        'debit',
        'Chat session charge - ' || p_minutes || ' minute(s)'
    );

    -- Credit woman earnings (₹2/min default)
    INSERT INTO public.women_earnings (user_id, amount, earning_type, chat_session_id, description)
    VALUES (
        v_session.woman_user_id,
        v_earning_amount,
        'chat',
        p_session_id,
        'Chat earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.women_earning_rate || '/min'
    );

    -- Log admin revenue
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, session_id, description, currency
    ) VALUES (
        'chat_revenue', v_admin_revenue, v_session.man_user_id, v_session.woman_user_id,
        p_session_id, 'Chat revenue - ' || p_minutes || ' minute(s)', 'INR'
    );

    -- Update session totals
    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount,
        last_activity_at = now()
    WHERE id = p_session_id;

    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount,
        'admin_revenue', v_admin_revenue
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$function$;