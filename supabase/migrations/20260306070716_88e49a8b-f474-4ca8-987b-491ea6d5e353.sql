
-- 1. Add user_status to realtime publication so frontend can see changes
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_status;

-- 2. Drop redundant increment/decrement triggers that cause count drift
DROP TRIGGER IF EXISTS trigger_sync_all_chat_availability ON active_chat_sessions;
DROP TRIGGER IF EXISTS sync_women_chat_count_trigger ON active_chat_sessions;
DROP TRIGGER IF EXISTS sync_user_chat_count_trigger ON active_chat_sessions;
DROP TRIGGER IF EXISTS trigger_sync_all_video_availability ON video_call_sessions;

-- 3. Replace chat session trigger: handles ALL status transitions using actual COUNTs
CREATE OR REPLACE FUNCTION public.sync_user_availability_on_session_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_woman_id uuid;
  v_man_id uuid;
  v_woman_chat_count INTEGER;
  v_woman_video_count INTEGER;
  v_man_chat_count INTEGER;
  v_man_video_count INTEGER;
BEGIN
  v_woman_id := COALESCE(NEW.woman_user_id, OLD.woman_user_id);
  v_man_id := COALESCE(NEW.man_user_id, OLD.man_user_id);

  IF v_woman_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_woman_chat_count
    FROM active_chat_sessions
    WHERE woman_user_id = v_woman_id AND status = 'active';
    
    SELECT COUNT(*) INTO v_woman_video_count
    FROM video_call_sessions
    WHERE woman_user_id = v_woman_id AND status = 'active';
    
    UPDATE women_availability
    SET 
      current_chat_count = v_woman_chat_count,
      is_available = v_woman_chat_count < 3 AND v_woman_video_count = 0,
      is_available_for_calls = v_woman_video_count = 0,
      current_call_count = v_woman_video_count
    WHERE user_id = v_woman_id;
    
    UPDATE user_status
    SET 
      active_chat_count = v_woman_chat_count,
      active_call_count = v_woman_video_count,
      status_text = CASE 
        WHEN is_online = false THEN 'offline'
        WHEN v_woman_video_count > 0 THEN 'busy'
        WHEN v_woman_chat_count >= 3 THEN 'busy'
        ELSE 'online'
      END,
      last_seen = now()
    WHERE user_id = v_woman_id;
  END IF;
  
  IF v_man_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_man_chat_count
    FROM active_chat_sessions
    WHERE man_user_id = v_man_id AND status = 'active';
    
    SELECT COUNT(*) INTO v_man_video_count
    FROM video_call_sessions
    WHERE man_user_id = v_man_id AND status = 'active';
    
    UPDATE user_status
    SET 
      active_chat_count = v_man_chat_count,
      active_call_count = v_man_video_count,
      status_text = CASE 
        WHEN is_online = false THEN 'offline'
        WHEN v_man_video_count > 0 THEN 'busy'
        WHEN v_man_chat_count >= 3 THEN 'busy'
        ELSE 'online'
      END,
      last_seen = now()
    WHERE user_id = v_man_id;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$function$;

-- 4. Replace video call trigger: handles ALL transitions (declined, missed, timeout_cleanup, ended)
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
  v_status_text text;
BEGIN
  FOR v_user_id IN
    SELECT unnest(ARRAY[
      COALESCE(NEW.woman_user_id, OLD.woman_user_id),
      COALESCE(NEW.man_user_id, OLD.man_user_id)
    ])
  LOOP
    IF v_user_id IS NULL THEN CONTINUE; END IF;

    SELECT COUNT(*) INTO v_chat_count
    FROM active_chat_sessions
    WHERE (man_user_id = v_user_id OR woman_user_id = v_user_id)
    AND status = 'active';

    SELECT COUNT(*) INTO v_video_count
    FROM video_call_sessions
    WHERE (man_user_id = v_user_id OR woman_user_id = v_user_id)
    AND status = 'active';

    IF v_video_count > 0 THEN
      v_status_text := 'busy';
    ELSIF v_chat_count >= 3 THEN
      v_status_text := 'busy';
    ELSE
      v_status_text := 'online';
    END IF;

    UPDATE user_status
    SET status_text = CASE WHEN is_online = false THEN 'offline' ELSE v_status_text END,
        active_chat_count = v_chat_count,
        active_call_count = v_video_count,
        last_seen = now()
    WHERE user_id = v_user_id;

    UPDATE women_availability
    SET current_call_count = v_video_count,
        current_chat_count = v_chat_count,
        is_available = v_chat_count < 3 AND v_video_count = 0,
        is_available_for_calls = v_video_count = 0
    WHERE user_id = v_user_id;
  END LOOP;

  RETURN COALESCE(NEW, OLD);
END;
$function$;

-- 5. Reset any drifted counts to accurate values
UPDATE user_status us
SET active_chat_count = (
  SELECT COUNT(*) FROM active_chat_sessions 
  WHERE (man_user_id = us.user_id OR woman_user_id = us.user_id) AND status = 'active'
),
active_call_count = (
  SELECT COUNT(*) FROM video_call_sessions 
  WHERE (man_user_id = us.user_id OR woman_user_id = us.user_id) AND status = 'active'
),
status_text = CASE
  WHEN is_online = false THEN 'offline'
  WHEN (SELECT COUNT(*) FROM video_call_sessions WHERE (man_user_id = us.user_id OR woman_user_id = us.user_id) AND status = 'active') > 0 THEN 'busy'
  WHEN (SELECT COUNT(*) FROM active_chat_sessions WHERE (man_user_id = us.user_id OR woman_user_id = us.user_id) AND status = 'active') >= 3 THEN 'busy'
  WHEN is_online = true THEN 'online'
  ELSE 'offline'
END;

UPDATE women_availability wa
SET current_chat_count = (
  SELECT COUNT(*) FROM active_chat_sessions WHERE woman_user_id = wa.user_id AND status = 'active'
),
current_call_count = (
  SELECT COUNT(*) FROM video_call_sessions WHERE woman_user_id = wa.user_id AND status = 'active'
),
is_available = (
  SELECT COUNT(*) FROM active_chat_sessions WHERE woman_user_id = wa.user_id AND status = 'active'
) < 3 AND (
  SELECT COUNT(*) FROM video_call_sessions WHERE woman_user_id = wa.user_id AND status = 'active'
) = 0,
is_available_for_calls = (
  SELECT COUNT(*) FROM video_call_sessions WHERE woman_user_id = wa.user_id AND status = 'active'
) = 0;
