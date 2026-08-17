
-- Retroactively bill today's unbilled sessions
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT call_id, call_type
    FROM video_call_sessions
    WHERE started_at >= '2026-04-10'
      AND status IN ('completed', 'ended')
      AND (total_earned = 0 OR total_earned IS NULL)
      AND (total_minutes = 0 OR total_minutes IS NULL)
      AND started_at IS NOT NULL
      AND ended_at IS NOT NULL
      AND EXTRACT(EPOCH FROM (ended_at - started_at)) > 0
  LOOP
    PERFORM public.process_call_billing(r.call_id, COALESCE(r.call_type, 'video'));
  END LOOP;
END;
$$;
