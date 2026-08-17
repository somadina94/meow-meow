CREATE OR REPLACE FUNCTION public.process_call_billing(
  p_call_id text,
  p_call_type text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session record;
  v_seconds numeric;
  v_minutes numeric;
  v_idem text;
  v_result jsonb;
BEGIN
  IF p_call_id IS NULL OR length(p_call_id) < 4 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_call_id');
  END IF;
  IF p_call_type NOT IN ('audio','video') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_call_type');
  END IF;

  SELECT * INTO v_session
  FROM public.video_call_sessions
  WHERE call_id = p_call_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_not_found');
  END IF;

  IF v_session.started_at IS NULL THEN
    -- Call never connected; nothing to bill
    RETURN jsonb_build_object('success', true, 'skipped', 'never_connected');
  END IF;

  v_seconds := EXTRACT(EPOCH FROM (COALESCE(v_session.ended_at, NOW()) - v_session.started_at));
  IF v_seconds < 1 THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'zero_duration');
  END IF;

  -- Pro-rated minutes (per-second precision)
  v_minutes := ROUND((v_seconds / 60.0)::numeric, 4);

  -- Stamp total_minutes for reporting
  UPDATE public.video_call_sessions
     SET total_minutes = v_minutes,
         updated_at = NOW()
   WHERE id = v_session.id;

  v_idem := p_call_type || '_eoc:' || v_session.id::text;

  IF p_call_type = 'audio' THEN
    v_result := public.process_audio_billing(
      p_session_id   := v_session.id::text,
      p_man_id       := v_session.man_user_id,
      p_woman_id     := v_session.woman_user_id,
      p_minutes      := v_minutes,
      p_idempotency  := v_idem
    );
  ELSE
    v_result := public.process_video_billing_v2(
      p_session_id   := v_session.id::text,
      p_man_id       := v_session.man_user_id,
      p_woman_id     := v_session.woman_user_id,
      p_minutes      := v_minutes,
      p_idempotency  := v_idem
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'call_type', p_call_type,
    'minutes', v_minutes,
    'billing', v_result
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_call_billing(text, text) TO authenticated, service_role;