-- Add TL role to service_role enum
ALTER TYPE public.service_role ADD VALUE IF NOT EXISTS 'tl_role';

-- Update bill_session_minute to fully bypass BOTH sides when either party is admin
CREATE OR REPLACE FUNCTION public.bill_session_minute(p_session_id uuid, p_session_type text, p_minutes numeric, p_man_id uuid, p_woman_id uuid, p_man_count integer DEFAULT 1, p_minute_index integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pricing jsonb;
  v_man_wallet_id uuid;
  v_woman_wallet_id uuid;
  v_man_id uuid := public.resolve_wallet_user_id(p_man_id);
  v_woman_id uuid := public.resolve_wallet_user_id(p_woman_id);
  v_man_rate numeric(10,2);
  v_woman_rate numeric(10,2);
  v_charge numeric(10,2);
  v_earn numeric(10,2);
  v_man_balance numeric(12,2);
  v_woman_balance numeric(12,2);
  v_man_balance_after numeric(12,2);
  v_woman_balance_after numeric(12,2);
  v_idem_key text;
  v_idem_earn text;
  v_man_is_admin boolean := false;
  v_woman_is_admin boolean := false;
  v_admin_bypass boolean := false;
  v_minute_idx integer;
  v_label text;
  v_caller uuid := auth.uid();
  v_is_live_group_host boolean := false;
BEGIN
  IF p_session_type NOT IN ('chat','audio_call','video_call','private_group_call') THEN
    RETURN jsonb_build_object('success',false,'error','Invalid session_type');
  END IF;
  IF p_minutes <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','minutes must be > 0');
  END IF;
  IF v_man_id IS NULL OR v_woman_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','Missing billing user');
  END IF;

  IF p_session_type = 'private_group_call' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.group_active_hosts gah
      WHERE gah.host_id = v_woman_id
        AND gah.stream_id = p_session_id::text
        AND gah.is_active = true
        AND gah.last_heartbeat_at > now() - interval '2 minutes'
    ) INTO v_is_live_group_host;
  END IF;

  IF auth.role() <> 'service_role'
     AND v_caller IS DISTINCT FROM v_man_id
     AND NOT (p_session_type = 'private_group_call' AND v_caller IS NOT DISTINCT FROM v_woman_id AND v_is_live_group_host)
     AND NOT public.has_role(v_caller, 'admin') THEN
    RETURN jsonb_build_object('success',false,'error','Not allowed to bill for this user');
  END IF;

  -- ADMIN BYPASS: when either participant is admin, skip debit AND credit entirely.
  SELECT public.has_role(v_man_id, 'admin')   INTO v_man_is_admin;
  SELECT public.has_role(v_woman_id, 'admin') INTO v_woman_is_admin;
  v_admin_bypass := v_man_is_admin OR v_woman_is_admin;

  IF v_admin_bypass THEN
    RETURN jsonb_build_object('success',true,'skipped','admin','session_type',p_session_type,'minutes',p_minutes);
  END IF;

  v_minute_idx := COALESCE(p_minute_index, FLOOR(EXTRACT(EPOCH FROM date_trunc('minute', now())) / 60)::integer);
  v_idem_key  := 'session|' || p_session_id::text || '|' || p_session_type || '|' || v_man_id::text || '|' || v_minute_idx::text;
  v_idem_earn := 'session_earn|' || p_session_id::text || '|' || p_session_type || '|' || v_woman_id::text || '|' || v_man_id::text || '|' || v_minute_idx::text;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key)
     OR EXISTS (SELECT 1 FROM public.wallet_transactions_archive WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
  END IF;

  v_pricing := public.get_unified_pricing();
  v_man_rate := CASE p_session_type
    WHEN 'chat' THEN (v_pricing->>'chat_man_rate')::numeric
    WHEN 'audio_call' THEN (v_pricing->>'audio_man_rate')::numeric
    WHEN 'video_call' THEN (v_pricing->>'video_man_rate')::numeric
    WHEN 'private_group_call' THEN (v_pricing->>'group_man_rate')::numeric
  END;
  v_woman_rate := CASE p_session_type
    WHEN 'chat' THEN (v_pricing->>'chat_woman_rate')::numeric
    WHEN 'audio_call' THEN (v_pricing->>'audio_woman_rate')::numeric
    WHEN 'video_call' THEN (v_pricing->>'video_woman_rate')::numeric
    WHEN 'private_group_call' THEN (v_pricing->>'group_woman_rate')::numeric
  END;

  v_charge := ROUND(v_man_rate * p_minutes, 2);
  v_earn   := ROUND(v_woman_rate * p_minutes * GREATEST(p_man_count,1), 2);
  v_label  := CASE p_session_type
    WHEN 'chat' THEN 'Chat'
    WHEN 'audio_call' THEN 'Audio Call'
    WHEN 'video_call' THEN 'Video Call'
    WHEN 'private_group_call' THEN 'Group Call'
  END;

  v_man_wallet_id := public.ensure_canonical_wallet(v_man_id, 'male');
  v_man_balance := public.canonical_wallet_balance(v_man_id);

  IF v_man_balance < v_charge THEN
    RETURN jsonb_build_object('success',false,'error','Insufficient balance','balance',v_man_balance,'required',v_charge);
  END IF;

  v_man_balance_after := (v_man_balance - v_charge)::numeric(12,2);

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, session_type, session_id,
    amount, balance_after, duration_seconds, rate_per_minute,
    description, idempotency_key, status
  ) VALUES (
    v_man_wallet_id, v_man_id, 'debit', 'session_charge', p_session_type, p_session_id,
    v_charge, v_man_balance_after, ROUND(p_minutes * 60)::int, v_man_rate,
    v_label || ' — ' || p_minutes || ' min @ ₹' || v_man_rate || '/min',
    v_idem_key, 'completed'
  );

  IF v_earn > 0 THEN
    v_woman_wallet_id := public.ensure_canonical_wallet(v_woman_id, 'female');
    v_woman_balance := public.canonical_wallet_balance(v_woman_id);
    v_woman_balance_after := (v_woman_balance + v_earn)::numeric(12,2);

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type, session_id,
      amount, balance_after, duration_seconds, rate_per_minute,
      description, idempotency_key, status
    ) VALUES (
      v_woman_wallet_id, v_woman_id, 'credit', 'session_earning', p_session_type, p_session_id,
      v_earn, v_woman_balance_after, ROUND(p_minutes * 60)::int, v_woman_rate,
      v_label || ' earnings — ' || p_minutes || ' min @ ₹' || v_woman_rate || '/min',
      v_idem_earn, 'completed'
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'session_type', p_session_type,
    'charged', v_charge,
    'earned', v_earn,
    'man_rate', v_man_rate,
    'woman_rate', v_woman_rate,
    'minutes', p_minutes,
    'minute_index', v_minute_idx
  );
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
END;
$function$;

-- Update bill_group_chat_minute: bypass when man or host is admin
CREATE OR REPLACE FUNCTION public.bill_group_chat_minute(p_session_id uuid, p_man_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_session RECORD;
  v_part RECORD;
  v_balance numeric;
  v_minute int;
  v_man_idem text;
  v_host_idem text;
  v_plat_idem text;
  v_man_charge numeric := 2.00;
  v_host_earn  numeric := 1.00;
  v_plat_rev   numeric := 1.00;
  v_platform_user uuid;
BEGIN
  SELECT * INTO v_session FROM public.group_chat_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_session.ended_at IS NOT NULL THEN
    RETURN jsonb_build_object('success',false,'error','session not live');
  END IF;
  SELECT * INTO v_part FROM public.group_chat_participants
    WHERE session_id = p_session_id AND user_id = p_man_id AND left_at IS NULL LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','not active participant');
  END IF;

  -- ADMIN BYPASS: no debit, no credit, no bookkeeping charges when admin is on either side
  IF public.has_role(p_man_id, 'admin') OR public.has_role(v_session.host_id, 'admin') THEN
    RETURN jsonb_build_object('success',true,'skipped','admin');
  END IF;

  v_minute := v_part.last_billed_minute + 1;
  v_man_idem  := 'groupchat:'||p_session_id::text||':'||p_man_id::text||':min:'||v_minute::text||':charge';
  v_host_idem := 'groupchat:'||p_session_id::text||':'||p_man_id::text||':min:'||v_minute::text||':host';
  v_plat_idem := 'groupchat:'||p_session_id::text||':'||p_man_id::text||':min:'||v_minute::text||':plat';

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_man_idem) THEN
    RETURN jsonb_build_object('success',true,'duplicate',true);
  END IF;

  v_balance := public.canonical_wallet_balance(p_man_id);
  IF v_balance < v_man_charge THEN
    RETURN jsonb_build_object('success',false,'insufficient',true,'balance',v_balance);
  END IF;

  INSERT INTO public.wallet_transactions
    (user_id, type, transaction_type, amount, description, session_id, session_type, idempotency_key, status, rate_per_minute, billing_metadata)
  VALUES
    (p_man_id, 'debit', 'debit', v_man_charge,
     'Group chat: min '||v_minute||' @ ₹'||v_man_charge||'/min',
     p_session_id, 'group_chat', v_man_idem, 'completed', v_man_charge,
     jsonb_build_object('minute',v_minute,'session',p_session_id,'kind','group_chat_minute_charge'));

  INSERT INTO public.wallet_transactions
    (user_id, type, transaction_type, amount, description, session_id, session_type, idempotency_key, status, rate_per_minute, billing_metadata)
  VALUES
    (v_session.host_id, 'credit', 'credit', v_host_earn,
     'Group chat earning: min '||v_minute||' from male user',
     p_session_id, 'group_chat', v_host_idem, 'completed', v_host_earn,
     jsonb_build_object('minute',v_minute,'session',p_session_id,'kind','group_chat_host_earning','man_id',p_man_id));

  SELECT user_id INTO v_platform_user FROM public.user_roles WHERE role = 'admin' ORDER BY user_id LIMIT 1;
  IF v_platform_user IS NOT NULL THEN
    INSERT INTO public.wallet_transactions
      (user_id, type, transaction_type, amount, description, session_id, session_type, idempotency_key, status, rate_per_minute, billing_metadata)
    VALUES
      (v_platform_user, 'credit', 'credit', v_plat_rev,
       'Group chat platform revenue: min '||v_minute,
       p_session_id, 'group_chat', v_plat_idem, 'completed', v_plat_rev,
       jsonb_build_object('minute',v_minute,'session',p_session_id,'kind','group_chat_platform_revenue','man_id',p_man_id));
  END IF;

  UPDATE public.group_chat_participants
    SET last_billed_minute = v_minute,
        total_billed = total_billed + v_man_charge,
        total_seconds = total_seconds + 60
    WHERE id = v_part.id;
  UPDATE public.group_chat_sessions
    SET total_men_minutes = total_men_minutes + 1,
        total_host_earning = total_host_earning + v_host_earn,
        total_platform_revenue = total_platform_revenue + v_plat_rev
    WHERE id = p_session_id;

  RETURN jsonb_build_object('success',true,'minute',v_minute,'balance',v_balance - v_man_charge);
END $function$;