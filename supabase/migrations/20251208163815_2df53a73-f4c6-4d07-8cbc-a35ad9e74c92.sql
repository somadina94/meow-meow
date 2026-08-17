-- ACID-Compliant Atomic Transfer Function
-- Ensures atomicity: both debit and credit happen or neither does
-- Uses row-level locking for isolation
CREATE OR REPLACE FUNCTION public.process_atomic_transfer(
  p_from_user_id uuid,
  p_to_user_id uuid,
  p_amount numeric,
  p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_from_wallet_id uuid;
    v_to_wallet_id uuid;
    v_from_balance numeric;
    v_to_balance numeric;
    v_from_new_balance numeric;
    v_to_new_balance numeric;
    v_from_transaction_id uuid;
    v_to_transaction_id uuid;
    v_is_super_user boolean;
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
    END IF;
    
    -- Check if sender is super user
    v_is_super_user := public.should_bypass_balance(p_from_user_id);
    
    -- Lock both wallets in consistent order (by user_id) to prevent deadlocks
    IF p_from_user_id < p_to_user_id THEN
        SELECT id, balance INTO v_from_wallet_id, v_from_balance
        FROM public.wallets WHERE user_id = p_from_user_id FOR UPDATE;
        
        SELECT id, balance INTO v_to_wallet_id, v_to_balance
        FROM public.wallets WHERE user_id = p_to_user_id FOR UPDATE;
    ELSE
        SELECT id, balance INTO v_to_wallet_id, v_to_balance
        FROM public.wallets WHERE user_id = p_to_user_id FOR UPDATE;
        
        SELECT id, balance INTO v_from_wallet_id, v_from_balance
        FROM public.wallets WHERE user_id = p_from_user_id FOR UPDATE;
    END IF;
    
    -- Validate wallets exist
    IF v_from_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Sender wallet not found');
    END IF;
    
    IF v_to_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Receiver wallet not found');
    END IF;
    
    -- Check balance (skip for super users)
    IF NOT v_is_super_user AND v_from_balance < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
    
    -- Calculate new balances
    IF v_is_super_user THEN
        v_from_new_balance := v_from_balance; -- Super users don't lose balance
    ELSE
        v_from_new_balance := v_from_balance - p_amount;
    END IF;
    v_to_new_balance := v_to_balance + p_amount;
    
    -- Update sender wallet (atomic)
    UPDATE public.wallets
    SET balance = v_from_new_balance, updated_at = now()
    WHERE id = v_from_wallet_id;
    
    -- Update receiver wallet (atomic)
    UPDATE public.wallets
    SET balance = v_to_new_balance, updated_at = now()
    WHERE id = v_to_wallet_id;
    
    -- Create debit transaction record
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, status
    ) VALUES (
        v_from_wallet_id, p_from_user_id, 'debit', p_amount,
        COALESCE(p_description, 'Transfer out'), 'completed'
    ) RETURNING id INTO v_from_transaction_id;
    
    -- Create credit transaction record
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, status
    ) VALUES (
        v_to_wallet_id, p_to_user_id, 'credit', p_amount,
        COALESCE(p_description, 'Transfer in'), 'completed'
    ) RETURNING id INTO v_to_transaction_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'from_transaction_id', v_from_transaction_id,
        'to_transaction_id', v_to_transaction_id,
        'from_previous_balance', v_from_balance,
        'from_new_balance', v_from_new_balance,
        'to_previous_balance', v_to_balance,
        'to_new_balance', v_to_new_balance,
        'super_user_bypass', v_is_super_user
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ACID-Compliant Gift Transaction Function
-- Atomically handles gift purchase: debit sender, record gift
CREATE OR REPLACE FUNCTION public.process_gift_transaction(
  p_sender_id uuid,
  p_receiver_id uuid,
  p_gift_id uuid,
  p_message text DEFAULT NULL
)
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
    
    -- Create wallet transaction record
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, status
    ) VALUES (
        v_wallet_id, p_sender_id, 'debit', v_gift.price,
        'Gift: ' || v_gift.name, 'completed'
    ) RETURNING id INTO v_transaction_id;
    
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
        'super_user_bypass', v_is_super_user
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ACID-Compliant Video Call Billing Function
CREATE OR REPLACE FUNCTION public.process_video_billing(
  p_session_id uuid,
  p_minutes numeric
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
    v_man_balance numeric;
    v_charge_amount numeric;
    v_earning_amount numeric;
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
    
    -- Get pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    LIMIT 1;
    
    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;
    
    -- Calculate amounts
    v_charge_amount := p_minutes * v_pricing.video_rate_per_minute;
    v_earning_amount := p_minutes * v_pricing.video_women_earning_rate;
    
    IF v_is_super_user THEN
        -- Super users: credit woman only, no debit
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 'Video call (super user session)');
        
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
    
    IF v_man_balance < v_charge_amount THEN
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
    VALUES (v_man_wallet_id, v_session.man_user_id, 'debit', v_charge_amount, 'Video call charge', 'completed');
    
    -- Credit woman
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
    VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 'Video call earnings');
    
    -- Update session
    UPDATE public.video_call_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount,
        updated_at = now()
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

-- ACID-Compliant Withdrawal Request Function
CREATE OR REPLACE FUNCTION public.process_withdrawal_request(
  p_user_id uuid,
  p_amount numeric,
  p_payment_method text DEFAULT NULL,
  p_payment_details jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_wallet_id uuid;
    v_balance numeric;
    v_min_balance numeric;
    v_new_balance numeric;
    v_withdrawal_id uuid;
    v_transaction_id uuid;
BEGIN
    -- Get minimum withdrawal balance
    SELECT (setting_value::text)::numeric INTO v_min_balance
    FROM public.app_settings
    WHERE setting_key = 'min_withdrawal_balance';
    
    v_min_balance := COALESCE(v_min_balance, 10000);
    
    IF p_amount < v_min_balance THEN
        RETURN jsonb_build_object('success', false, 'error', 'Amount below minimum withdrawal');
    END IF;
    
    -- Lock wallet
    SELECT id, balance INTO v_wallet_id, v_balance
    FROM public.wallets
    WHERE user_id = p_user_id
    FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;
    
    IF v_balance < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;
    
    v_new_balance := v_balance - p_amount;
    
    -- Hold funds (debit wallet)
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create transaction record
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_wallet_id, p_user_id, 'debit', p_amount, 'Withdrawal request', 'pending')
    RETURNING id INTO v_transaction_id;
    
    -- Create withdrawal request
    INSERT INTO public.withdrawal_requests (
        user_id, amount, payment_method, payment_details, status
    ) VALUES (
        p_user_id, p_amount, p_payment_method, p_payment_details, 'pending'
    ) RETURNING id INTO v_withdrawal_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'withdrawal_id', v_withdrawal_id,
        'transaction_id', v_transaction_id,
        'previous_balance', v_balance,
        'new_balance', v_new_balance
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;