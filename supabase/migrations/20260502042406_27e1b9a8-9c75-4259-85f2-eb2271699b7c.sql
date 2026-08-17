CREATE OR REPLACE FUNCTION public.reconcile_user_busy_status(_user_id uuid DEFAULT NULL)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  affected integer := 0;
BEGIN
  -- Clear user_status.status_text='busy' when no active chats and no active video calls
  WITH stuck AS (
    SELECT us.user_id
    FROM public.user_status us
    WHERE us.status_text = 'busy'
      AND (_user_id IS NULL OR us.user_id = _user_id)
      AND NOT EXISTS (
        SELECT 1 FROM public.active_chat_sessions acs
        WHERE (acs.woman_user_id = us.user_id OR acs.man_user_id = us.user_id)
          AND acs.status IN ('active','pending')
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.video_call_sessions vcs
        WHERE (vcs.woman_user_id = us.user_id OR vcs.man_user_id = us.user_id)
          AND vcs.status IN ('active','ringing','connected','ongoing')
      )
  ),
  upd AS (
    UPDATE public.user_status us
    SET status_text = CASE WHEN us.is_online THEN 'online' ELSE 'offline' END,
        active_chat_count = 0,
        active_call_count = 0,
        updated_at = now()
    FROM stuck
    WHERE us.user_id = stuck.user_id
    RETURNING us.user_id
  )
  SELECT COUNT(*) INTO affected FROM upd;

  -- Reset women_availability.is_available=true when no active chats
  UPDATE public.women_availability wa
  SET is_available = true,
      current_chat_count = 0,
      updated_at = now()
  WHERE wa.is_available = false
    AND (_user_id IS NULL OR wa.user_id = _user_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.active_chat_sessions acs
      WHERE acs.woman_user_id = wa.user_id
        AND acs.status IN ('active','pending')
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.video_call_sessions vcs
      WHERE vcs.woman_user_id = wa.user_id
        AND vcs.status IN ('active','ringing','connected','ongoing')
    );

  RETURN affected;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reconcile_user_busy_status(uuid) TO authenticated, anon, service_role;

-- Run once now to clear current stuck flags
SELECT public.reconcile_user_busy_status(NULL);