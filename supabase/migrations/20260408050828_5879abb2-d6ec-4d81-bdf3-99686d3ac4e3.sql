
-- Bill all unbilled completed/ended sessions
DO $$
DECLARE
  v_session record;
  v_result jsonb;
  v_call_type text;
BEGIN
  FOR v_session IN
    SELECT call_id, call_type
    FROM public.video_call_sessions
    WHERE status IN ('completed', 'ended')
      AND started_at IS NOT NULL
      AND ended_at IS NOT NULL
      AND total_minutes = 0
      AND total_earned = 0
  LOOP
    v_call_type := COALESCE(v_session.call_type, 'video');
    SELECT public.process_call_billing(v_session.call_id, v_call_type) INTO v_result;
    RAISE NOTICE 'Billed %: %', v_session.call_id, v_result;
  END LOOP;
END;
$$;
