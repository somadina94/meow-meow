-- Group chat billing: write canonical ledger rows (wallet_id + balance_after)
-- and count active men from participants (only men can join via group_chat_join).

CREATE OR REPLACE FUNCTION public.group_chat_active_men_count(p_session_id uuid, p_host_id uuid)
RETURNS int
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT count(DISTINCT gcp.user_id)::int
    FROM public.group_chat_participants gcp
   WHERE gcp.session_id = p_session_id
     AND gcp.left_at IS NULL
     AND gcp.user_id IS DISTINCT FROM p_host_id;
$$;

CREATE OR REPLACE FUNCTION public.bill_group_chat_minute(p_session_id uuid, p_man_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session RECORD;
  v_part RECORD;
  v_man_id uuid;
  v_host_id uuid;
  v_caller uuid := auth.uid();
  v_balance numeric;
  v_host_balance numeric;
  v_man_balance_after numeric;
  v_host_balance_after numeric;
  v_minute int;
  v_man_idem text;
  v_host_idem text;
  v_plat_idem text;
  v_man_charge numeric := 2.00;
  v_host_earn  numeric := 1.00;
  v_plat_rev   numeric := 1.00;
  v_platform_user uuid;
  v_active_men int;
  v_man_wallet_id uuid;
  v_host_wallet_id uuid;
BEGIN
  v_man_id := public.resolve_wallet_user_id(p_man_id);

  SELECT * INTO v_session FROM public.group_chat_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_session.ended_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session not live', 'skipped', 'not_live');
  END IF;

  v_host_id := public.resolve_wallet_user_id(v_session.host_id);

  IF v_man_id IS NOT DISTINCT FROM v_host_id THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'host_not_billable');
  END IF;

  IF auth.role() <> 'service_role'
     AND v_caller IS DISTINCT FROM v_man_id
     AND v_caller IS DISTINCT FROM v_host_id
     AND NOT public.has_role(v_caller, 'admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not allowed to bill for this user');
  END IF;

  SELECT * INTO v_part FROM public.group_chat_participants
    WHERE session_id = p_session_id AND user_id = v_man_id AND left_at IS NULL
    LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'not active participant', 'skipped', 'man_left');
  END IF;

  v_active_men := public.group_chat_active_men_count(p_session_id, v_host_id);
  IF COALESCE(v_active_men, 0) < 1 THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'no_active_men');
  END IF;

  IF public.has_role(v_man_id, 'admin') OR public.has_role(v_host_id, 'admin') THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'admin');
  END IF;

  v_minute := COALESCE(v_part.last_billed_minute, 0) + 1;
  v_man_idem  := 'groupchat:'||p_session_id::text||':'||v_man_id::text||':min:'||v_minute::text||':charge';
  v_host_idem := 'groupchat:'||p_session_id::text||':'||v_man_id::text||':min:'||v_minute::text||':host';
  v_plat_idem := 'groupchat:'||p_session_id::text||':'||v_man_id::text||':min:'||v_minute::text||':plat';

  IF EXISTS (
    SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_man_idem
    UNION ALL
    SELECT 1 FROM public.wallet_transactions_archive WHERE idempotency_key = v_man_idem
  ) THEN
    RETURN jsonb_build_object('success', true, 'duplicate', true);
  END IF;

  v_man_wallet_id := public.ensure_canonical_wallet(v_man_id, 'male');
  v_host_wallet_id := public.ensure_canonical_wallet(v_host_id, 'female');

  v_balance := public.canonical_wallet_balance(v_man_id);
  IF v_balance < v_man_charge THEN
    RETURN jsonb_build_object('success', false, 'insufficient', true, 'balance', v_balance);
  END IF;

  v_man_balance_after := (v_balance - v_man_charge)::numeric(12,2);
  v_host_balance := public.canonical_wallet_balance(v_host_id);
  v_host_balance_after := (v_host_balance + v_host_earn)::numeric(12,2);

  INSERT INTO public.wallet_transactions
    (wallet_id, user_id, type, transaction_type, amount, description, session_id, session_type,
     idempotency_key, status, rate_per_minute, balance_after, billing_metadata)
  VALUES
    (v_man_wallet_id, v_man_id, 'debit', 'debit', v_man_charge,
     'Group chat: min '||v_minute||' @ ₹'||v_man_charge||'/min',
     p_session_id, 'group_chat', v_man_idem, 'completed', v_man_charge, v_man_balance_after,
     jsonb_build_object('minute', v_minute, 'session', p_session_id, 'kind', 'group_chat_minute_charge'));

  INSERT INTO public.wallet_transactions
    (wallet_id, user_id, type, transaction_type, amount, description, session_id, session_type,
     idempotency_key, status, rate_per_minute, balance_after, billing_metadata)
  VALUES
    (v_host_wallet_id, v_host_id, 'credit', 'credit', v_host_earn,
     'Group chat earning: min '||v_minute||' from male user',
     p_session_id, 'group_chat', v_host_idem, 'completed', v_host_earn, v_host_balance_after,
     jsonb_build_object('minute', v_minute, 'session', p_session_id, 'kind', 'group_chat_host_earning', 'man_id', v_man_id));

  SELECT user_id INTO v_platform_user FROM public.user_roles WHERE role = 'admin' ORDER BY user_id LIMIT 1;
  IF v_platform_user IS NOT NULL AND v_platform_user IS DISTINCT FROM v_host_id THEN
    INSERT INTO public.wallet_transactions
      (user_id, type, transaction_type, amount, description, session_id, session_type,
       idempotency_key, status, rate_per_minute, billing_metadata)
    VALUES
      (v_platform_user, 'credit', 'credit', v_plat_rev,
       'Group chat platform revenue: min '||v_minute,
       p_session_id, 'group_chat', v_plat_idem, 'completed', v_plat_rev,
       jsonb_build_object('minute', v_minute, 'session', p_session_id, 'kind', 'group_chat_platform_revenue', 'man_id', v_man_id));
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

  PERFORM public.sync_wallet_balance_from_ledger(v_man_id);
  PERFORM public.sync_wallet_balance_from_ledger(v_host_id);

  RETURN jsonb_build_object(
    'success', true,
    'minute', v_minute,
    'charged', v_man_charge,
    'earned', v_host_earn,
    'balance', v_man_balance_after
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.group_chat_active_men_count(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bill_group_chat_minute(uuid, uuid) TO authenticated, service_role;
