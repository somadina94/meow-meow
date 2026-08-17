
CREATE OR REPLACE FUNCTION public.bill_group_gift_or_tip(
  p_group_id     uuid,
  p_man_id       uuid,
  p_amount       numeric,
  p_type         text,
  p_description  text DEFAULT NULL,
  p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_group   RECORD;
  v_host_id uuid;
  v_man_id  uuid := public.resolve_wallet_user_id(p_man_id);
  v_ref     text;
  v_result  jsonb;
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
  IF NOT COALESCE(v_group.is_live,false) OR NOT COALESCE(v_group.is_active,false) THEN
    RETURN jsonb_build_object('success',false,'error','Group not live');
  END IF;

  v_host_id := v_group.current_host_id;
  IF v_host_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','No active host');
  END IF;

  IF NOT public.has_role(v_man_id, 'admin') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.group_memberships
      WHERE group_id = p_group_id
        AND user_id  = v_man_id
        AND has_access = true
    ) THEN
      RETURN jsonb_build_object('success',false,'error','Not an active group member');
    END IF;
  END IF;

  v_ref := COALESCE(NULLIF(p_reference_id, ''),
                    'grp:' || p_group_id::text || ':' || gen_random_uuid()::text);

  v_result := public.bill_gift_or_tip(
    p_man_id       => v_man_id,
    p_woman_id     => v_host_id,
    p_amount       => p_amount,
    p_type         => p_type,
    p_description  => COALESCE(p_description,
                       initcap(p_type) || ' in group: ' || v_group.name),
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
END;
$function$;

REVOKE ALL ON FUNCTION public.bill_group_gift_or_tip(uuid,uuid,numeric,text,text,text) FROM public;
GRANT EXECUTE ON FUNCTION public.bill_group_gift_or_tip(uuid,uuid,numeric,text,text,text) TO authenticated, service_role;
