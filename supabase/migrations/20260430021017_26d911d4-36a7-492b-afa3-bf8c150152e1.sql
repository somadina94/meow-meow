CREATE OR REPLACE FUNCTION public.start_host_session(
  p_group_id uuid,
  p_host_name text,
  p_host_photo text DEFAULT NULL::text,
  p_host_language text DEFAULT NULL::text,
  p_stream_id text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_active_hosts integer;
  v_other_active_group uuid;
  v_same_group_active boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Clear stale host rows for this user before enforcing single-host rule.
  UPDATE public.group_active_hosts
  SET is_active = false
  WHERE host_id = v_user_id
    AND is_active = true
    AND last_heartbeat_at < now() - interval '90 seconds';

  -- Lock requested group row.
  PERFORM 1 FROM public.private_groups WHERE id = p_group_id FOR UPDATE;

  -- If the same user is already active in this same group, allow idempotent reuse.
  SELECT EXISTS (
    SELECT 1
    FROM public.group_active_hosts
    WHERE host_id = v_user_id
      AND group_id = p_group_id
      AND is_active = true
  ) INTO v_same_group_active;

  -- Only block if user is active in a different group.
  SELECT group_id INTO v_other_active_group
  FROM public.group_active_hosts
  WHERE host_id = v_user_id
    AND group_id <> p_group_id
    AND is_active = true
  ORDER BY started_at DESC
  LIMIT 1;

  IF v_other_active_group IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'You are already hosting another group. Stop that first.', 'group_id', v_other_active_group);
  END IF;

  -- Check 3-host cap, excluding this same user's existing row in this group.
  SELECT COUNT(*) INTO v_active_hosts
  FROM public.group_active_hosts
  WHERE group_id = p_group_id
    AND is_active = true
    AND host_id <> v_user_id;

  IF v_active_hosts >= 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'This group already has 3 active hosts. Try another.');
  END IF;

  INSERT INTO public.group_active_hosts (
    group_id, host_id, host_name, host_photo, host_language, stream_id, is_active, started_at, last_heartbeat_at
  ) VALUES (
    p_group_id, v_user_id, p_host_name, p_host_photo, p_host_language, p_stream_id, true, now(), now()
  )
  ON CONFLICT (group_id, host_id) DO UPDATE SET
    host_name = EXCLUDED.host_name,
    host_photo = COALESCE(EXCLUDED.host_photo, public.group_active_hosts.host_photo),
    host_language = COALESCE(EXCLUDED.host_language, public.group_active_hosts.host_language),
    stream_id = COALESCE(EXCLUDED.stream_id, public.group_active_hosts.stream_id),
    is_active = true,
    started_at = CASE WHEN public.group_active_hosts.is_active THEN public.group_active_hosts.started_at ELSE now() END,
    last_heartbeat_at = now();

  UPDATE public.private_groups
  SET is_live = true,
      updated_at = now(),
      current_host_id = COALESCE(current_host_id, v_user_id),
      current_host_name = COALESCE(current_host_name, p_host_name)
  WHERE id = p_group_id;

  RETURN jsonb_build_object(
    'success', true,
    'active_hosts', v_active_hosts + 1,
    'reused', v_same_group_active
  );
END;
$function$;