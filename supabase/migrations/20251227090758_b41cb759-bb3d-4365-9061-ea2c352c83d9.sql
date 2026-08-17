-- Reset stale women_availability counts (no active sessions exist)
UPDATE women_availability 
SET current_chat_count = 0, 
    current_call_count = 0
WHERE current_chat_count > 0 OR current_call_count > 0;

-- Create or replace function to sync women availability when chat sessions change
CREATE OR REPLACE FUNCTION public.sync_women_availability_on_session_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- On INSERT of active session: increment chat count
  IF TG_OP = 'INSERT' AND NEW.status = 'active' THEN
    UPDATE women_availability
    SET current_chat_count = COALESCE(current_chat_count, 0) + 1
    WHERE user_id = NEW.woman_user_id;
  END IF;
  
  -- On UPDATE from active to ended: decrement chat count and reset if zero
  IF TG_OP = 'UPDATE' AND OLD.status = 'active' AND NEW.status = 'ended' THEN
    UPDATE women_availability
    SET current_chat_count = GREATEST(0, COALESCE(current_chat_count, 0) - 1)
    WHERE user_id = NEW.woman_user_id;
  END IF;
  
  -- On DELETE of active session: decrement chat count
  IF TG_OP = 'DELETE' AND OLD.status = 'active' THEN
    UPDATE women_availability
    SET current_chat_count = GREATEST(0, COALESCE(current_chat_count, 0) - 1)
    WHERE user_id = OLD.woman_user_id;
    RETURN OLD;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- Drop and recreate the trigger
DROP TRIGGER IF EXISTS trigger_sync_women_availability ON public.active_chat_sessions;

CREATE TRIGGER trigger_sync_women_availability
AFTER INSERT OR UPDATE OR DELETE ON public.active_chat_sessions
FOR EACH ROW
EXECUTE FUNCTION public.sync_women_availability_on_session_change();

-- Create or replace function to sync women availability for video calls
CREATE OR REPLACE FUNCTION public.sync_women_video_availability()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- On INSERT of active/ringing/connecting session: increment call count
  IF TG_OP = 'INSERT' AND NEW.status IN ('active', 'ringing', 'connecting') THEN
    UPDATE women_availability
    SET current_call_count = COALESCE(current_call_count, 0) + 1
    WHERE user_id = NEW.woman_user_id;
  END IF;
  
  -- On UPDATE to ended: decrement call count
  IF TG_OP = 'UPDATE' AND OLD.status IN ('active', 'ringing', 'connecting') AND NEW.status = 'ended' THEN
    UPDATE women_availability
    SET current_call_count = GREATEST(0, COALESCE(current_call_count, 0) - 1)
    WHERE user_id = NEW.woman_user_id;
  END IF;
  
  -- On DELETE of active session: decrement call count
  IF TG_OP = 'DELETE' AND OLD.status IN ('active', 'ringing', 'connecting') THEN
    UPDATE women_availability
    SET current_call_count = GREATEST(0, COALESCE(current_call_count, 0) - 1)
    WHERE user_id = OLD.woman_user_id;
    RETURN OLD;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- Drop and recreate the trigger for video calls
DROP TRIGGER IF EXISTS trigger_sync_women_video_availability ON public.video_call_sessions;

CREATE TRIGGER trigger_sync_women_video_availability
AFTER INSERT OR UPDATE OR DELETE ON public.video_call_sessions
FOR EACH ROW
EXECUTE FUNCTION public.sync_women_video_availability();

-- Also update the cleanup function to reset availability counts
CREATE OR REPLACE FUNCTION public.cleanup_expired_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- 1. End chat sessions idle for 3+ minutes
  UPDATE active_chat_sessions
  SET status = 'ended',
      ended_at = NOW(),
      end_reason = 'idle_3min'
  WHERE status = 'active'
    AND last_activity_at < NOW() - INTERVAL '3 minutes';

  -- 2. Delete chat messages older than 7 days
  DELETE FROM chat_messages
  WHERE created_at < NOW() - INTERVAL '7 days';

  -- 3. Delete group messages older than 15 minutes (ephemeral chat)
  DELETE FROM group_messages
  WHERE created_at < NOW() - INTERVAL '15 minutes';

  -- 4. Delete language community messages older than 15 minutes
  DELETE FROM language_community_messages
  WHERE created_at < NOW() - INTERVAL '15 minutes';

  -- 5. Delete wallet transactions older than 9 years
  DELETE FROM wallet_transactions
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 6. Delete admin revenue transactions older than 9 years
  DELETE FROM admin_revenue_transactions
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 7. Delete women earnings older than 9 years
  DELETE FROM women_earnings
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 8. Delete gift transactions older than 9 years
  DELETE FROM gift_transactions
  WHERE created_at < NOW() - INTERVAL '9 years';

  -- 9. Mark stale users as offline (10 min inactivity)
  UPDATE user_status
  SET is_online = false
  WHERE is_online = true
    AND last_seen < NOW() - INTERVAL '10 minutes';

  -- 10. Reset women_availability counts for users with no active sessions
  UPDATE women_availability wa
  SET current_chat_count = 0
  WHERE current_chat_count > 0
    AND NOT EXISTS (
      SELECT 1 FROM active_chat_sessions acs 
      WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
    );

  UPDATE women_availability wa
  SET current_call_count = 0
  WHERE current_call_count > 0
    AND NOT EXISTS (
      SELECT 1 FROM video_call_sessions vcs 
      WHERE vcs.woman_user_id = wa.user_id AND vcs.status IN ('active', 'ringing', 'connecting')
    );
END;
$function$;