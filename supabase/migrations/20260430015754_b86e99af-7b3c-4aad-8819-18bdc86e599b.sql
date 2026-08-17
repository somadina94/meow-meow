-- Heartbeat refresh RPC: host calls this every ~30s while live
CREATE OR REPLACE FUNCTION public.update_host_heartbeat(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_updated integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  UPDATE public.group_active_hosts
  SET last_heartbeat_at = now()
  WHERE group_id = p_group_id
    AND host_id = v_user_id
    AND is_active = true;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host session');
  END IF;

  -- Touch the group too so cleanup's `updated_at` window slides forward
  UPDATE public.private_groups
  SET updated_at = now()
  WHERE id = p_group_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_host_heartbeat(uuid) TO authenticated;

-- Stale host sweeper: marks host inactive after 90s of silence
-- and clears the private_groups row if no live hosts remain.
CREATE OR REPLACE FUNCTION public.sweep_stale_group_hosts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_stale_ids uuid[];
  v_affected_groups uuid[];
  v_group_id uuid;
  v_remaining integer;
  v_next_host record;
BEGIN
  -- 1) Find stale active hosts (no heartbeat for > 90s)
  SELECT array_agg(id), array_agg(DISTINCT group_id)
  INTO v_stale_ids, v_affected_groups
  FROM public.group_active_hosts
  WHERE is_active = true
    AND last_heartbeat_at < now() - interval '90 seconds';

  IF v_stale_ids IS NULL OR array_length(v_stale_ids, 1) = 0 THEN
    RETURN jsonb_build_object('success', true, 'swept', 0);
  END IF;

  -- 2) Mark them inactive
  UPDATE public.group_active_hosts
  SET is_active = false
  WHERE id = ANY(v_stale_ids);

  -- 3) For each affected group, recompute legacy current_host_*
  FOREACH v_group_id IN ARRAY v_affected_groups LOOP
    SELECT COUNT(*) INTO v_remaining
    FROM public.group_active_hosts
    WHERE group_id = v_group_id AND is_active = true;

    IF v_remaining = 0 THEN
      UPDATE public.private_groups
      SET is_live = false,
          stream_id = NULL,
          current_host_id = NULL,
          current_host_name = NULL,
          participant_count = 0,
          updated_at = now()
      WHERE id = v_group_id;

      -- Detach memberships tied to swept hosts
      UPDATE public.group_memberships
      SET joined_host_id = NULL
      WHERE group_id = v_group_id;
    ELSE
      SELECT host_id, host_name INTO v_next_host
      FROM public.group_active_hosts
      WHERE group_id = v_group_id AND is_active = true
      ORDER BY started_at ASC
      LIMIT 1;

      UPDATE public.private_groups
      SET current_host_id = v_next_host.host_id,
          current_host_name = v_next_host.host_name,
          updated_at = now()
      WHERE id = v_group_id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'swept', array_length(v_stale_ids, 1),
    'groups_affected', array_length(v_affected_groups, 1)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sweep_stale_group_hosts() TO authenticated, service_role;

-- Schedule the sweeper to run every minute via pg_cron (idempotent)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('sweep-stale-group-hosts')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'sweep-stale-group-hosts');

    PERFORM cron.schedule(
      'sweep-stale-group-hosts',
      '* * * * *',
      $cron$ SELECT public.sweep_stale_group_hosts(); $cron$
    );
  END IF;
END $$;
