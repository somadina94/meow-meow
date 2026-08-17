-- Fix: group call woman earnings must be tagged as 'group_call_earning' in ledger_transactions
-- so they appear in the Statement (single source of truth) and align with men's 'group_call_charge' rows.
-- Also fix description so it shows as "Group Call Earning" in statements.

CREATE OR REPLACE FUNCTION public.process_group_billing(p_group_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
    v_ref_key text;
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

    SELECT * INTO v_pricing
    FROM public.chat_pricing
    WHERE is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    v_charge_amount := v_pricing.group_call_rate_per_minute;

    -- Duplicate billing guard: check last billing within 50 seconds
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

    -- Bill each active male member
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

        -- Debit man's wallet
        UPDATE public.wallets
        SET balance = balance - v_charge_amount, updated_at = now()
        WHERE id = v_wallet.id;

        -- Wallet transaction for man
        INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status, transaction_type, rate_per_minute, duration_seconds, session_id)
        VALUES (
            v_wallet.id,
            v_member.user_id,
            'debit',
            v_charge_amount,
            'Group call: ' || v_group.name || ' (₹' || v_charge_amount || '/min)',
            'completed',
            'group_call_charge',
            v_charge_amount,
            60,
            p_group_id
        );

        -- Platform ledger entry for man debit (single source of truth)
        v_ref_key := p_group_id::text || '_' || v_member.user_id::text || '_grp_' || extract(epoch from now())::bigint::text;
        PERFORM public.safe_ledger_insert(
            v_member.user_id, p_group_id, 'group_call_charge',
            v_charge_amount, 0, v_charge_amount, 60, v_host_id,
            v_ref_key, 'Group Call: ' || v_group.name || ' @ ₹' || v_charge_amount || '/min', now()
        );

        v_active_count := v_active_count + 1;
        v_billed_users := array_append(v_billed_users, v_member.user_id);

        -- Woman earns for EVERY billed man
        v_total_host_earning := v_total_host_earning + v_pricing.group_call_women_earning_rate;

        -- Platform ledger entry for woman earning per man — FIXED: use 'group_call_earning' so Statement displays it
        v_ref_key := p_group_id::text || '_' || v_host_id::text || '_grpearn_' || v_member.user_id::text || '_' || extract(epoch from now())::bigint::text;
        PERFORM public.safe_ledger_insert(
            v_host_id, p_group_id, 'group_call_earning',
            0, v_pricing.group_call_women_earning_rate, v_pricing.group_call_women_earning_rate,
            60, v_member.user_id, v_ref_key,
            'Group Call Earning: ' || v_group.name || ' @ ₹' || v_pricing.group_call_women_earning_rate || '/man', now()
        );
    END LOOP;

    -- Credit host wallet with total earnings
    IF v_total_host_earning > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description, group_id, rate_per_minute, minutes_billed)
        VALUES (
            v_host_id,
            v_total_host_earning,
            'group_call',
            'Group call earnings: ' || v_group.name || ' - ' || v_active_count || ' participants @ ₹' || v_pricing.group_call_women_earning_rate || '/each',
            p_group_id,
            v_pricing.group_call_women_earning_rate,
            1
        );

        UPDATE public.wallets
        SET balance = balance + v_total_host_earning, updated_at = now()
        WHERE user_id = v_host_id;

        -- Wallet transaction for woman earning (aggregated)
        INSERT INTO public.wallet_transactions (
            wallet_id, user_id, type, amount, description, status, transaction_type, rate_per_minute, duration_seconds, session_id
        )
        SELECT w.id, v_host_id, 'credit', v_total_host_earning,
            'Group call earning: ' || v_group.name || ' (' || v_active_count || ' men × ₹' || v_pricing.group_call_women_earning_rate || ')',
            'completed', 'group_call_earning', v_pricing.group_call_women_earning_rate, 60, p_group_id
        FROM public.wallets w WHERE w.user_id = v_host_id;
    END IF;

    -- Update participant count
    UPDATE public.private_groups
    SET participant_count = v_active_count + 1
    WHERE id = p_group_id;

    RETURN jsonb_build_object(
        'success', true,
        'active_count', v_active_count,
        'total_charged', v_active_count * v_charge_amount,
        'host_earned', v_total_host_earning,
        'removed_users', to_jsonb(v_removed_users),
        'billed_users', to_jsonb(v_billed_users),
        'rate_per_minute', v_charge_amount,
        'host_earning_rate', v_pricing.group_call_women_earning_rate
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- Backfill: tag historical group call woman earnings (currently 'earning' from group sessions) to 'group_call_earning'
UPDATE public.ledger_transactions
SET transaction_type = 'group_call_earning'
WHERE transaction_type = 'earning'
  AND description ILIKE 'Group call earning%';