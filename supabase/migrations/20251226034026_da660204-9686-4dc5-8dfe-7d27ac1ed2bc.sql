-- Update process_gift_transaction to remove redundant admin revenue logging
-- Since all men's recharges already stay with admin, the 50% admin share is implicit
CREATE OR REPLACE FUNCTION public.process_gift_transaction(
    p_sender_id uuid,
    p_receiver_id uuid,
    p_gift_id uuid,
    p_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
    
    -- Calculate 50% share for women (remaining 50% stays with admin implicitly via original recharge)
    v_women_share := v_gift.price * 0.5;
    
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
    
    -- NOTE: No admin_revenue_transactions entry needed for gifts
    -- The 50% admin share is implicit since men's original recharge stays with admin
    
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
        'super_user_bypass', v_is_super_user
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;