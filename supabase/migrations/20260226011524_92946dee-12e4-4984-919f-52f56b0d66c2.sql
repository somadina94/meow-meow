CREATE OR REPLACE FUNCTION public.process_video_billing(p_session_id uuid, p_minutes integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_wallet_id uuid;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_is_super_user boolean;
    v_lock_check integer;
BEGIN
    SELECT * INTO v_session
    FROM public.video_call_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session not found');
    END IF;

    UPDATE public.video_call_sessions
    SET updated_at = now()
    WHERE id = p_session_id
      AND updated_at = v_session.updated_at;
    
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
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;
    
    v_charge_amount := p_minutes * v_pricing.video_rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.video_women_earning_rate;
    
    IF v_is_super_user THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
                'Video call (super user session) - ' || p_minutes || ' minute(s)');
        
        UPDATE public.video_call_sessions
        SET total_minutes = total_minutes + p_minutes,
            total_earned = total_earned + v_earning_amount
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', v_earning_amount
        );
    END IF;
    
    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        UPDATE public.video_call_sessions
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
    
    UPDATE public.wallets
    SET balance = balance - v_charge_amount, updated_at = now()
    WHERE id = v_man_wallet_id;
    
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_man_wallet_id, v_session.man_user_id, 'debit', v_charge_amount, 
            'Video call charge - ' || p_minutes || ' minute(s)', 'completed');
    
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
            'Video call earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.video_women_earning_rate || '/min');
    
    UPDATE public.video_call_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;