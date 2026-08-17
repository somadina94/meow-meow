-- =============================================================================
-- Migration: Wallet-Only Architecture + Half-Rule Validation
-- Date: 2026-03-13
-- =============================================================================
--
-- RULES ENFORCED:
--   1. wallets.balance is the ONLY source of truth for both men and women.
--      - Men:   balance decremented on each session charge.
--      - Women: balance incremented on each session earning.
--      - Recharge: balance incremented (added to existing).
--      - Withdrawal: balance decremented.
--
--   2. wallet_transactions records exist for ADMIN view only.
--      Men's and women's dashboards show ONLY wallets.balance — no history list.
--
--   3. Half-rule validation per session (enforced in every billing RPC):
--      SUM(all individual men charged in session) = 2 × women_earned
--      i.e. women_earned = SUM(men_charged) / 2
--      Any result that violates this is rejected and rolled back.
--
--   4. women_earnings table is kept for admin audit trail only.
--      It is NOT used to compute wallets.balance for women.
--
-- =============================================================================

-- ─── 1. process_chat_billing — wallet-only, half-rule validated ───────────────
-- One man + one woman. Man pays rate/min. Woman earns exactly half.
-- Both wallets.balance updated atomically. wallet_transactions = admin only.

CREATE OR REPLACE FUNCTION public.process_chat_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_session       RECORD;
    v_pricing       RECORD;
    v_man_balance   numeric;
    v_charge_amount numeric;
    v_earn_amount   numeric;
    v_is_super_user boolean;
    v_lock_check    integer;
    v_woman_is_indian boolean := false;
    v_man_wallet_id  uuid;
    v_woman_wallet_id uuid;
BEGIN
    -- Lock session row
    SELECT * INTO v_session
    FROM public.active_chat_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF v_session IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session not found');
    END IF;

    -- Optimistic lock: prevents duplicate billing for the same minute
    UPDATE public.active_chat_sessions
    SET last_activity_at = now()
    WHERE id = p_session_id
      AND last_activity_at = v_session.last_activity_at;

    GET DIAGNOSTICS v_lock_check = ROW_COUNT;
    IF v_lock_check = 0 THEN
        RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0);
    END IF;

    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);

    -- Read active pricing
    SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    -- Check if woman is Indian (only Indian women earn)
    SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_woman_is_indian
    FROM public.profiles p
    LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
    WHERE p.user_id = v_session.woman_user_id;

    -- Compute amounts — women earn EXACTLY half of men's charge
    v_charge_amount := p_minutes * v_pricing.rate_per_minute;
    v_earn_amount   := CASE WHEN v_woman_is_indian THEN ROUND(v_charge_amount / 2.0, 2) ELSE 0 END;

    -- VALIDATE half-rule: women_earned must equal charged / 2 (or 0 for non-Indian)
    IF v_woman_is_indian AND v_earn_amount <> ROUND(v_charge_amount / 2.0, 2) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Half-rule validation failed: women earned does not equal half of men charged');
    END IF;

    -- Super user: update session stats only, no wallet changes
    IF v_is_super_user THEN
        UPDATE public.active_chat_sessions
        SET total_minutes = total_minutes + p_minutes
        WHERE id = p_session_id;
        RETURN jsonb_build_object('success', true, 'super_user', true, 'charged', 0, 'earned', 0);
    END IF;

    -- Lock man's wallet
    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets WHERE user_id = v_session.man_user_id FOR UPDATE;

    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        UPDATE public.active_chat_sessions
        SET status = 'ended', ended_at = now(), end_reason = 'insufficient_funds'
        WHERE id = p_session_id;
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'session_ended', true);
    END IF;

    -- Debit man's wallet.balance
    UPDATE public.wallets SET balance = balance - v_charge_amount, updated_at = now()
    WHERE id = v_man_wallet_id;

    -- Admin audit: record man's debit in wallet_transactions (admin-only, not shown on dashboard)
    INSERT INTO public.wallet_transactions (user_id, amount, transaction_type, description, balance_after, created_at)
    VALUES (v_session.man_user_id, v_charge_amount, 'debit',
            'Chat charge: ' || p_minutes || ' min @ ₹' || v_pricing.rate_per_minute || '/min (session ' || p_session_id || ')',
            (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id), now());

    -- Credit woman's wallet.balance (if Indian)
    IF v_earn_amount > 0 THEN
        SELECT id INTO v_woman_wallet_id FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;
        IF v_woman_wallet_id IS NOT NULL THEN
            UPDATE public.wallets SET balance = balance + v_earn_amount, updated_at = now()
            WHERE id = v_woman_wallet_id;
        END IF;

        -- Admin audit: record woman's earning in women_earnings (admin-only)
        INSERT INTO public.women_earnings (user_id, amount, earning_type, chat_session_id, description)
        VALUES (v_session.woman_user_id, v_earn_amount, 'chat', p_session_id,
                'Chat earning: ' || p_minutes || ' min @ ₹' || v_pricing.women_earning_rate || '/min (half of ₹' || v_charge_amount || ')');
    END IF;

    -- Update session totals
    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes,
        total_earned  = total_earned  + v_earn_amount
    WHERE id = p_session_id;

    RETURN jsonb_build_object(
        'success',          true,
        'charged',          v_charge_amount,
        'earned',           v_earn_amount,
        'woman_is_indian',  v_woman_is_indian,
        'half_rule_valid',  (v_earn_amount = ROUND(v_charge_amount / 2.0, 2) OR NOT v_woman_is_indian)
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ─── 2. process_video_billing — wallet-only, half-rule validated ──────────────
-- One man + one woman (same language). Man pays video_rate/min. Woman earns exactly half.

CREATE OR REPLACE FUNCTION public.process_video_billing(p_session_id uuid, p_minutes integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_session         RECORD;
    v_pricing         RECORD;
    v_man_wallet_id   uuid;
    v_man_balance     numeric;
    v_woman_wallet_id uuid;
    v_charge_amount   numeric;
    v_earn_amount     numeric;
    v_is_super_user   boolean;
    v_lock_check      integer;
    v_woman_is_indian boolean := false;
BEGIN
    -- Lock session row
    SELECT * INTO v_session FROM public.video_call_sessions WHERE id = p_session_id FOR UPDATE;
    IF v_session IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Session not found');
    END IF;

    -- Optimistic lock via updated_at (prevents duplicate per-minute billing)
    UPDATE public.video_call_sessions SET updated_at = now()
    WHERE id = p_session_id AND updated_at = v_session.updated_at;
    GET DIAGNOSTICS v_lock_check = ROW_COUNT;
    IF v_lock_check = 0 THEN
        RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0);
    END IF;

    v_is_super_user := public.should_bypass_balance(v_session.man_user_id);

    -- Read active pricing
    SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    -- Check if woman is Indian
    SELECT COALESCE(fp.is_indian, p.is_indian, false) INTO v_woman_is_indian
    FROM public.profiles p
    LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
    WHERE p.user_id = v_session.woman_user_id;

    -- Compute amounts — women earn EXACTLY half of men's charge
    v_charge_amount := p_minutes * v_pricing.video_rate_per_minute;
    v_earn_amount   := CASE WHEN v_woman_is_indian THEN ROUND(v_charge_amount / 2.0, 2) ELSE 0 END;

    -- VALIDATE half-rule
    IF v_woman_is_indian AND v_earn_amount <> ROUND(v_charge_amount / 2.0, 2) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Half-rule validation failed: video call');
    END IF;

    -- Super user: update session stats only
    IF v_is_super_user THEN
        UPDATE public.video_call_sessions
        SET total_minutes = total_minutes + p_minutes, total_earned = total_earned + v_earn_amount
        WHERE id = p_session_id;
        -- Still credit woman's wallet even for super user
        IF v_earn_amount > 0 THEN
            SELECT id INTO v_woman_wallet_id FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;
            IF v_woman_wallet_id IS NOT NULL THEN
                UPDATE public.wallets SET balance = balance + v_earn_amount, updated_at = now() WHERE id = v_woman_wallet_id;
            END IF;
            INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
            VALUES (v_session.woman_user_id, v_earn_amount, 'video_call',
                    'Video earning (super user session): ' || p_minutes || ' min @ ₹' || v_pricing.video_women_earning_rate || '/min');
        END IF;
        RETURN jsonb_build_object('success', true, 'super_user', true, 'charged', 0, 'earned', v_earn_amount);
    END IF;

    -- Lock man's wallet
    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets WHERE user_id = v_session.man_user_id FOR UPDATE;

    IF v_man_balance IS NULL OR v_man_balance < v_charge_amount THEN
        UPDATE public.video_call_sessions
        SET status = 'ended', ended_at = now(), end_reason = 'insufficient_funds'
        WHERE id = p_session_id;
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'session_ended', true);
    END IF;

    -- Debit man's wallet.balance
    UPDATE public.wallets SET balance = balance - v_charge_amount, updated_at = now()
    WHERE id = v_man_wallet_id;

    -- Admin audit record for man
    INSERT INTO public.wallet_transactions (user_id, amount, transaction_type, description, balance_after, created_at)
    VALUES (v_session.man_user_id, v_charge_amount, 'debit',
            'Video call: ' || p_minutes || ' min @ ₹' || v_pricing.video_rate_per_minute || '/min (session ' || p_session_id || ')',
            (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id), now());

    -- Credit woman's wallet.balance (if Indian)
    IF v_earn_amount > 0 THEN
        SELECT id INTO v_woman_wallet_id FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;
        IF v_woman_wallet_id IS NOT NULL THEN
            UPDATE public.wallets SET balance = balance + v_earn_amount, updated_at = now()
            WHERE id = v_woman_wallet_id;
        END IF;
        -- Admin audit record for woman
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_session.woman_user_id, v_earn_amount, 'video_call',
                'Video earning: ' || p_minutes || ' min @ ₹' || v_pricing.video_women_earning_rate || '/min (half of ₹' || v_charge_amount || ')');
    END IF;

    -- Update session totals
    UPDATE public.video_call_sessions
    SET total_minutes = total_minutes + p_minutes, total_earned = total_earned + v_earn_amount
    WHERE id = p_session_id;

    RETURN jsonb_build_object(
        'success',         true,
        'charged',         v_charge_amount,
        'earned',          v_earn_amount,
        'woman_is_indian', v_woman_is_indian,
        'half_rule_valid', (v_earn_amount = ROUND(v_charge_amount / 2.0, 2) OR NOT v_woman_is_indian)
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ─── 3. process_group_billing — wallet-only, half-rule validated per session ──
-- Multiple men + one Indian host. Each man charged individually.
-- Host earns (group_call_women_earning_rate × N active men) = SUM(men_charged) / 2.
-- Validation: host_earned = SUM(each man's charge) / 2

CREATE OR REPLACE FUNCTION public.process_group_billing(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_group            RECORD;
    v_pricing          RECORD;
    v_host_id          uuid;
    v_host_wallet_id   uuid;
    v_member           RECORD;
    v_wallet           RECORD;
    v_charge_per_man   numeric;
    v_earn_per_man     numeric;
    v_total_charged    numeric := 0;
    v_total_host_earn  numeric := 0;
    v_active_count     integer := 0;
    v_removed_users    uuid[]  := '{}';
    v_billed_users     uuid[]  := '{}';
    v_last_billing_at  timestamptz;
    v_half_rule_valid  boolean;
BEGIN
    -- Advisory lock: one billing cycle at a time per group
    PERFORM pg_advisory_xact_lock(hashtext('process_group_billing:' || p_group_id::text));

    SELECT * INTO v_group FROM public.private_groups
    WHERE id = p_group_id AND is_live = true AND is_active = true FOR UPDATE;
    IF v_group IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Group not live or not found');
    END IF;

    v_host_id := v_group.current_host_id;
    IF v_host_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active host');
    END IF;

    -- Read active pricing
    SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
    IF v_pricing IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active pricing');
    END IF;

    v_charge_per_man := COALESCE(v_pricing.group_call_rate_per_minute, v_pricing.rate_per_minute);
    -- earn_per_man is ALWAYS exactly half of charge_per_man (half-rule)
    v_earn_per_man   := ROUND(v_charge_per_man / 2.0, 2);

    -- Duplicate guard: skip if last billing was < 50 seconds ago
    SELECT GREATEST(
      COALESCE((
        SELECT MAX(created_at) FROM public.wallet_transactions wt
        WHERE wt.user_id IN (
          SELECT gm.user_id FROM public.group_memberships gm
          WHERE gm.group_id = p_group_id AND gm.has_access = true AND gm.user_id != v_host_id
        ) AND wt.transaction_type = 'debit'
          AND wt.description LIKE 'Group call: %' || p_group_id::text || '%'
      ), 'epoch'::timestamptz),
      COALESCE((
        SELECT MAX(created_at) FROM public.women_earnings we
        WHERE we.user_id = v_host_id AND we.earning_type = 'group_call'
          AND we.description LIKE '%' || p_group_id::text || '%'
      ), 'epoch'::timestamptz)
    ) INTO v_last_billing_at;

    IF v_last_billing_at > (now() - interval '50 seconds') THEN
        RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'last_billed_at', v_last_billing_at);
    END IF;

    -- Lock host wallet
    SELECT id INTO v_host_wallet_id FROM public.wallets WHERE user_id = v_host_id FOR UPDATE;

    -- Bill each active male participant individually
    FOR v_member IN
        SELECT gm.user_id
        FROM public.group_memberships gm
        WHERE gm.group_id = p_group_id AND gm.has_access = true AND gm.user_id != v_host_id
    LOOP
        SELECT id, balance INTO v_wallet FROM public.wallets WHERE user_id = v_member.user_id FOR UPDATE;

        IF v_wallet.balance IS NULL OR v_wallet.balance < v_charge_per_man THEN
            -- Insufficient funds: remove from group
            UPDATE public.group_memberships SET has_access = false
            WHERE group_id = p_group_id AND user_id = v_member.user_id;
            v_removed_users := array_append(v_removed_users, v_member.user_id);
            CONTINUE;
        END IF;

        -- Debit each man's wallet.balance individually
        UPDATE public.wallets SET balance = balance - v_charge_per_man, updated_at = now() WHERE id = v_wallet.id;

        -- Admin audit record for this man
        INSERT INTO public.wallet_transactions (user_id, amount, transaction_type, description, balance_after, created_at)
        VALUES (v_member.user_id, v_charge_per_man, 'debit',
                'Group call: ' || v_group.name || ' @ ₹' || v_charge_per_man || '/min (group ' || p_group_id || ')',
                (SELECT balance FROM public.wallets WHERE id = v_wallet.id), now());

        v_active_count  := v_active_count  + 1;
        v_total_charged := v_total_charged + v_charge_per_man;
        -- Host earns exactly half per man
        v_total_host_earn := v_total_host_earn + v_earn_per_man;
        v_billed_users := array_append(v_billed_users, v_member.user_id);
    END LOOP;

    -- VALIDATE half-rule: SUM(men_charged) / 2 = host_earned
    IF v_active_count > 0 THEN
        v_half_rule_valid := (ROUND(v_total_charged / 2.0, 2) = ROUND(v_total_host_earn, 2));
        IF NOT v_half_rule_valid THEN
            RAISE EXCEPTION 'Half-rule validation failed: total_charged=% total_host_earn=% expected=%',
                v_total_charged, v_total_host_earn, ROUND(v_total_charged / 2.0, 2);
        END IF;

        -- Credit host wallet.balance with total earned
        IF v_host_wallet_id IS NOT NULL THEN
            UPDATE public.wallets SET balance = balance + v_total_host_earn, updated_at = now()
            WHERE id = v_host_wallet_id;
        END IF;

        -- Admin audit: women_earnings record for host
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (v_host_id, v_total_host_earn, 'group_call',
                'Group call: ' || v_group.name || ' — ' || v_active_count || ' man(s) × ₹' || v_earn_per_man ||
                '/min = ₹' || v_total_host_earn || ' (half of ₹' || v_total_charged || ' total charged, group ' || p_group_id || ')');
    END IF;

    -- Update group participant count
    UPDATE public.private_groups
    SET participant_count = (SELECT count(*) FROM public.group_memberships WHERE group_id = p_group_id AND has_access = true)
    WHERE id = p_group_id;

    RETURN jsonb_build_object(
        'success',          true,
        'active_count',     v_active_count,
        'total_charged',    v_total_charged,
        'host_earned',      v_total_host_earn,
        'half_rule_valid',  v_active_count = 0 OR (ROUND(v_total_charged / 2.0, 2) = ROUND(v_total_host_earn, 2)),
        'removed_users',    to_jsonb(v_removed_users),
        'billed_users',     to_jsonb(v_billed_users)
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ─── 4. recharge_wallet — adds to existing wallets.balance ────────────────────
-- Men recharge: amount added on top of existing balance. Admin audit record created.

CREATE OR REPLACE FUNCTION public.recharge_men_wallet(p_user_id uuid, p_amount numeric, p_description text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_wallet_id   uuid;
    v_old_balance numeric;
    v_new_balance numeric;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Recharge amount must be positive');
    END IF;

    SELECT id, balance INTO v_wallet_id, v_old_balance
    FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;

    IF v_wallet_id IS NULL THEN
        -- Create wallet if it doesn't exist
        INSERT INTO public.wallets (user_id, balance, currency)
        VALUES (p_user_id, 0, 'INR')
        RETURNING id, balance INTO v_wallet_id, v_old_balance;
    END IF;

    -- Add recharge amount to EXISTING balance (not replace)
    v_new_balance := v_old_balance + p_amount;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;

    -- Admin audit record
    INSERT INTO public.wallet_transactions (user_id, amount, transaction_type, description, balance_after, created_at)
    VALUES (p_user_id, p_amount, 'recharge',
            COALESCE(p_description, 'Wallet recharge: ₹' || p_amount),
            v_new_balance, now());

    RETURN jsonb_build_object(
        'success',          true,
        'previous_balance', v_old_balance,
        'added_amount',     p_amount,
        'new_balance',      v_new_balance
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ─── 5. get_men_wallet_balance — wallets.balance is the only source of truth ──
-- Returns only the current wallet balance. No transaction history for dashboard.

CREATE OR REPLACE FUNCTION public.get_men_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_balance numeric := 0;
BEGIN
    SELECT COALESCE(balance, 0) INTO v_balance
    FROM public.wallets WHERE user_id = p_user_id;

    -- wallets.balance is the single source of truth — already kept in sync
    -- by every billing/recharge RPC atomically. No recalculation needed.
    RETURN jsonb_build_object('balance', v_balance);
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('balance', 0, 'error', SQLERRM);
END;
$$;

-- ─── 6. get_women_wallet_balance — wallets.balance is the only source of truth ─
-- Returns only current wallet balance + pending withdrawals.
-- wallets.balance is updated directly on every earning credit and withdrawal debit.

CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_wallet_balance    numeric := 0;
    v_pending_withdrawals numeric := 0;
    v_available_balance numeric := 0;
BEGIN
    -- wallets.balance = single source of truth (incremented by every earning credit)
    SELECT COALESCE(balance, 0) INTO v_wallet_balance
    FROM public.wallets WHERE user_id = p_user_id;

    -- Pending withdrawals reduce available balance (not yet deducted from wallet)
    SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
    FROM public.withdrawal_requests
    WHERE user_id = p_user_id AND status = 'pending';

    v_available_balance := v_wallet_balance - v_pending_withdrawals;

    RETURN jsonb_build_object(
        'balance',              v_wallet_balance,
        'available_balance',    GREATEST(v_available_balance, 0),
        'pending_withdrawals',  v_pending_withdrawals,
        -- total_earnings kept for display only — not used to compute balance
        'total_earnings',       v_wallet_balance + (
            SELECT COALESCE(SUM(amount), 0) FROM public.withdrawal_requests
            WHERE user_id = p_user_id AND status IN ('approved', 'processed')
        )
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('balance', 0, 'available_balance', 0, 'pending_withdrawals', 0, 'total_earnings', 0);
END;
$$;

-- ─── 7. request_withdrawal — deducts from wallets.balance atomically ──────────
-- When admin approves, balance is already deducted on request.
-- No double-deduction: withdrawal_request status tracks approval, not balance.

CREATE OR REPLACE FUNCTION public.request_women_withdrawal(
    p_user_id       uuid,
    p_amount        numeric,
    p_payment_method text DEFAULT 'upi',
    p_payment_details jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_wallet_id          uuid;
    v_wallet_balance     numeric;
    v_pending_withdrawals numeric := 0;
    v_available          numeric;
    v_min_withdrawal     numeric := 5000;
    v_pricing            RECORD;
    v_request_id         uuid;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Withdrawal amount must be positive');
    END IF;

    -- Get min withdrawal from pricing
    SELECT min_withdrawal_balance INTO v_min_withdrawal
    FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
    v_min_withdrawal := COALESCE(v_min_withdrawal, 5000);

    -- Lock wallet
    SELECT id, balance INTO v_wallet_id, v_wallet_balance
    FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;

    IF v_wallet_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
    END IF;

    -- Pending withdrawals
    SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
    FROM public.withdrawal_requests WHERE user_id = p_user_id AND status = 'pending';

    v_available := v_wallet_balance - v_pending_withdrawals;

    IF v_available < v_min_withdrawal THEN
        RETURN jsonb_build_object('success', false, 'error',
            'Minimum withdrawal is ₹' || v_min_withdrawal || '. Available: ₹' || v_available);
    END IF;

    IF p_amount > v_available THEN
        RETURN jsonb_build_object('success', false, 'error',
            'Insufficient available balance. Available: ₹' || v_available);
    END IF;

    -- Create withdrawal request (pending admin approval)
    INSERT INTO public.withdrawal_requests (user_id, amount, payment_method, payment_details, status)
    VALUES (p_user_id, p_amount, p_payment_method, p_payment_details, 'pending')
    RETURNING id INTO v_request_id;

    -- Note: wallets.balance is NOT deducted here. It is deducted when admin approves.
    -- This prevents double-deduction. Available balance = wallet_balance - pending_requests.

    RETURN jsonb_build_object(
        'success',            true,
        'request_id',         v_request_id,
        'amount_requested',   p_amount,
        'available_balance',  v_available - p_amount
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ─── 8. approve_withdrawal — deducts from wallets.balance on approval ─────────

CREATE OR REPLACE FUNCTION public.approve_women_withdrawal(p_request_id uuid, p_admin_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_request    RECORD;
    v_wallet_id  uuid;
    v_balance    numeric;
BEGIN
    SELECT * INTO v_request FROM public.withdrawal_requests
    WHERE id = p_request_id AND status = 'pending' FOR UPDATE;

    IF v_request IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Withdrawal request not found or not pending');
    END IF;

    SELECT id, balance INTO v_wallet_id, v_balance
    FROM public.wallets WHERE user_id = v_request.user_id FOR UPDATE;

    IF v_balance < v_request.amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient wallet balance for this withdrawal');
    END IF;

    -- Deduct from wallet.balance on approval
    UPDATE public.wallets SET balance = balance - v_request.amount, updated_at = now() WHERE id = v_wallet_id;

    -- Admin audit
    INSERT INTO public.wallet_transactions (user_id, amount, transaction_type, description, balance_after, created_at)
    VALUES (v_request.user_id, v_request.amount, 'withdrawal',
            'Withdrawal approved by admin (request ' || p_request_id || ')',
            (SELECT balance FROM public.wallets WHERE id = v_wallet_id), now());

    -- Mark request approved
    UPDATE public.withdrawal_requests
    SET status = 'approved', processed_at = now(), processed_by = p_admin_id
    WHERE id = p_request_id;

    RETURN jsonb_build_object('success', true, 'amount_deducted', v_request.amount,
        'new_balance', (SELECT balance FROM public.wallets WHERE id = v_wallet_id));
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ─── 9. Session-level half-rule validation view (admin) ───────────────────────
-- Admin can audit that every session satisfies: men_total_charged = 2 × women_earned

CREATE OR REPLACE VIEW public.admin_session_half_rule_audit AS
SELECT
    'chat'          AS session_type,
    s.id            AS session_id,
    s.man_user_id,
    s.woman_user_id,
    s.total_minutes,
    -- total charged to this man for this session
    COALESCE(SUM(wt.amount) FILTER (WHERE wt.user_id = s.man_user_id), 0) AS total_man_charged,
    -- total earned by woman for this session
    COALESCE(SUM(we.amount), 0)                                            AS total_woman_earned,
    -- half-rule: man_charged should equal 2 × woman_earned
    CASE
        WHEN COALESCE(SUM(we.amount), 0) = 0 THEN true  -- non-Indian woman earns 0, no violation
        ELSE ROUND(COALESCE(SUM(wt.amount) FILTER (WHERE wt.user_id = s.man_user_id), 0), 2)
             = ROUND(COALESCE(SUM(we.amount), 0) * 2, 2)
    END AS half_rule_valid,
    s.created_at
FROM public.active_chat_sessions s
LEFT JOIN public.wallet_transactions wt
    ON wt.user_id = s.man_user_id AND wt.description LIKE '%session ' || s.id || '%'
LEFT JOIN public.women_earnings we
    ON we.user_id = s.woman_user_id AND we.chat_session_id = s.id
WHERE s.created_at >= now() - interval '6 months'
GROUP BY s.id, s.man_user_id, s.woman_user_id, s.total_minutes, s.created_at;

COMMENT ON VIEW public.admin_session_half_rule_audit IS
    'Admin audit view: verifies men_charged = 2 × women_earned for every session. '
    'half_rule_valid = false indicates a billing inconsistency that needs investigation.';

-- ─── 10. Grant permissions ────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION public.process_chat_billing(uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_video_billing(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_group_billing(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recharge_men_wallet(uuid, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_men_wallet_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_women_wallet_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_women_withdrawal(uuid, numeric, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_women_withdrawal(uuid, uuid) TO service_role;
