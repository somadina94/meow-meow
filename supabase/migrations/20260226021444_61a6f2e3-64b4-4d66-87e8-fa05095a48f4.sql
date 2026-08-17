CREATE OR REPLACE FUNCTION public.process_group_billing(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
BEGIN
    -- Transaction-level advisory lock to serialize billing per group
    PERFORM pg_advisory_xact_lock(hashtext('process_group_billing:' || p_group_id::text));

    -- Lock group row to ensure it is still live
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

    -- Get active pricing
    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    -- Men pay ₹4/min (rate_per_minute from chat_pricing)
    v_charge_amount := v_pricing.rate_per_minute;

    -- Strong duplicate protection: allow at most one successful billing cycle per ~minute per group
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

    -- Process each non-host member with access
    FOR v_member IN
        SELECT gm.user_id
        FROM public.group_memberships gm
        WHERE gm.group_id = p_group_id
          AND gm.has_access = true
          AND gm.user_id != v_host_id
    LOOP
        -- Lock man's wallet
        SELECT id, balance INTO v_wallet
        FROM public.wallets
        WHERE user_id = v_member.user_id
        FOR UPDATE;

        IF v_wallet.balance IS NULL OR v_wallet.balance < v_charge_amount THEN
            -- Insufficient balance: remove from group
            v_removed_users := array_append(v_removed_users, v_member.user_id);

            UPDATE public.group_memberships
            SET has_access = false
            WHERE group_id = p_group_id AND user_id = v_member.user_id;

            CONTINUE;
        END IF;

        -- Deduct ₹4 from man's wallet
        UPDATE public.wallets
        SET balance = balance - v_charge_amount, updated_at = now()
        WHERE id = v_wallet.id;

        -- Record debit transaction for man
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
        v_total_host_earning := v_total_host_earning + v_pricing.women_earning_rate; -- ₹2 per man
    END LOOP;

    -- Credit host earnings if any men were billed
    IF v_total_host_earning > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (
            v_host_id,
            v_total_host_earning,
            'chat',
            'Group call earnings: ' || v_group.name || ' - ' || v_active_count || ' participant(s) × ₹' || v_pricing.women_earning_rate || '/min'
        );
    END IF;

    -- Update participant count
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
        'removed_users', to_jsonb(v_removed_users),
        'billed_users', to_jsonb(v_billed_users)
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;