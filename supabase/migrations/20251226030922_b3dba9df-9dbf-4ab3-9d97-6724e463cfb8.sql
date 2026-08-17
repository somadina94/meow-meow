-- Create admin_revenue_transactions table for detailed revenue tracking
CREATE TABLE public.admin_revenue_transactions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    transaction_type text NOT NULL, -- 'recharge', 'chat_revenue', 'video_revenue', 'gift_revenue'
    amount numeric NOT NULL DEFAULT 0,
    man_user_id uuid, -- The man who paid/was charged
    woman_user_id uuid, -- The woman who earned (for chat/video/gift)
    session_id uuid, -- Reference to chat/video session if applicable
    reference_id text, -- External payment reference for recharges
    description text,
    currency text NOT NULL DEFAULT 'INR',
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.admin_revenue_transactions ENABLE ROW LEVEL SECURITY;

-- Admin-only access policies
CREATE POLICY "Admins can view all admin revenue"
ON public.admin_revenue_transactions
FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "System can insert admin revenue"
ON public.admin_revenue_transactions
FOR INSERT
WITH CHECK (true);

-- Create index for efficient queries
CREATE INDEX idx_admin_revenue_type ON public.admin_revenue_transactions(transaction_type);
CREATE INDEX idx_admin_revenue_created ON public.admin_revenue_transactions(created_at);
CREATE INDEX idx_admin_revenue_man ON public.admin_revenue_transactions(man_user_id);

-- Create process_recharge function
-- When man recharges: 100% goes to admin revenue, man gets spending balance
CREATE OR REPLACE FUNCTION public.process_recharge(
    p_user_id uuid,
    p_amount numeric,
    p_reference_id text DEFAULT NULL,
    p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_wallet_id uuid;
    v_current_balance numeric;
    v_new_balance numeric;
    v_transaction_id uuid;
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
    END IF;
    
    -- Lock the wallet row for update
    SELECT id, balance INTO v_wallet_id, v_current_balance
    FROM public.wallets
    WHERE user_id = p_user_id
    FOR UPDATE;
    
    -- Create wallet if not exists
    IF v_wallet_id IS NULL THEN
        INSERT INTO public.wallets (user_id, balance, currency)
        VALUES (p_user_id, 0, 'INR')
        RETURNING id, balance INTO v_wallet_id, v_current_balance;
    END IF;
    
    -- Calculate new balance (man gets spending power)
    v_new_balance := v_current_balance + p_amount;
    
    -- Update wallet balance
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create wallet transaction record for man
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, reference_id, status
    ) VALUES (
        v_wallet_id, p_user_id, 'credit', p_amount,
        COALESCE(p_description, 'Wallet Recharge'), p_reference_id, 'completed'
    ) RETURNING id INTO v_transaction_id;
    
    -- Log admin revenue (100% of recharge goes to admin)
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, reference_id, description, currency
    ) VALUES (
        'recharge', p_amount, p_user_id, p_reference_id,
        'Recharge by user', 'INR'
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_transaction_id,
        'previous_balance', v_current_balance,
        'new_balance', v_new_balance,
        'admin_revenue', p_amount
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Update process_chat_billing to track admin revenue
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
    
    IF v_is_super_user THEN
        -- Super users don't get charged, but women still earn
        SELECT * INTO v_pricing
        FROM public.chat_pricing
        WHERE is_active = true
        ORDER BY updated_at DESC
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
    
    -- Get latest active pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RAISE EXCEPTION 'No active pricing configuration';
    END IF;
    
    -- Calculate charges using admin-defined rates
    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.women_earning_rate;
    v_admin_revenue := v_charge_amount - v_earning_amount;
    
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
    
    -- Debit man's wallet (his spending balance)
    PERFORM process_wallet_transaction(
        v_session.man_user_id,
        v_charge_amount,
        'debit',
        'Chat session charge - ' || p_minutes || ' minute(s)'
    );
    
    -- Credit woman's earnings
    INSERT INTO public.women_earnings (user_id, amount, chat_session_id, earning_type, description)
    VALUES (v_session.woman_user_id, v_earning_amount, p_session_id, 'chat', 
            'Chat earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.women_earning_rate || '/min');
    
    -- Log admin revenue (charge - woman earning)
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
$$;

-- Update process_video_billing to track admin revenue
CREATE OR REPLACE FUNCTION public.process_video_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_session RECORD;
    v_pricing RECORD;
    v_man_wallet_id uuid;
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
    v_admin_revenue numeric;
    v_is_super_user boolean;
BEGIN
    -- Get session with lock
    SELECT * INTO v_session
    FROM public.video_call_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session not found');
    END IF;
    
    -- Check if man is super user
    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);
    
    -- Get latest active pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;
    
    -- Calculate amounts using admin-defined video rates
    v_charge_amount := p_minutes * v_pricing.video_rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.video_women_earning_rate;
    v_admin_revenue := v_charge_amount - v_earning_amount;
    
    IF v_is_super_user THEN
        -- Super users: credit woman only, no debit
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
                'Video call (super user session) - ' || p_minutes || ' minute(s)');
        
        UPDATE public.video_call_sessions
        SET total_minutes = total_minutes + p_minutes,
            total_earned = total_earned + v_earning_amount,
            updated_at = now()
        WHERE id = p_session_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'super_user', true,
            'charged', 0,
            'earned', v_earning_amount
        );
    END IF;
    
    -- Normal flow: lock wallet
    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets
    WHERE user_id = v_session.man_user_id
    FOR UPDATE;
    
    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        -- End session due to insufficient funds
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
    
    -- Debit man's wallet
    UPDATE public.wallets
    SET balance = balance - v_charge_amount, updated_at = now()
    WHERE id = v_man_wallet_id;
    
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_man_wallet_id, v_session.man_user_id, 'debit', v_charge_amount, 
            'Video call charge - ' || p_minutes || ' minute(s)', 'completed');
    
    -- Credit woman
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
            'Video call earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.video_women_earning_rate || '/min');
    
    -- Log admin revenue
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, session_id, description, currency
    ) VALUES (
        'video_revenue', v_admin_revenue, v_session.man_user_id, v_session.woman_user_id,
        p_session_id, 'Video call revenue - ' || p_minutes || ' minute(s)', 'INR'
    );
    
    -- Update session
    UPDATE public.video_call_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount,
        updated_at = now()
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount,
        'admin_revenue', v_admin_revenue
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Update process_gift_transaction to track admin revenue
CREATE OR REPLACE FUNCTION public.process_gift_transaction(p_sender_id uuid, p_receiver_id uuid, p_gift_id uuid, p_message text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_gift RECORD;
    v_wallet_id uuid;
    v_balance numeric;
    v_new_balance numeric;
    v_transaction_id uuid;
    v_gift_transaction_id uuid;
    v_is_super_user boolean;
    v_women_share numeric;
    v_admin_share numeric;
BEGIN
    -- Get gift details with lock
    SELECT * INTO v_gift
    FROM public.gifts
    WHERE id = p_gift_id AND is_active = true
    FOR SHARE;
    
    IF v_gift IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift not found or inactive');
    END IF;
    
    -- Check if sender is super user
    v_is_super_user := public.should_bypass_balance(p_sender_id);
    
    -- Lock sender's wallet
    SELECT id, balance INTO v_wallet_id, v_balance
    FROM public.wallets
    WHERE user_id = p_sender_id
    FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;
    
    -- Check balance (skip for super users)
    IF NOT v_is_super_user AND v_balance < v_gift.price THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
    
    -- Calculate 50/50 split for gifts
    v_women_share := v_gift.price * 0.5;
    v_admin_share := v_gift.price * 0.5;
    
    -- Calculate new balance
    IF v_is_super_user THEN
        v_new_balance := v_balance; -- Super users don't lose balance
    ELSE
        v_new_balance := v_balance - v_gift.price;
    END IF;
    
    -- Debit wallet (atomic)
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create wallet transaction record for sender
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, status
    ) VALUES (
        v_wallet_id, p_sender_id, 'debit', v_gift.price,
        'Gift: ' || v_gift.name || ' (sent)', 'completed'
    ) RETURNING id INTO v_transaction_id;
    
    -- Credit woman's earnings (50% of gift value)
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (p_receiver_id, v_women_share, 'gift', 'Gift received: ' || v_gift.name || ' (50% share)');
    
    -- Log admin revenue (50% of gift value)
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, reference_id, description, currency
    ) VALUES (
        'gift_revenue', v_admin_share, p_sender_id, p_receiver_id,
        p_gift_id::text, 'Gift revenue: ' || v_gift.name || ' (50% share)', 'INR'
    );
    
    -- Create gift transaction record
    INSERT INTO public.gift_transactions (
        sender_id, receiver_id, gift_id, price_paid, currency, message, status
    ) VALUES (
        p_sender_id, p_receiver_id, p_gift_id, v_gift.price, v_gift.currency, p_message, 'completed'
    ) RETURNING id INTO v_gift_transaction_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'gift_transaction_id', v_gift_transaction_id,
        'wallet_transaction_id', v_transaction_id,
        'previous_balance', v_balance,
        'new_balance', v_new_balance,
        'gift_name', v_gift.name,
        'gift_emoji', v_gift.emoji,
        'gift_price', v_gift.price,
        'women_share', v_women_share,
        'admin_share', v_admin_share,
        'super_user_bypass', v_is_super_user
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;