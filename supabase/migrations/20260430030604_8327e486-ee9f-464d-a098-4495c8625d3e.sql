CREATE OR REPLACE FUNCTION public.update_host_heartbeat(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_updated integer;
  v_stream_id text;
  v_started_at timestamptz;
  v_elapsed_sec integer;
  v_minute_idx integer;
  v_host_gender text;
  r RECORD;
  v_billed integer := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Refresh heartbeat and grab session metadata in one shot
  UPDATE public.group_active_hosts
  SET last_heartbeat_at = now()
  WHERE group_id = p_group_id
    AND host_id = v_user_id
    AND is_active = true
  RETURNING stream_id, started_at INTO v_stream_id, v_started_at;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host session');
  END IF;

  UPDATE public.private_groups SET updated_at = now() WHERE id = p_group_id;

  -- ── Server-side per-minute billing ───────────────────────────────────
  -- Only bill if we have a stream_id and the host is female (men don't host paid groups).
  SELECT gender INTO v_host_gender FROM public.profiles WHERE user_id = v_user_id;

  IF v_stream_id IS NOT NULL AND v_host_gender = 'female' AND v_started_at IS NOT NULL THEN
    v_elapsed_sec := GREATEST(0, EXTRACT(EPOCH FROM (now() - v_started_at))::integer);
    v_minute_idx  := v_elapsed_sec / 60;

    -- Skip minute 0 (already billed by join_group_atomic on each man's join)
    IF v_minute_idx >= 1 THEN
      -- Every active man in the room, joined via this host
      FOR r IN
        SELECT gm.user_id AS man_id
        FROM public.group_memberships gm
        JOIN public.profiles p ON p.user_id = gm.user_id
        WHERE gm.group_id = p_group_id
          AND gm.has_access = true
          AND gm.joined_host_id = v_user_id
          AND p.gender = 'male'
      LOOP
        BEGIN
          PERFORM public.bill_session_minute(
            p_session_id   => v_stream_id::uuid,
            p_session_type => 'private_group_call',
            p_minutes      => 1.0,
            p_man_id       => r.man_id,
            p_woman_id     => v_user_id,
            p_man_count    => 1,
            p_minute_index => v_minute_idx
          );
          v_billed := v_billed + 1;
        EXCEPTION WHEN OTHERS THEN
          RAISE NOTICE 'heartbeat billing failed for man %: %', r.man_id, SQLERRM;
        END;
      END LOOP;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'minute_index', v_minute_idx,
    'billed_men', v_billed
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.update_host_heartbeat(uuid) TO authenticated, service_role;