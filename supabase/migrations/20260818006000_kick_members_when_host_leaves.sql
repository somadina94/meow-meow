-- When the woman host exits a group call:
-- 1) Mark her host row inactive immediately
-- 2) Kick members who joined her (has_access = false) so they cannot keep billing
-- 3) Do not charge private_group_call minutes unless that host is still live
-- 4) Provide leave_group_atomic (client already calls it; it was missing from repo)

CREATE OR REPLACE FUNCTION public.stop_host_session(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_remaining integer;
  v_next_host record;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  UPDATE public.group_active_hosts
  SET is_active = false,
      last_heartbeat_at = now() - interval '3 minutes'
  WHERE group_id = p_group_id AND host_id = v_user_id;

  UPDATE public.group_memberships
  SET has_access = false,
      joined_host_id = NULL
  WHERE group_id = p_group_id
    AND (joined_host_id = v_user_id OR user_id = v_user_id);

  SELECT COUNT(*) INTO v_remaining
  FROM public.group_active_hosts
  WHERE group_id = p_group_id AND is_active = true;

  IF v_remaining = 0 THEN
    UPDATE public.private_groups
    SET is_live = false,
        stream_id = NULL,
        current_host_id = NULL,
        current_host_name = NULL,
        participant_count = 0,
        updated_at = now()
    WHERE id = p_group_id;
  ELSE
    SELECT host_id, host_name INTO v_next_host
    FROM public.group_active_hosts
    WHERE group_id = p_group_id AND is_active = true
    ORDER BY started_at ASC
    LIMIT 1;

    UPDATE public.private_groups
    SET current_host_id = v_next_host.host_id,
        current_host_name = v_next_host.host_name,
        participant_count = GREATEST(participant_count, 0),
        updated_at = now()
    WHERE id = p_group_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'remaining_hosts', v_remaining);
END;
$$;

GRANT EXECUTE ON FUNCTION public.stop_host_session(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.leave_group_atomic(p_group_id uuid, p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user uuid := COALESCE(p_user_id, auth.uid());
  v_host uuid;
  v_had_access boolean;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF auth.uid() IS NOT NULL
     AND auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_user
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not allowed');
  END IF;

  SELECT joined_host_id, has_access
    INTO v_host, v_had_access
  FROM public.group_memberships
  WHERE group_id = p_group_id AND user_id = v_user;

  IF NOT FOUND OR COALESCE(v_had_access, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('success', true, 'already_left', true);
  END IF;

  UPDATE public.group_memberships
  SET has_access = false, joined_host_id = NULL
  WHERE group_id = p_group_id AND user_id = v_user;

  UPDATE public.private_groups
  SET participant_count = GREATEST(participant_count - 1, 0),
      updated_at = now()
  WHERE id = p_group_id
    AND COALESCE(is_live, false) = true;

  IF v_host IS NOT NULL THEN
    UPDATE public.group_active_hosts
    SET participant_count = GREATEST(participant_count - 1, 0)
    WHERE group_id = p_group_id AND host_id = v_host AND is_active = true;
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.leave_group_atomic(uuid, uuid) TO authenticated, service_role;

-- Same bill_session_minute as 20260818003000, plus: refuse group minutes after host left.
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

  IF p_session_type = 'chat' AND NOT public.chat_session_has_mutual_replies(p_session_id) THEN
    RETURN jsonb_build_object('success',true,'skipped','waiting_for_replies');
  END IF;

  IF p_session_type IN ('audio_call','video_call') AND NOT public.call_session_was_answered(p_session_id) THEN
    RETURN jsonb_build_object('success',true,'skipped','not_answered');
  END IF;

  IF p_session_type = 'private_group_call' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.group_active_hosts gah
      WHERE gah.host_id = v_woman_id
        AND gah.is_active = true
        AND gah.last_heartbeat_at > now() - interval '2 minutes'
        AND (
          gah.stream_id = p_session_id::text
          OR EXISTS (
            SELECT 1 FROM public.group_memberships gm
            WHERE gm.group_id = gah.group_id
              AND gm.user_id = v_man_id
              AND gm.has_access = true
              AND gm.joined_host_id = v_woman_id
          )
        )
    ) INTO v_is_live_group_host;
    IF NOT COALESCE(v_is_live_group_host, false) THEN
      RETURN jsonb_build_object('success',true,'skipped','host_not_live');
    END IF;
  END IF;

  IF auth.role() <> 'service_role'
     AND v_caller IS DISTINCT FROM v_man_id
     AND NOT (p_session_type = 'private_group_call' AND v_caller IS NOT DISTINCT FROM v_woman_id AND v_is_live_group_host)
     AND NOT public.has_role(v_caller, 'admin') THEN
    RETURN jsonb_build_object('success',false,'error','Not allowed to bill for this user');
  END IF;

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

GRANT EXECUTE ON FUNCTION public.bill_session_minute(uuid, text, numeric, uuid, uuid, integer, integer) TO authenticated, service_role;
