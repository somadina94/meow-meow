-- Fix join_group_atomic: validate liveness via group_active_hosts (source of truth)
-- instead of private_groups.is_live, which can race or be stale, blocking men from
-- joining and producing billing rows.

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
  v_active_host_count INT;
BEGIN
  -- Source of truth for "is live": at least one active host with fresh heartbeat.
  SELECT COUNT(*), MIN(host_id)
    INTO v_active_host_count, v_host_id
  FROM public.group_active_hosts
  WHERE group_id = p_group_id
    AND is_active = true
    AND last_heartbeat_at > now() - interval '2 minutes';

  IF v_active_host_count = 0 OR v_host_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No live host in this group right now');
  END IF;

  -- Pick the oldest active host to attach this man to (stable selection).
  SELECT host_id INTO v_host_id
  FROM public.group_active_hosts
  WHERE group_id = p_group_id
    AND is_active = true
    AND last_heartbeat_at > now() - interval '2 minutes'
  ORDER BY started_at ASC
  LIMIT 1;

  -- Atomic increment with capacity guard on private_groups.
  UPDATE public.private_groups
  SET participant_count = participant_count + 1,
      is_live = true,                                  -- self-heal stale flag
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

  -- Upsert membership AND tag the host atomically — billing depends on this
  INSERT INTO public.group_memberships (group_id, user_id, has_access, gift_amount_paid, joined_host_id, joined_at)
  VALUES (p_group_id, p_user_id, true, 0, v_host_id, now())
  ON CONFLICT (group_id, user_id)
  DO UPDATE SET
    has_access = true,
    joined_at = now(),
    joined_host_id = EXCLUDED.joined_host_id;

  RETURN jsonb_build_object(
    'success', true,
    'participant_count', v_new_count,
    'host_id', v_host_id
  );
END;
$function$;