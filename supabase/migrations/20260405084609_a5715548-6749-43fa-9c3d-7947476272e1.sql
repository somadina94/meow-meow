-- BUG FIX 1: process_video_billing — use correct rate for audio vs video calls
CREATE OR REPLACE FUNCTION public.process_video_billing(p_session_id uuid, p_minutes integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_session RECORD; v_pricing RECORD; v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_charge numeric; v_earn numeric; v_is_super boolean;
  v_lock_check integer; v_woman_indian boolean := false; v_idem_key text; v_minute_bucket bigint;
  v_rate_per_min numeric; v_call_type text; v_call_label text;
BEGIN
  SELECT * INTO v_session FROM public.video_call_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Session not found'); END IF;

  UPDATE public.video_call_sessions SET updated_at = now()
  WHERE id = p_session_id AND updated_at = v_session.updated_at;
  GET DIAGNOSTICS v_lock_check = ROW_COUNT;
  IF v_lock_check = 0 THEN RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0); END IF;

  v_minute_bucket := floor(extract(epoch from now()) / 60)::bigint;
  v_idem_key := 'video:' || p_session_id::text || ':' || v_minute_bucket::text;
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'idempotency_key', v_idem_key, 'charged', 0, 'earned', 0);
  END IF;

  v_is_super := public.should_bypass_balance(v_session.man_user_id);
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'No active pricing'); END IF;

  SELECT COALESCE(fp.is_indian, pr.is_indian, false) INTO v_woman_indian
  FROM public.profiles pr LEFT JOIN public.female_profiles fp ON fp.user_id = pr.user_id
  WHERE pr.user_id = v_session.woman_user_id;

  -- Determine correct rate based on call_type
  v_call_type := COALESCE(v_session.call_type, 'video');
  IF v_call_type = 'audio' THEN
    v_rate_per_min := v_pricing.audio_rate_per_minute;       -- ₹6
    v_call_label := 'Audio call';
  ELSE
    v_rate_per_min := v_pricing.video_rate_per_minute;       -- ₹8
    v_call_label := 'Video call';
  END IF;

  v_charge := ROUND(p_minutes * v_rate_per_min, 2);
  v_earn   := CASE WHEN v_woman_indian THEN ROUND(v_charge / 2.0, 2) ELSE 0 END;

  IF v_is_super THEN
    IF v_earn > 0 THEN
      SELECT id INTO v_woman_wallet_id FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;
      IF v_woman_wallet_id IS NOT NULL THEN UPDATE public.wallets SET balance = balance + v_earn, updated_at = now() WHERE id = v_woman_wallet_id; END IF;
      INSERT INTO public.women_earnings (user_id, amount, earning_type, description, created_at)
      VALUES (v_session.woman_user_id, v_earn, 'video_call', v_call_label || ' (super user): ' || p_minutes || ' min', now());
    END IF;
    UPDATE public.video_call_sessions SET total_minutes = total_minutes + p_minutes, total_earned = total_earned + v_earn WHERE id = p_session_id;
    RETURN jsonb_build_object('success', true, 'super_user', true, 'charged', 0, 'earned', v_earn);
  END IF;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance FROM public.wallets WHERE user_id = v_session.man_user_id FOR UPDATE;
  IF v_man_balance IS NULL OR v_man_balance < v_charge THEN
    UPDATE public.video_call_sessions SET status = 'ended', ended_at = now(), end_reason = 'insufficient_funds' WHERE id = p_session_id;
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'session_ended', true);
  END IF;

  UPDATE public.wallets SET balance = balance - v_charge, updated_at = now() WHERE id = v_man_wallet_id;
  INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, created_at)
  VALUES (v_session.man_user_id, 'debit', 'debit', v_charge,
          v_call_label || ': ' || p_minutes || ' min @ ₹' || v_rate_per_min || '/min',
          p_session_id, (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id),
          v_idem_key, 'completed', now());

  IF v_earn > 0 THEN
    SELECT id INTO v_woman_wallet_id FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL THEN UPDATE public.wallets SET balance = balance + v_earn, updated_at = now() WHERE id = v_woman_wallet_id; END IF;
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, created_at)
    VALUES (v_session.woman_user_id, v_earn, 'video_call', v_call_label || ': ' || p_minutes || ' min (½ of ₹' || v_charge || ')', now());
  END IF;

  UPDATE public.video_call_sessions SET total_minutes = total_minutes + p_minutes, total_earned = total_earned + v_earn WHERE id = p_session_id;
  RETURN jsonb_build_object('success', true, 'charged', v_charge, 'earned', v_earn, 'woman_indian', v_woman_indian, 'call_type', v_call_type, 'rate_per_minute', v_rate_per_min, 'idempotency_key', v_idem_key);
EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $function$;


-- BUG FIX 2: process_group_billing — use group_call_rate and group_call_women_earning_rate
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

    -- FIX: Use group_call_rate_per_minute instead of rate_per_minute
    v_charge_amount := v_pricing.group_call_rate_per_minute;

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
        
        -- FIX: Use group_call_women_earning_rate instead of women_earning_rate
        IF v_host_is_indian THEN
            v_total_host_earning := v_total_host_earning + v_pricing.group_call_women_earning_rate;
        END IF;
    END LOOP;

    IF v_total_host_earning > 0 THEN
        INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
        VALUES (
            v_host_id,
            v_total_host_earning,
            'group_call',
            'Group call earnings: ' || v_group.name || ' - ' || v_active_count || ' participants @ ₹' || v_pricing.group_call_women_earning_rate || '/each'
        );

        -- Credit host wallet
        UPDATE public.wallets
        SET balance = balance + v_total_host_earning, updated_at = now()
        WHERE user_id = v_host_id;
    END IF;

    -- Update participant count
    UPDATE public.private_groups
    SET participant_count = v_active_count + 1
    WHERE id = p_group_id;

    RETURN jsonb_build_object(
        'success', true,
        'billed_count', v_active_count,
        'total_host_earning', v_total_host_earning,
        'removed_users', to_jsonb(v_removed_users),
        'billed_users', to_jsonb(v_billed_users),
        'rate_per_minute', v_charge_amount,
        'host_earning_rate', v_pricing.group_call_women_earning_rate,
        'host_is_indian', v_host_is_indian
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $function$;


-- BUG FIX 3: init_video_call_billing trigger — use audio rate for audio calls
CREATE OR REPLACE FUNCTION public.init_video_call_billing()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_rate NUMERIC;
  v_call_type TEXT;
BEGIN
  IF NEW.status = 'active' AND (OLD.status IS NULL OR OLD.status != 'active') THEN
    v_call_type := COALESCE(NEW.call_type, 'video');
    
    IF v_call_type = 'audio' THEN
      SELECT audio_rate_per_minute INTO v_rate
      FROM chat_pricing WHERE is_active = true LIMIT 1;
      v_rate := COALESCE(v_rate, 6.0);
    ELSE
      SELECT video_rate_per_minute INTO v_rate
      FROM chat_pricing WHERE is_active = true LIMIT 1;
      v_rate := COALESCE(v_rate, 8.0);
    END IF;
    
    IF NEW.rate_per_minute IS NULL OR NEW.rate_per_minute = 0 THEN
      NEW.rate_per_minute := v_rate;
    END IF;
    IF NEW.started_at IS NULL THEN
      NEW.started_at := now();
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;