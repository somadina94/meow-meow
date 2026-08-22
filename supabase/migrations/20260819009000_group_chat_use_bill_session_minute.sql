-- Route group chat billing through bill_session_minute (same SoT as 1:1 chat / group call).
-- Fixes wallet not updating when standalone group-chat inserts were blocked or rolled back.

CREATE OR REPLACE FUNCTION public.group_chat_has_mutual_engagement(p_session_id uuid, p_host_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.group_chat_messages m
     WHERE m.session_id = p_session_id
       AND m.deleted_at IS NULL
       AND m.sender_id = p_host_id
       AND (
         (COALESCE(trim(m.body), '') <> '' AND left(trim(m.body), 1) <> '👋')
         OR COALESCE(m.media_url, '') <> ''
       )
  )
  AND EXISTS (
    SELECT 1
      FROM public.group_chat_messages m
      JOIN public.group_chat_participants gcp
        ON gcp.session_id = p_session_id
       AND gcp.user_id = m.sender_id
       AND gcp.left_at IS NULL
       AND gcp.user_id IS DISTINCT FROM p_host_id
     WHERE m.session_id = p_session_id
       AND m.deleted_at IS NULL
       AND m.sender_id IS DISTINCT FROM p_host_id
       AND (
         (COALESCE(trim(m.body), '') <> '' AND left(trim(m.body), 1) <> '👋')
         OR COALESCE(m.media_url, '') <> ''
       )
  );
$$;

CREATE OR REPLACE FUNCTION public.group_chat_active_men_count(p_session_id uuid, p_host_id uuid)
RETURNS int
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT count(DISTINCT gcp.user_id)::int
    FROM public.group_chat_participants gcp
   WHERE gcp.session_id = p_session_id
     AND gcp.left_at IS NULL
     AND gcp.user_id IS DISTINCT FROM p_host_id;
$$;

-- Extend canonical bill_session_minute with group_chat @ ₹2 man / ₹1 host.
CREATE OR REPLACE FUNCTION public.bill_session_minute(
  p_session_id uuid,
  p_session_type text,
  p_minutes numeric,
  p_man_id uuid,
  p_woman_id uuid,
  p_man_count integer DEFAULT 1,
  p_minute_index integer DEFAULT NULL
)
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
  v_is_live_group_chat_host boolean := false;
BEGIN
  PERFORM set_config('row_security', 'off', true);

  IF p_session_type NOT IN ('chat','audio_call','video_call','private_group_call','group_chat') THEN
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

  IF p_session_type = 'group_chat' AND NOT public.group_chat_has_mutual_engagement(p_session_id, v_woman_id) THEN
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

  IF p_session_type = 'group_chat' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.group_chat_sessions gcs
      WHERE gcs.id = p_session_id
        AND gcs.host_id = v_woman_id
        AND gcs.ended_at IS NULL
    ) INTO v_is_live_group_chat_host;
    IF NOT COALESCE(v_is_live_group_chat_host, false) THEN
      RETURN jsonb_build_object('success',true,'skipped','not_live');
    END IF;
    IF public.group_chat_active_men_count(p_session_id, v_woman_id) < 1 THEN
      RETURN jsonb_build_object('success',true,'skipped','no_active_men');
    END IF;
  END IF;

  IF auth.role() <> 'service_role'
     AND v_caller IS DISTINCT FROM v_man_id
     AND NOT (p_session_type = 'private_group_call' AND v_caller IS NOT DISTINCT FROM v_woman_id AND v_is_live_group_host)
     AND NOT (p_session_type = 'group_chat' AND v_caller IS NOT DISTINCT FROM v_woman_id AND v_is_live_group_chat_host)
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
    WHEN 'group_chat' THEN 2.00
  END;
  v_woman_rate := CASE p_session_type
    WHEN 'chat' THEN (v_pricing->>'chat_woman_rate')::numeric
    WHEN 'audio_call' THEN (v_pricing->>'audio_woman_rate')::numeric
    WHEN 'video_call' THEN (v_pricing->>'video_woman_rate')::numeric
    WHEN 'private_group_call' THEN (v_pricing->>'group_woman_rate')::numeric
    WHEN 'group_chat' THEN 1.00
  END;

  v_charge := ROUND(v_man_rate * p_minutes, 2);
  v_earn   := ROUND(v_woman_rate * p_minutes * GREATEST(p_man_count,1), 2);
  v_label  := CASE p_session_type
    WHEN 'chat' THEN 'Chat'
    WHEN 'audio_call' THEN 'Audio Call'
    WHEN 'video_call' THEN 'Video Call'
    WHEN 'private_group_call' THEN 'Group Call'
    WHEN 'group_chat' THEN 'Group Chat'
  END;

  v_man_wallet_id := public.ensure_canonical_wallet(v_man_id, 'male');
  v_man_balance := public.canonical_wallet_balance(v_man_id);

  IF v_man_balance < v_charge THEN
    RETURN jsonb_build_object('success',false,'error','Insufficient balance','balance',v_man_balance,'required',v_charge,'insufficient',true);
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

  PERFORM public.sync_wallet_balance_from_ledger(v_man_id);
  PERFORM public.sync_wallet_balance_from_ledger(v_woman_id);

  RETURN jsonb_build_object(
    'success', true,
    'session_type', p_session_type,
    'charged', v_charge,
    'earned', v_earn,
    'man_rate', v_man_rate,
    'woman_rate', v_woman_rate,
    'minutes', p_minutes,
    'minute_index', v_minute_idx,
    'balance', v_man_balance_after
  );
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.bill_group_chat_minute(p_session_id uuid, p_man_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session RECORD;
  v_part RECORD;
  v_man_id uuid;
  v_host_id uuid;
  v_minute int;
  v_result jsonb;
  v_charged numeric;
  v_earned numeric;
BEGIN
  PERFORM set_config('row_security', 'off', true);

  v_man_id := public.resolve_wallet_user_id(p_man_id);

  SELECT * INTO v_session FROM public.group_chat_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_session.ended_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session not live', 'skipped', 'not_live');
  END IF;

  v_host_id := public.resolve_wallet_user_id(v_session.host_id);
  IF v_man_id IS NOT DISTINCT FROM v_host_id THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'host_not_billable');
  END IF;

  SELECT * INTO v_part FROM public.group_chat_participants
   WHERE session_id = p_session_id AND user_id = v_man_id AND left_at IS NULL
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'not active participant', 'skipped', 'man_left');
  END IF;

  v_minute := COALESCE(v_part.last_billed_minute, 0) + 1;

  v_result := public.bill_session_minute(
    p_session_id, 'group_chat', 1, v_man_id, v_host_id, 1, v_minute
  );

  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_result;
  END IF;

  IF v_result ? 'skipped' THEN
    RETURN v_result;
  END IF;

  IF COALESCE((v_result->>'duplicate_skipped')::boolean, false) THEN
    RETURN jsonb_build_object('success', true, 'duplicate', true);
  END IF;

  v_charged := COALESCE((v_result->>'charged')::numeric, 2.00);
  v_earned := COALESCE((v_result->>'earned')::numeric, 1.00);

  UPDATE public.group_chat_participants
     SET last_billed_minute = v_minute,
         total_billed = total_billed + v_charged,
         total_seconds = total_seconds + 60
   WHERE id = v_part.id;

  UPDATE public.group_chat_sessions
     SET total_men_minutes = total_men_minutes + 1,
         total_host_earning = total_host_earning + v_earned,
         total_platform_revenue = total_platform_revenue + GREATEST(v_charged - v_earned, 0)
   WHERE id = p_session_id;

  RETURN jsonb_build_object(
    'success', true,
    'minute', v_minute,
    'charged', v_charged,
    'earned', v_earned,
    'balance', v_result->'balance'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.group_chat_has_mutual_engagement(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.group_chat_active_men_count(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bill_group_chat_minute(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bill_session_minute(uuid, text, numeric, uuid, uuid, integer, integer) TO authenticated, service_role;
