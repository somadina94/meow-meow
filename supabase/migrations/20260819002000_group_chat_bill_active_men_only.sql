-- Group chat billing only for active men. Host (woman) is never billed as a man.
-- No men in the room (or all men left) → no debit/credit.

CREATE OR REPLACE FUNCTION public.bill_group_chat_minute(p_session_id uuid, p_man_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session RECORD;
  v_part RECORD;
  v_gender text;
  v_balance numeric;
  v_minute int;
  v_man_idem text;
  v_host_idem text;
  v_plat_idem text;
  v_man_charge numeric := 2.00;
  v_host_earn  numeric := 1.00;
  v_plat_rev   numeric := 1.00;
  v_platform_user uuid;
  v_active_men int;
BEGIN
  SELECT * INTO v_session FROM public.group_chat_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_session.ended_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session not live', 'skipped', 'not_live');
  END IF;

  IF p_man_id IS NOT DISTINCT FROM v_session.host_id THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'host_not_billable');
  END IF;

  SELECT lower(trim(gender)) INTO v_gender
    FROM public.profiles
   WHERE user_id = p_man_id OR id = p_man_id
   LIMIT 1;
  IF v_gender IS DISTINCT FROM 'male' THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'not_male');
  END IF;

  SELECT * INTO v_part FROM public.group_chat_participants
    WHERE session_id = p_session_id AND user_id = p_man_id AND left_at IS NULL
    LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'not active participant', 'skipped', 'man_left');
  END IF;

  SELECT count(*)::int INTO v_active_men
    FROM public.group_chat_participants gcp
    JOIN public.profiles p ON p.user_id = gcp.user_id OR p.id = gcp.user_id
   WHERE gcp.session_id = p_session_id
     AND gcp.left_at IS NULL
     AND gcp.user_id IS DISTINCT FROM v_session.host_id
     AND lower(trim(p.gender)) = 'male';

  IF COALESCE(v_active_men, 0) < 1 THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'no_active_men');
  END IF;

  IF public.has_role(p_man_id, 'admin') OR public.has_role(v_session.host_id, 'admin') THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'admin');
  END IF;

  v_minute := COALESCE(v_part.last_billed_minute, 0) + 1;
  v_man_idem  := 'groupchat:'||p_session_id::text||':'||p_man_id::text||':min:'||v_minute::text||':charge';
  v_host_idem := 'groupchat:'||p_session_id::text||':'||p_man_id::text||':min:'||v_minute::text||':host';
  v_plat_idem := 'groupchat:'||p_session_id::text||':'||p_man_id::text||':min:'||v_minute::text||':plat';

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_man_idem) THEN
    RETURN jsonb_build_object('success', true, 'duplicate', true);
  END IF;

  v_balance := public.canonical_wallet_balance(p_man_id);
  IF v_balance < v_man_charge THEN
    RETURN jsonb_build_object('success', false, 'insufficient', true, 'balance', v_balance);
  END IF;

  INSERT INTO public.wallet_transactions
    (user_id, type, transaction_type, amount, description, session_id, session_type, idempotency_key, status, rate_per_minute, billing_metadata)
  VALUES
    (p_man_id, 'debit', 'debit', v_man_charge,
     'Group chat: min '||v_minute||' @ ₹'||v_man_charge||'/min',
     p_session_id, 'group_chat', v_man_idem, 'completed', v_man_charge,
     jsonb_build_object('minute', v_minute, 'session', p_session_id, 'kind', 'group_chat_minute_charge'));

  INSERT INTO public.wallet_transactions
    (user_id, type, transaction_type, amount, description, session_id, session_type, idempotency_key, status, rate_per_minute, billing_metadata)
  VALUES
    (v_session.host_id, 'credit', 'credit', v_host_earn,
     'Group chat earning: min '||v_minute||' from male user',
     p_session_id, 'group_chat', v_host_idem, 'completed', v_host_earn,
     jsonb_build_object('minute', v_minute, 'session', p_session_id, 'kind', 'group_chat_host_earning', 'man_id', p_man_id));

  SELECT user_id INTO v_platform_user FROM public.user_roles WHERE role = 'admin' ORDER BY user_id LIMIT 1;
  IF v_platform_user IS NOT NULL AND v_platform_user IS DISTINCT FROM v_session.host_id THEN
    INSERT INTO public.wallet_transactions
      (user_id, type, transaction_type, amount, description, session_id, session_type, idempotency_key, status, rate_per_minute, billing_metadata)
    VALUES
      (v_platform_user, 'credit', 'credit', v_plat_rev,
       'Group chat platform revenue: min '||v_minute,
       p_session_id, 'group_chat', v_plat_idem, 'completed', v_plat_rev,
       jsonb_build_object('minute', v_minute, 'session', p_session_id, 'kind', 'group_chat_platform_revenue', 'man_id', p_man_id));
  END IF;

  UPDATE public.group_chat_participants
    SET last_billed_minute = v_minute,
        total_billed = total_billed + v_man_charge,
        total_seconds = total_seconds + 60
    WHERE id = v_part.id;
  UPDATE public.group_chat_sessions
    SET total_men_minutes = total_men_minutes + 1,
        total_host_earning = total_host_earning + v_host_earn,
        total_platform_revenue = total_platform_revenue + v_plat_rev
    WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true, 'minute', v_minute, 'balance', v_balance - v_man_charge);
END;
$$;

CREATE OR REPLACE FUNCTION public.bill_group_chat_leftover(p_session_id uuid, p_man_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session RECORD;
  v_part RECORD;
  v_gender text;
  v_elapsed numeric;
  v_remainder numeric;
BEGIN
  SELECT * INTO v_session FROM public.group_chat_sessions WHERE id = p_session_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'session not found');
  END IF;
  IF p_man_id IS NOT DISTINCT FROM v_session.host_id THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'host_not_billable');
  END IF;

  SELECT lower(trim(gender)) INTO v_gender
    FROM public.profiles
   WHERE user_id = p_man_id OR id = p_man_id
   LIMIT 1;
  IF v_gender IS DISTINCT FROM 'male' THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'not_male');
  END IF;

  SELECT * INTO v_part
    FROM public.group_chat_participants
   WHERE session_id = p_session_id AND user_id = p_man_id AND left_at IS NULL
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'not active participant');
  END IF;

  v_elapsed := EXTRACT(EPOCH FROM (now() - v_part.joined_at));
  IF v_elapsed < 1 THEN
    RETURN jsonb_build_object('success', true, 'skipped', true);
  END IF;

  v_remainder := v_elapsed - COALESCE(v_part.last_billed_minute, 0) * 60;
  IF v_remainder < 1 THEN
    RETURN jsonb_build_object('success', true, 'skipped', true);
  END IF;

  RETURN public.bill_group_chat_minute(p_session_id, p_man_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.group_chat_end_live(p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_session RECORD;
  v_man uuid;
BEGIN
  SELECT * INTO v_session FROM public.group_chat_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','not found'); END IF;
  IF v_user IS NULL THEN RETURN jsonb_build_object('success',false,'error','unauthenticated'); END IF;
  IF v_session.host_id IS DISTINCT FROM v_user AND NOT public.has_role(v_user,'admin') THEN
    RETURN jsonb_build_object('success',false,'error','not host');
  END IF;

  BEGIN
    FOR v_man IN
      SELECT DISTINCT gcp.user_id
        FROM public.group_chat_participants gcp
        JOIN public.profiles p ON p.user_id = gcp.user_id OR p.id = gcp.user_id
       WHERE gcp.session_id = p_session_id
         AND gcp.left_at IS NULL
         AND gcp.user_id IS DISTINCT FROM v_session.host_id
         AND lower(trim(p.gender)) = 'male'
    LOOP
      BEGIN
        PERFORM public.bill_group_chat_leftover(p_session_id, v_man);
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  UPDATE public.group_chat_sessions SET ended_at = COALESCE(ended_at, now()) WHERE id = p_session_id;
  UPDATE public.group_chat_participants SET left_at = now() WHERE session_id = p_session_id AND left_at IS NULL;
  UPDATE public.group_chat_rooms
    SET status='offline', current_host_id=NULL, current_session_id=NULL, current_participant_count=0, updated_at=now()
    WHERE id = v_session.room_id;
  RETURN jsonb_build_object('success',true);
END $$;

GRANT EXECUTE ON FUNCTION public.bill_group_chat_minute(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bill_group_chat_leftover(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.group_chat_end_live(uuid) TO authenticated, service_role;
