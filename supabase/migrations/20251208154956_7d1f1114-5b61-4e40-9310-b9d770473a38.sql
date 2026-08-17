-- Create app_settings table for dynamic configuration (ACID compliant)
CREATE TABLE IF NOT EXISTS public.app_settings (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    setting_key text NOT NULL UNIQUE,
    setting_value jsonb NOT NULL,
    setting_type text NOT NULL DEFAULT 'string',
    category text NOT NULL DEFAULT 'general',
    description text,
    is_public boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Public settings can be read by anyone
CREATE POLICY "Anyone can view public settings"
ON public.app_settings FOR SELECT
USING (is_public = true);

-- Admins can manage all settings
CREATE POLICY "Admins can manage all settings"
ON public.app_settings FOR ALL
USING (has_role(auth.uid(), 'admin'));

-- Create trigger for updated_at
CREATE TRIGGER update_app_settings_updated_at
BEFORE UPDATE ON public.app_settings
FOR EACH ROW
EXECUTE FUNCTION handle_updated_at();

-- Insert default dynamic settings (recharge amounts, withdrawal amounts, limits, etc.)
INSERT INTO public.app_settings (setting_key, setting_value, setting_type, category, description, is_public) VALUES
('recharge_amounts', '[100, 500, 1000, 2000, 5000, 10000]', 'json', 'wallet', 'Available recharge amounts for men', true),
('withdrawal_amounts', '[500, 1000, 2000, 5000, 10000]', 'json', 'wallet', 'Available withdrawal amounts for women', true),
('min_video_call_balance', '50', 'number', 'video', 'Minimum balance required for video call', true),
('max_parallel_chats', '3', 'number', 'chat', 'Maximum parallel chats allowed', true),
('max_reconnect_attempts', '3', 'number', 'chat', 'Maximum auto-reconnect attempts', true),
('mobile_breakpoint', '768', 'number', 'ui', 'Mobile responsive breakpoint in pixels', true),
('supported_currencies', '["INR", "USD", "EUR"]', 'json', 'wallet', 'Supported currencies', true),
('default_currency', '"INR"', 'json', 'wallet', 'Default currency for new users', true),
('withdrawal_processing_hours', '24', 'number', 'wallet', 'Hours to process withdrawal', true),
('session_timeout_minutes', '30', 'number', 'security', 'Session timeout in minutes', true),
('max_message_length', '2000', 'number', 'chat', 'Maximum message length', true),
('max_file_upload_mb', '10', 'number', 'storage', 'Maximum file upload size in MB', true)
ON CONFLICT (setting_key) DO UPDATE SET 
    setting_value = EXCLUDED.setting_value,
    updated_at = now();

-- Create function for atomic wallet transactions (ACID compliant)
CREATE OR REPLACE FUNCTION public.process_wallet_transaction(
    p_user_id uuid,
    p_amount numeric,
    p_type text,
    p_description text DEFAULT NULL,
    p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_wallet_id uuid;
    v_current_balance numeric;
    v_new_balance numeric;
    v_transaction_id uuid;
BEGIN
    -- Lock the wallet row for update (isolation)
    SELECT id, balance INTO v_wallet_id, v_current_balance
    FROM public.wallets
    WHERE user_id = p_user_id
    FOR UPDATE;
    
    IF v_wallet_id IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user';
    END IF;
    
    -- Calculate new balance
    IF p_type = 'credit' THEN
        v_new_balance := v_current_balance + p_amount;
    ELSIF p_type = 'debit' THEN
        IF v_current_balance < p_amount THEN
            RAISE EXCEPTION 'Insufficient balance';
        END IF;
        v_new_balance := v_current_balance - p_amount;
    ELSE
        RAISE EXCEPTION 'Invalid transaction type';
    END IF;
    
    -- Update wallet balance (atomic)
    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Create transaction record
    INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, amount, description, reference_id, status
    ) VALUES (
        v_wallet_id, p_user_id, p_type, p_amount, p_description, p_reference_id, 'completed'
    )
    RETURNING id INTO v_transaction_id;
    
    -- Return result
    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_transaction_id,
        'previous_balance', v_current_balance,
        'new_balance', v_new_balance
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

-- Create function for atomic chat session billing
CREATE OR REPLACE FUNCTION public.process_chat_billing(
    p_session_id uuid,
    p_minutes numeric
)
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
BEGIN
    -- Get session with lock
    SELECT * INTO v_session
    FROM public.active_chat_sessions
    WHERE id = p_session_id
    FOR UPDATE;
    
    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;
    
    -- Get active pricing
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