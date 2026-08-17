-- Update pricing to match spec: Men pay ₹8/min for video, Women earn ₹4/min for video ONLY
-- Women should NOT earn from text chat per spec

-- Update the active chat_pricing record with spec defaults
UPDATE public.chat_pricing
SET 
  video_rate_per_minute = 8,        -- Men pay ₹8/min for video (spec default)
  video_women_earning_rate = 4,     -- Women earn ₹4/min for video (spec default)  
  women_earning_rate = 0,           -- Women earn NOTHING from text chat (spec: video only)
  rate_per_minute = 8,              -- Men pay ₹8/min for chat too (consistent)
  updated_at = now()
WHERE is_active = true;

-- Update process_chat_billing to reflect that women earn NOTHING from chat
-- (keeping man charges, but women_earning_rate = 0 means no earnings)
CREATE OR REPLACE FUNCTION public.process_chat_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_balance numeric;
    v_charge_amount numeric;
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
    
    IF v_is_super_user THEN
        -- Super users don't get charged, women don't earn from chat anyway
        UPDATE public.active_chat_sessions
        SET total_minutes = total_minutes + p_minutes,
            last_activity_at = now()
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', 0,
            'note', 'Women earn from video calls only, not text chat'
        );
    END IF;
    
    -- Calculate charges - MEN ALWAYS PAY
    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    
    -- WOMEN EARN NOTHING FROM TEXT CHAT (per spec - video only)
    -- Admin gets 100% of chat revenue
    v_admin_revenue := v_charge_amount;
    
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
    
    -- Debit man's wallet (MEN ALWAYS PAY)
    PERFORM process_wallet_transaction(
        v_session.man_user_id,
        v_charge_amount,
        'debit',
        'Chat session charge - ' || p_minutes || ' minute(s)'
    );
    
    -- NO EARNINGS FOR WOMEN FROM CHAT (spec says video only)
    
    -- Log admin revenue (100% goes to admin for chat)
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, session_id, description, currency
    ) VALUES (
        'chat_revenue', v_admin_revenue, v_session.man_user_id, v_session.woman_user_id,
        p_session_id, 'Chat revenue - ' || p_minutes || ' minute(s) (women earn video only)', 'INR'
    );
    
    -- Update session totals (no earnings for women in chat)
    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = 0, -- Women don't earn from chat
        last_activity_at = now()
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', 0,
        'admin_revenue', v_admin_revenue,
        'note', 'Women earn from video calls only'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

-- Ensure video billing still pays women (spec: women earn from video calls)
-- process_video_billing already handles this correctly - women get video_women_earning_rate