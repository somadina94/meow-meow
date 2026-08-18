-- Group gifts were resolving the woman from private_groups.current_host_id,
-- which stays stuck on the first host (COALESCE) and can be NULL after the
-- language-host rewrite. Credit the host this man actually joined instead.

DROP FUNCTION IF EXISTS public.bill_group_gift_or_tip(uuid, uuid, numeric, text, text, text, uuid);
DROP FUNCTION IF EXISTS public.bill_group_gift_or_tip(uuid, uuid, numeric, text, text, text);

CREATE OR REPLACE FUNCTION public.bill_group_gift_or_tip(
  p_group_id uuid,
  p_man_id uuid,
  p_amount numeric,
  p_type text,
  p_description text DEFAULT NULL::text,
  p_reference_id text DEFAULT NULL::text,
  p_host_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_group   RECORD;
  v_host_id uuid;
  v_man_id  uuid := public.resolve_wallet_user_id(p_man_id);
  v_ref     text;
  v_result  jsonb;
  v_live    boolean := false;
BEGIN
  IF p_type NOT IN ('gift','tip') THEN
    RETURN jsonb_build_object('success',false,'error','type must be gift or tip');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','amount must be > 0');
  END IF;
  IF v_man_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','Missing man id');
  END IF;

  IF auth.uid() IS NOT NULL
     AND auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_man_id
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RETURN jsonb_build_object('success',false,'error','Not allowed to bill for this user');
  END IF;

  SELECT id, name, is_live, is_active, current_host_id
    INTO v_group
  FROM public.private_groups
  WHERE id = p_group_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','Group not found');
  END IF;
  IF NOT COALESCE(v_group.is_active, false) THEN
    RETURN jsonb_build_object('success',false,'error','Group not live');
  END IF;

  -- 1) Host the client named (the woman on screen)
  IF p_host_id IS NOT NULL THEN
    SELECT host_id INTO v_host_id
    FROM public.group_active_hosts
    WHERE group_id = p_group_id
      AND host_id = public.resolve_wallet_user_id(p_host_id)
      AND is_active = true
      AND last_heartbeat_at > now() - interval '2 minutes';
  END IF;

  -- 2) Host this man actually joined
  IF v_host_id IS NULL THEN
    SELECT public.resolve_wallet_user_id(gm.joined_host_id) INTO v_host_id
    FROM public.group_memberships gm
    WHERE gm.group_id = p_group_id
      AND gm.has_access = true
      AND gm.user_id IN (
        v_man_id,
        p_man_id,
        (SELECT p.user_id FROM public.profiles p WHERE p.id = p_man_id LIMIT 1),
        (SELECT p.id FROM public.profiles p WHERE p.user_id = v_man_id LIMIT 1)
      )
    ORDER BY gm.joined_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  -- 3) Any currently live host in this group
  IF v_host_id IS NULL THEN
    SELECT host_id INTO v_host_id
    FROM public.group_active_hosts
    WHERE group_id = p_group_id
      AND is_active = true
      AND last_heartbeat_at > now() - interval '2 minutes'
    ORDER BY started_at DESC
    LIMIT 1;
  END IF;

  -- 4) Legacy column (may be the original host, not the current one)
  IF v_host_id IS NULL THEN
    v_host_id := v_group.current_host_id;
  END IF;

  IF v_host_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','No active host');
  END IF;

  v_host_id := public.resolve_wallet_user_id(v_host_id);

  SELECT EXISTS (
    SELECT 1 FROM public.group_active_hosts
    WHERE group_id = p_group_id
      AND host_id = v_host_id
      AND is_active = true
      AND last_heartbeat_at > now() - interval '2 minutes'
  ) INTO v_live;

  IF NOT v_live AND NOT COALESCE(v_group.is_live, false) THEN
    RETURN jsonb_build_object('success',false,'error','Group not live');
  END IF;

  IF NOT public.has_role(v_man_id, 'admin') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.group_memberships gm
      WHERE gm.group_id = p_group_id
        AND gm.has_access = true
        AND gm.user_id IN (
          v_man_id,
          p_man_id,
          (SELECT p.user_id FROM public.profiles p WHERE p.id = p_man_id LIMIT 1),
          (SELECT p.id FROM public.profiles p WHERE p.user_id = v_man_id LIMIT 1)
        )
    ) THEN
      RETURN jsonb_build_object('success',false,'error','Not an active group member');
    END IF;
  END IF;

  v_ref := COALESCE(NULLIF(p_reference_id, ''), 'grp:' || p_group_id::text || ':' || gen_random_uuid()::text);

  v_result := public.bill_gift_or_tip(
    p_man_id       => v_man_id,
    p_woman_id     => v_host_id,
    p_amount       => p_amount,
    p_type         => p_type,
    p_description  => COALESCE(p_description, initcap(p_type) || ' in group: ' || v_group.name),
    p_reference_id => v_ref
  );

  IF (v_result->>'success')::boolean = true
     AND COALESCE((v_result->>'duplicate_skipped')::boolean, false) = false THEN
    UPDATE public.wallet_transactions
       SET session_id = p_group_id
     WHERE reference_id = v_ref
       AND session_id IS NULL;
  END IF;

  RETURN v_result || jsonb_build_object('group_id', p_group_id, 'host_id', v_host_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.bill_group_gift_or_tip(uuid, uuid, numeric, text, text, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bill_group_gift_or_tip(uuid, uuid, numeric, text, text, text, uuid) TO authenticated, service_role;
