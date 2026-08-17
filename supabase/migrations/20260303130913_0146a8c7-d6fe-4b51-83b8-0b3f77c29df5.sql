
-- Update all billing functions to only credit earnings to Indian women
-- Men are ALWAYS charged regardless of woman's nationality

-- 1. process_chat_billing: check if woman is Indian before crediting earnings
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
BEGIN
    SELECT * INTO v_session
    FROM public.active_chat_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Session not found';
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
    -- Only Indian women earn
    v_earning_amount := CASE WHEN v_woman_is_indian THEN p_minutes * v_pricing.women_earning_rate ELSE 0 END;
    v_admin_revenue := v_charge_amount - v_earning_amount;

    IF v_is_super_user THEN
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

    -- Log admin revenue (full charge goes to admin if non-Indian woman)
    INSERT INTO public.admin_revenue_transactions (
        transaction_type, amount, man_user_id, woman_user_id, session_id, description, currency
    ) VALUES (
        'chat_revenue', v_admin_revenue, v_session.man_user_id, v_session.woman_user_id,
        p_session_id, 'Chat revenue - ' || p_minutes || ' minute(s)', 'INR'
    );

    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount,
        last_activity_at = now()
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

-- 2. process_video_billing: check if woman is Indian before crediting earnings
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
    v_woman_is_indian boolean := false;
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

    -- Check if the woman is Indian
    SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_woman_is_indian
    FROM public.profiles p
    LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
    WHERE p.user_id = v_session.woman_user_id;
    
    v_charge_amount := p_minutes * v_pricing.video_rate_per_minute;
    -- Only Indian women earn
    v_earning_amount := CASE WHEN v_woman_is_indian THEN p_minutes * v_pricing.video_women_earning_rate ELSE 0 END;
    
    IF v_is_super_user THEN
        IF v_earning_amount > 0 THEN
            INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
            VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
                    'Video call (super user session) - ' || p_minutes || ' minute(s)');
        END IF;
        
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
    
    -- Always debit man
    UPDATE public.wallets
    SET balance = balance - v_charge_amount, updated_at = now()
    WHERE id = v_man_wallet_id;
    
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
    VALUES (v_man_wallet_id, v_session.man_user_id, 'debit', v_charge_amount, 
            'Video call charge - ' || p_minutes || ' minute(s)', 'completed');
    
    -- Only credit Indian women
    IF v_earning_amount > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_session.woman_user_id, v_earning_amount, 'video_call', 
                'Video call earnings - ' || p_minutes || ' minute(s) @ ₹' || v_pricing.video_women_earning_rate || '/min');
    END IF;
    
    UPDATE public.video_call_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned = total_earned + v_earning_amount
    WHERE id = p_session_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'charged', v_charge_amount,
        'earned', v_earning_amount,
        'woman_is_indian', v_woman_is_indian
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 3. process_group_billing: check if host is Indian before crediting earnings
CREATE OR REPLACE FUNCTION public.process_group_billing(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_group RECORD;
    v_pricing RECORD;
    v_host_id uuid;
    v_member RECORD;
    v_wallet RECORD;
    v_charge_amount numeric;
    v_total_host_earning numeric := 0;
    v_active_count integer := 0;
    v_removed_users uuid[] := '{}';
    v_billed_users uuid[] := '{}';
    v_last_billing_at timestamptz;
    v_host_is_indian boolean := false;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('process_group_billing:' || p_group_id::text));

    SELECT * INTO v_group
    FROM public.private_groups
    WHERE id = p_group_id AND is_live = true AND is_active = true
    FOR UPDATE;

    IF v_group IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Group not live or not found');
    END IF;

    v_host_id := v_group.current_host_id;
    IF v_host_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active host');
    END IF;

    -- Check if host is Indian
    SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_host_is_indian
    FROM public.profiles p
    LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
    WHERE p.user_id = v_host_id;

    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    v_charge_amount := v_pricing.rate_per_minute;

    SELECT GREATEST(
      COALESCE((
        SELECT MAX(created_at)
        FROM public.wallet_transactions wt
        WHERE wt.type = 'debit'
          AND wt.description = ('Group call: ' || v_group.name || ' (₹' || v_charge_amount || '/min)')
      ), 'epoch'::timestamptz),
      COALESCE((
        SELECT MAX(created_at)
        FROM public.women_earnings we
        WHERE we.user_id = v_host_id
          AND we.description LIKE ('Group call earnings: ' || v_group.name || ' - %')
      ), 'epoch'::timestamptz)
    ) INTO v_last_billing_at;

    IF v_last_billing_at > (now() - interval '50 seconds') THEN
        RETURN jsonb_build_object(
            'success', true,
            'duplicate_skipped', true,
            'last_billed_at', v_last_billing_at
        );
    END IF;

    FOR v_member IN
        SELECT gm.user_id
        FROM public.group_memberships gm
        WHERE gm.group_id = p_group_id
          AND gm.has_access = true
          AND gm.user_id != v_host_id
    LOOP
        SELECT id, balance INTO v_wallet
        FROM public.wallets
        WHERE user_id = v_member.user_id
        FOR UPDATE;

        IF v_wallet.balance IS NULL OR v_wallet.balance < v_charge_amount THEN
            v_removed_users := array_append(v_removed_users, v_member.user_id);

            UPDATE public.group_memberships
            SET has_access = false
            WHERE group_id = p_group_id AND user_id = v_member.user_id;

            CONTINUE;
        END IF;

        -- Always charge the man
        UPDATE public.wallets
        SET balance = balance - v_charge_amount, updated_at = now()
        WHERE id = v_wallet.id;

        INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
        VALUES (
            v_wallet.id,
            v_member.user_id,
            'debit',
            v_charge_amount,
            'Group call: ' || v_group.name || ' (₹' || v_charge_amount || '/min)',
            'completed'
        );

        v_active_count := v_active_count + 1;
        v_billed_users := array_append(v_billed_users, v_member.user_id);
        
        -- Only accumulate host earnings if host is Indian
        IF v_host_is_indian THEN
            v_total_host_earning := v_total_host_earning + v_pricing.women_earning_rate;
        END IF;
    END LOOP;

    -- Only credit Indian host
    IF v_total_host_earning > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (
            v_host_id,
            v_total_host_earning,
            'chat',
            'Group call earnings: ' || v_group.name || ' - ' || v_active_count || ' participant(s) × ₹' || v_pricing.women_earning_rate || '/min'
        );
    END IF;

    UPDATE public.private_groups
    SET participant_count = (
        SELECT count(*)
        FROM public.group_memberships
        WHERE group_id = p_group_id AND has_access = true
    )
    WHERE id = p_group_id;

    RETURN jsonb_build_object(
        'success', true,
        'active_count', v_active_count,
        'total_charged', v_active_count * v_charge_amount,
        'host_earned', v_total_host_earning,
        'host_is_indian', v_host_is_indian,
        'removed_users', to_jsonb(v_removed_users),
        'billed_users', to_jsonb(v_billed_users)
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;
