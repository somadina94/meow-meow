
-- Create trigger on video_call_sessions to auto-sync user_status and women_availability
CREATE OR REPLACE FUNCTION public.sync_user_status_on_video_call_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid;
  v_chat_count integer;
  v_video_count integer;
  v_total integer;
  v_status_text text;
BEGIN
  -- Process woman user
  FOR v_user_id IN
    SELECT unnest(ARRAY[
      COALESCE(NEW.woman_user_id, OLD.woman_user_id),
      COALESCE(NEW.man_user_id, OLD.man_user_id)
    ])
  LOOP
    IF v_user_id IS NULL THEN CONTINUE; END IF;

    -- Count active chats
    SELECT COUNT(*) INTO v_chat_count
    FROM active_chat_sessions
    WHERE (man_user_id = v_user_id OR woman_user_id = v_user_id)
    AND status = 'active';

    -- Count active video calls
    SELECT COUNT(*) INTO v_video_count
    FROM video_call_sessions
    WHERE (man_user_id = v_user_id OR woman_user_id = v_user_id)
    AND status = 'active';

    v_total := v_chat_count + v_video_count;

    -- Determine status
    IF v_video_count > 0 THEN
      v_status_text := 'busy';
    ELSIF v_chat_count >= 3 THEN
      v_status_text := 'busy';
    ELSE
      v_status_text := 'online';
    END IF;

    -- Update user_status
    UPDATE user_status
    SET status_text = CASE WHEN is_online = false THEN 'offline' ELSE v_status_text END,
        last_seen = now()
    WHERE user_id = v_user_id;

    -- Update women_availability if applicable
    UPDATE women_availability
    SET current_call_count = v_video_count,
        is_available = v_chat_count < 3 AND v_video_count = 0,
        is_available_for_calls = v_video_count = 0
    WHERE user_id = v_user_id;
  END LOOP;

  RETURN COALESCE(NEW, OLD);
END;
$function$;

-- Create trigger
DROP TRIGGER IF EXISTS sync_video_call_status ON video_call_sessions;
CREATE TRIGGER sync_video_call_status
  AFTER INSERT OR UPDATE OR DELETE ON video_call_sessions
  FOR EACH ROW
  EXECUTE FUNCTION sync_user_status_on_video_call_change();
