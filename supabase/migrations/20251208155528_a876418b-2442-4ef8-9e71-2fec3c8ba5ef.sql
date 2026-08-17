-- Clear all sample/mock data
DELETE FROM public.sample_users;
DELETE FROM public.sample_men;
DELETE FROM public.sample_women;

-- Reset sequences if any (for fresh start)
-- Note: These tables use UUID so no sequence reset needed

-- Create a function to check if a user is a super user (by email pattern)
CREATE OR REPLACE FUNCTION public.is_super_user(user_email text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if email matches super user patterns:
  -- female1-15@meow-meow.com, male1-15@meow-meow.com, admin1-15@meow-meow.com
  RETURN user_email ~ '^(female|male|admin)(1[0-5]?|[1-9])@meow-meow\.com$';
END;
$$;

-- Create a function to check if user should bypass balance requirements
CREATE OR REPLACE FUNCTION public.should_bypass_balance(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  -- Get user email from auth.users
  SELECT email INTO v_email
  FROM auth.users
  WHERE id = p_user_id;
  
  -- Check if super user
  RETURN public.is_super_user(COALESCE(v_email, ''));
END;
$$;

-- Update process_chat_billing to bypass billing for super users
CREATE OR REPLACE FUNCTION public.process_chat_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
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
    
    IF v_is_super_user THEN
        -- Super users don't get charged, but women still earn
        SELECT * INTO v_pricing
        FROM public.chat_pricing
        WHERE is_active = true
        LIMIT 1;
        
        IF v_pricing IS NOT NULL THEN
            v_earning_amount := p_minutes * v_pricing.women_earning_rate;
            
            -- Credit woman's earnings (platform pays)
            INSERT INTO public.women_earnings (user_id, amount, chat_session_id, earning_type, description)
            VALUES (v_session.woman_user_id, v_earning_amount, p_session_id, 'chat', 'Chat earnings (super user session)');
            
            -- Update session totals
            UPDATE public.active_chat_sessions
            SET total_minutes = total_minutes + p_minutes,
                total_earned = total_earned + v_earning_amount,
                last_activity_at = now()
            WHERE id = p_session_id;
        END IF;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', COALESCE(v_earning_amount, 0)
        );
    END IF;
    
    -- Normal billing flow for non-super users
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RAISE EXCEPTION 'No active pricing configuration';
    END IF;
    
    -- Calculate charges
    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.women_earning_rate;
    
    -- Check man's balance
    SELECT balance INTO v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance < v_charge_amount THEN
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
    
    -- Debit man's wallet
    PERFORM process_wallet_transaction(
        v_session.man_user_id,
        v_charge_amount,
        'debit',
        'Chat session charge'
    );
    
    -- Credit woman's earnings
    INSERT INTO public.women_earnings (user_id, amount, chat_session_id, earning_type, description)
    VALUES (v_session.woman_user_id, v_earning_amount, p_session_id, 'chat', 'Chat earnings');
    
    -- Update session totals
    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount,
        last_activity_at = now()
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;