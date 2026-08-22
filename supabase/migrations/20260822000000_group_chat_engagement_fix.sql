-- Group chat billing was silently failing because wallet_transactions
-- rejected session_type = 'group_chat'. Earnings UI then reset each minute
-- because the client counted a billed minute that never landed in the ledger.
-- Also treat mutual "hello" messages as engagement even after someone leaves.

ALTER TABLE public.wallet_transactions
  DROP CONSTRAINT IF EXISTS wallet_transactions_session_type_check;

ALTER TABLE public.wallet_transactions
  ADD CONSTRAINT wallet_transactions_session_type_check
  CHECK (
    session_type IS NULL OR session_type = ANY (ARRAY[
      'chat','audio_call','video_call','private_group_call',
      'group_call','private_call','group','group_chat',
      'gift','tip','wallet','video','admin','withdrawal','payout'
    ]::text[])
  );

CREATE OR REPLACE FUNCTION public.group_chat_has_mutual_engagement(p_session_id uuid, p_host_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.group_chat_messages m
     WHERE m.session_id = p_session_id
       AND m.deleted_at IS NULL
       AND m.sender_id = p_host_id
       AND (
         (COALESCE(trim(m.body), '') <> '' AND left(trim(m.body), 1) <> '👋')
         OR COALESCE(m.media_url, '') <> ''
       )
  )
  AND EXISTS (
    SELECT 1
      FROM public.group_chat_messages m
     WHERE m.session_id = p_session_id
       AND m.deleted_at IS NULL
       AND m.sender_id IS DISTINCT FROM p_host_id
       AND (
         (COALESCE(trim(m.body), '') <> '' AND left(trim(m.body), 1) <> '👋')
         OR COALESCE(m.media_url, '') <> ''
       )
       AND EXISTS (
         SELECT 1
           FROM public.group_chat_participants gcp
          WHERE gcp.session_id = p_session_id
            AND gcp.user_id = m.sender_id
            AND gcp.user_id IS DISTINCT FROM p_host_id
       )
  );
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
  v_minute int;
  v_result jsonb;
  v_charged numeric;
  v_earned numeric;
BEGIN
  PERFORM set_config('row_security', 'off', true);

  v_man_id := public.resolve_wallet_user_id(p_man_id);

  SELECT * INTO v_session FROM public.group_chat_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_session.ended_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session not live', 'skipped', 'not_live');
  END IF;

  v_host_id := public.resolve_wallet_user_id(v_session.host_id);
  IF v_man_id IS NOT DISTINCT FROM v_host_id THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'host_not_billable');
  END IF;

  SELECT * INTO v_part FROM public.group_chat_participants
   WHERE session_id = p_session_id AND user_id = v_man_id AND left_at IS NULL
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'not active participant', 'skipped', 'man_left');
  END IF;

  v_minute := COALESCE(v_part.last_billed_minute, 0) + 1;

  v_result := public.bill_session_minute(
    p_session_id, 'group_chat', 1, v_man_id, v_host_id, 1, v_minute
  );

  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_result;
  END IF;

  IF v_result ? 'skipped' THEN
    RETURN v_result;
  END IF;

  IF COALESCE((v_result->>'duplicate_skipped')::boolean, false) THEN
    RETURN jsonb_build_object('success', true, 'duplicate', true);
  END IF;

  v_charged := COALESCE((v_result->>'charged')::numeric, 2.00);
  v_earned := COALESCE((v_result->>'earned')::numeric, 1.00);

  UPDATE public.group_chat_participants
     SET last_billed_minute = v_minute,
         total_billed = total_billed + v_charged,
         total_seconds = total_seconds + 60
   WHERE id = v_part.id;

  UPDATE public.group_chat_sessions
     SET total_men_minutes = total_men_minutes + 1,
         total_host_earning = total_host_earning + v_earned,
         total_platform_revenue = total_platform_revenue + GREATEST(v_charged - v_earned, 0)
   WHERE id = p_session_id;

  RETURN jsonb_build_object(
    'success', true,
    'minute', v_minute,
    'charged', v_charged,
    'earned', v_earned,
    'balance', v_result->'balance'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.group_chat_has_mutual_engagement(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bill_group_chat_minute(uuid, uuid) TO authenticated, service_role;
