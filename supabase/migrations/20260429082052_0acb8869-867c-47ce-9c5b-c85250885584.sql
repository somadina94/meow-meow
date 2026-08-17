
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
BEGIN
  -- Atomic increment with guard, capture current host atomically
  UPDATE private_groups
  SET participant_count = participant_count + 1,
      updated_at = now()
  WHERE id = p_group_id
    AND participant_count < p_max_participants
    AND is_active = true
    AND is_live = true
    AND current_host_id IS NOT NULL
  RETURNING participant_count, current_host_id INTO v_new_count, v_host_id;

  IF v_new_count IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group is full, not live, or has no active host');
  END IF;

  -- Upsert membership AND tag the host atomically — billing depends on this
  INSERT INTO group_memberships (group_id, user_id, has_access, gift_amount_paid, joined_host_id, joined_at)
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
