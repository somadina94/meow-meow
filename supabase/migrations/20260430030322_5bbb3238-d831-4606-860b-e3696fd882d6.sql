-- ============================================================================
-- Bill first minute of private group call inside join_group_atomic
-- ============================================================================
-- Charges man ₹4 / credits host woman ₹1 the moment join succeeds.
-- Idempotent via bill_session_minute (minute_index=0) — safe with client tick.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.join_group_atomic(
  p_group_id uuid,
  p_user_id uuid,
  p_max_participants integer DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_new_count INT;
  v_host_id UUID;
  v_stream_id TEXT;
  v_joiner_gender TEXT;
  v_host_gender TEXT;
  v_bill_result JSONB;
BEGIN
  -- Source of truth for "is live": pick the oldest active host with fresh heartbeat.
  SELECT host_id, stream_id INTO v_host_id, v_stream_id
  FROM public.group_active_hosts
  WHERE group_id = p_group_id
    AND is_active = true
    AND last_heartbeat_at > now() - interval '2 minutes'
  ORDER BY started_at ASC
  LIMIT 1;

  IF v_host_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No live host in this group right now');
  END IF;

  -- Resolve genders (ledger billing only fires for man -> woman host).
  SELECT gender INTO v_joiner_gender FROM public.profiles WHERE user_id = p_user_id;
  SELECT gender INTO v_host_gender   FROM public.profiles WHERE user_id = v_host_id;

  -- Pre-flight balance check for men so we don't increment counters for a join we're about to reject.
  IF v_joiner_gender = 'male' AND v_host_gender = 'female' AND v_stream_id IS NOT NULL THEN
    IF NOT public.has_role(p_user_id, 'admin') THEN
      DECLARE
        v_required numeric;
        v_balance  numeric;
      BEGIN
        v_required := (public.get_unified_pricing()->>'group_man_rate')::numeric;
        SELECT balance INTO v_balance FROM public.wallets WHERE user_id = public.resolve_wallet_user_id(p_user_id);
        IF COALESCE(v_balance, 0) < v_required THEN
          RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'balance', COALESCE(v_balance, 0),
            'required', v_required
          );
        END IF;
      END;
    END IF;
  END IF;

  -- Atomic increment with capacity guard on private_groups.
  UPDATE public.private_groups
  SET participant_count = participant_count + 1,
      is_live = true,
      current_host_id = COALESCE(current_host_id, v_host_id),
      updated_at = now()
  WHERE id = p_group_id
    AND is_active = true
    AND participant_count < p_max_participants
  RETURNING participant_count INTO v_new_count;

  IF v_new_count IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group is full or inactive');
  END IF;

  -- Mirror count onto the host row so UI counters stay accurate.
  UPDATE public.group_active_hosts
  SET participant_count = participant_count + 1
  WHERE group_id = p_group_id
    AND host_id = v_host_id
    AND is_active = true;

  -- Upsert membership AND tag the host atomically — billing depends on this.
  INSERT INTO public.group_memberships (group_id, user_id, has_access, gift_amount_paid, joined_host_id, joined_at)
  VALUES (p_group_id, p_user_id, true, 0, v_host_id, now())
  ON CONFLICT (group_id, user_id)
  DO UPDATE SET
    has_access = true,
    joined_at = now(),
    joined_host_id = EXCLUDED.joined_host_id;

  -- ── First-minute billing: man -> woman host ────────────────────────────
  -- Idempotent (minute_index=0) so client-side billing tick won't double-charge.
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
      -- Don't fail the join over a billing error; log via NOTICE.
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
$function$;

GRANT EXECUTE ON FUNCTION public.join_group_atomic(uuid, uuid, integer) TO authenticated, service_role;