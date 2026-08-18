-- Billing starts only after both parties have actually engaged.
-- Chat: both have sent a real message in this session.
-- Audio/video: the callee answered (status left ringing). Missed/declined calls never bill.

ALTER TABLE public.video_call_sessions
  ALTER COLUMN started_at DROP DEFAULT;
ALTER TABLE public.video_call_sessions
  ALTER COLUMN started_at DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.chat_session_has_mutual_replies(p_session_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_chat_id text;
  v_man_id uuid;
  v_woman_id uuid;
  v_since timestamptz;
BEGIN
  SELECT s.chat_id, s.man_user_id, s.woman_user_id, COALESCE(s.started_at, s.created_at)
    INTO v_chat_id, v_man_id, v_woman_id, v_since
  FROM public.active_chat_sessions s
  WHERE s.id = p_session_id;

  IF v_chat_id IS NULL OR v_man_id IS NULL OR v_woman_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.chat_messages m
    WHERE m.chat_id = v_chat_id
      AND m.sender_id = v_man_id
      AND m.created_at >= v_since
      AND COALESCE(m.deleted_for_everyone, false) = false
  ) AND EXISTS (
    SELECT 1 FROM public.chat_messages w
    WHERE w.chat_id = v_chat_id
      AND w.sender_id = v_woman_id
      AND w.created_at >= v_since
      AND COALESCE(w.deleted_for_everyone, false) = false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.call_session_was_answered(p_session_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.video_call_sessions v
    WHERE v.id = p_session_id
      AND v.started_at IS NOT NULL
      AND LOWER(COALESCE(v.status, '')) IN ('active', 'answered', 'connected', 'ongoing', 'completed', 'ended')
  );
$$;

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

GRANT EXECUTE ON FUNCTION public.chat_session_has_mutual_replies(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.call_session_was_answered(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bill_session_minute(uuid, text, numeric, uuid, uuid, integer, integer) TO authenticated, service_role;

-- First minute only after the callee answers (status becomes active).
DROP TRIGGER IF EXISTS trg_video_call_first_minute_billing ON public.video_call_sessions;

CREATE OR REPLACE FUNCTION public.trg_call_first_minute_billing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session_type text;
BEGIN
  IF NEW.status IS NULL OR LOWER(NEW.status) NOT IN ('active','answered','connected','ongoing') THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status IS NOT NULL
     AND LOWER(OLD.status) IN ('active','answered','connected','ongoing') THEN
    RETURN NEW;
  END IF;
  IF NEW.man_user_id IS NULL OR NEW.woman_user_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.started_at IS NULL THEN
    RETURN NEW;
  END IF;

  v_session_type := CASE LOWER(COALESCE(NEW.call_type, 'video'))
    WHEN 'audio' THEN 'audio_call'
    WHEN 'video' THEN 'video_call'
    ELSE 'video_call'
  END;

  BEGIN
    PERFORM public.bill_session_minute(
      p_session_id   => NEW.id,
      p_session_type => v_session_type,
      p_minutes      => 1.0,
      p_man_id       => NEW.man_user_id,
      p_woman_id     => NEW.woman_user_id,
      p_man_count    => 1,
      p_minute_index => 0
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'call first-minute billing failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_video_call_first_minute_billing
AFTER UPDATE OF status ON public.video_call_sessions
FOR EACH ROW
EXECUTE FUNCTION public.trg_call_first_minute_billing();

-- End-of-call settlement only for answered calls. Missed/declined never bill.
CREATE OR REPLACE FUNCTION public.trg_video_call_ended()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_minutes numeric;
  v_session_type text;
  v_result jsonb;
  v_already_billed boolean;
  v_was_answered boolean;
BEGIN
  IF NEW.status IN ('ended', 'completed') AND OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM public.revert_busy_to_online(NEW.man_user_id);
    PERFORM public.revert_busy_to_online(NEW.woman_user_id);

    v_was_answered := LOWER(COALESCE(OLD.status, '')) IN ('active','answered','connected','ongoing')
                      AND NEW.started_at IS NOT NULL;

    IF v_was_answered
       AND NEW.ended_at IS NOT NULL
       AND EXTRACT(EPOCH FROM (NEW.ended_at - NEW.started_at)) > 0
    THEN
      SELECT EXISTS (
        SELECT 1 FROM public.wallet_transactions
         WHERE session_id = NEW.id
           AND transaction_type IN ('session_charge','session_earning')
        UNION ALL
        SELECT 1 FROM public.wallet_transactions_archive
         WHERE session_id = NEW.id
           AND transaction_type IN ('session_charge','session_earning')
      ) INTO v_already_billed;

      IF NOT v_already_billed THEN
        v_minutes := ROUND(EXTRACT(EPOCH FROM (NEW.ended_at - NEW.started_at)) / 60.0, 4);
        v_session_type := CASE COALESCE(NEW.call_type, 'video')
                            WHEN 'audio' THEN 'audio_call'
                            WHEN 'video' THEN 'video_call'
                            ELSE 'video_call'
                          END;

        v_result := public.bill_session_minute(
          p_session_id   => NEW.id,
          p_session_type => v_session_type,
          p_minutes      => v_minutes,
          p_man_id       => NEW.man_user_id,
          p_woman_id     => NEW.woman_user_id,
          p_man_count    => 1,
          p_minute_index => NULL
        );

        IF (v_result->>'success')::boolean IS TRUE AND COALESCE(v_result->>'skipped','') = '' THEN
          UPDATE public.video_call_sessions
             SET total_minutes = v_minutes,
                 total_earned  = COALESCE((v_result->>'earned')::numeric, 0)
           WHERE id = NEW.id;
        END IF;
      END IF;
    END IF;
  ELSIF NEW.status IN ('declined', 'missed', 'cancelled') AND OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM public.revert_busy_to_online(NEW.man_user_id);
    PERFORM public.revert_busy_to_online(NEW.woman_user_id);
  END IF;
  RETURN NEW;
END;
$function$;
