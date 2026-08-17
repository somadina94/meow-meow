
-- Update trg_video_call_ended to auto-bill when call ends
CREATE OR REPLACE FUNCTION public.trg_video_call_ended()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status IN ('ended', 'completed') AND OLD.status IS DISTINCT FROM NEW.status THEN
    -- Revert busy status
    PERFORM public.revert_busy_to_online(NEW.man_user_id);
    PERFORM public.revert_busy_to_online(NEW.woman_user_id);

    -- Auto-bill if not already billed and call had valid duration
    IF (NEW.total_earned = 0 OR NEW.total_earned IS NULL)
       AND (NEW.total_minutes = 0 OR NEW.total_minutes IS NULL)
       AND NEW.started_at IS NOT NULL
       AND NEW.ended_at IS NOT NULL
       AND EXTRACT(EPOCH FROM (NEW.ended_at - NEW.started_at)) > 0
    THEN
      PERFORM public.process_call_billing(NEW.call_id, COALESCE(NEW.call_type, 'video'));
    END IF;
  ELSIF NEW.status IN ('declined', 'missed') AND OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM public.revert_busy_to_online(NEW.man_user_id);
    PERFORM public.revert_busy_to_online(NEW.woman_user_id);
  END IF;
  RETURN NEW;
END;
$$;
