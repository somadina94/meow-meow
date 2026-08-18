-- Group calls: visible to all men. Join any live host (no profile-language gate).
-- Hosts are still one-per-language so men pick a language room from the full list.

CREATE OR REPLACE FUNCTION public.join_group_atomic(
  p_group_id uuid,
  p_user_id uuid,
  p_max_participants integer DEFAULT 15,
  p_host_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_new_count INT;
  v_host_id UUID;
  v_stream_id TEXT;
  v_host_language TEXT;
  v_joiner_gender TEXT;
  v_host_gender TEXT;
  v_bill_result JSONB;
  v_max INT := LEAST(COALESCE(p_max_participants, 15), 15);
BEGIN
  IF p_host_id IS NOT NULL THEN
    SELECT host_id, stream_id, host_language INTO v_host_id, v_stream_id, v_host_language
    FROM public.group_active_hosts
    WHERE group_id = p_group_id
      AND host_id = p_host_id
      AND is_active = true
      AND last_heartbeat_at > now() - interval '2 minutes';
  ELSE
    SELECT host_id, stream_id, host_language INTO v_host_id, v_stream_id, v_host_language
    FROM public.group_active_hosts
    WHERE group_id = p_group_id
      AND is_active = true
      AND last_heartbeat_at > now() - interval '2 minutes'
    ORDER BY started_at ASC
    LIMIT 1;
  END IF;

  IF v_host_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No live host in this group right now');
  END IF;

  SELECT gender INTO v_joiner_gender FROM public.profiles WHERE user_id = p_user_id;
  SELECT gender INTO v_host_gender   FROM public.profiles WHERE user_id = v_host_id;

  IF v_joiner_gender = 'male' AND v_host_gender = 'female' AND v_stream_id IS NOT NULL THEN
    IF NOT public.has_role(p_user_id, 'admin') THEN
      DECLARE
        v_required numeric;
        v_balance  numeric;
        v_resolved uuid := public.resolve_wallet_user_id(p_user_id);
      BEGIN
        v_required := (public.get_unified_pricing()->>'group_man_rate')::numeric;
        SELECT GREATEST(COALESCE(SUM(CASE
                 WHEN u.type='credit' THEN u.amount
                 WHEN u.type='debit'  THEN -u.amount
                 ELSE 0 END), 0), 0)
          INTO v_balance
        FROM (
          SELECT type, amount, status FROM public.wallet_transactions WHERE user_id = v_resolved
          UNION ALL
          SELECT type, amount, status FROM public.wallet_transactions_archive WHERE user_id = v_resolved
        ) u
        WHERE u.status='completed';

        IF COALESCE(v_balance, 0) < v_required THEN
          RETURN jsonb_build_object(
            'success', false, 'error', 'Insufficient balance',
            'balance', COALESCE(v_balance, 0), 'required', v_required
          );
        END IF;
      END;
    END IF;
  END IF;

  UPDATE public.private_groups
  SET participant_count = participant_count + 1,
      is_live = true,
      current_host_id = COALESCE(current_host_id, v_host_id),
      updated_at = now()
  WHERE id = p_group_id AND is_active = true AND participant_count < v_max
  RETURNING participant_count INTO v_new_count;

  IF v_new_count IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group is full or inactive');
  END IF;

  UPDATE public.group_active_hosts
  SET participant_count = participant_count + 1
  WHERE group_id = p_group_id AND host_id = v_host_id AND is_active = true;

  INSERT INTO public.group_memberships (group_id, user_id, has_access, gift_amount_paid, joined_host_id, joined_at)
  VALUES (p_group_id, p_user_id, true, 0, v_host_id, now())
  ON CONFLICT (group_id, user_id) DO UPDATE SET
    has_access = true, joined_at = now(), joined_host_id = EXCLUDED.joined_host_id;

  IF v_joiner_gender = 'male' AND v_host_gender = 'female' AND v_stream_id IS NOT NULL THEN
    BEGIN
      v_bill_result := public.bill_session_minute(
        p_session_id   => v_stream_id::uuid,
        p_session_type => 'private_group_call',
        p_minutes      => 1.0,
        p_man_id       => p_user_id,
        p_woman_id     => v_host_id,
        p_man_count    => 1,
        p_minute_index => 0
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'join_group_atomic billing failed: %', SQLERRM;
      v_bill_result := jsonb_build_object('success', false, 'error', SQLERRM);
    END;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'participant_count', v_new_count,
    'host_id', v_host_id,
    'billing', v_bill_result
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_group_atomic(uuid, uuid, integer, uuid) TO authenticated, service_role;
