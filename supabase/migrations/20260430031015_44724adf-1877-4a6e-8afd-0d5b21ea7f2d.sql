-- ============================================================================
-- First-minute billing trigger for audio + video calls
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_call_first_minute_billing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session_type text;
BEGIN
  -- Skip if either party is missing
  IF NEW.man_user_id IS NULL OR NEW.woman_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Map call_type → session_type expected by bill_session_minute
  v_session_type := CASE LOWER(COALESCE(NEW.call_type, ''))
    WHEN 'audio' THEN 'audio_call'
    WHEN 'video' THEN 'video_call'
    ELSE NULL
  END;

  IF v_session_type IS NULL THEN
    RETURN NEW;
  END IF;

  -- Bill minute 0 immediately (idempotent — client tick at minute 1+ won't double-charge)
  BEGIN
    PERFORM public.bill_session_minute(
      p_session_id   => NEW.id,
      p_session_type => v_session_type,
      p_minutes      => 1.0,
      p_man_id       => NEW.man_user_id,
      p_woman_id     => NEW.woman_user_id,
      p_man_count    => 1,
      p_minute_index => 0
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'call first-minute billing failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_video_call_first_minute_billing ON public.video_call_sessions;
CREATE TRIGGER trg_video_call_first_minute_billing
AFTER INSERT ON public.video_call_sessions
FOR EACH ROW
EXECUTE FUNCTION public.trg_call_first_minute_billing();

GRANT EXECUTE ON FUNCTION public.trg_call_first_minute_billing() TO authenticated, service_role;