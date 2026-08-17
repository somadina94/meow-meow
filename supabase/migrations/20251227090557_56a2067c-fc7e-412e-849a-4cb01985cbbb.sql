-- Create or replace function to auto-end video calls when user goes offline
CREATE OR REPLACE FUNCTION public.auto_end_video_calls_on_offline()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- When user goes offline, end their active video call sessions
  IF OLD.is_online = true AND NEW.is_online = false THEN
    -- End video sessions where this user is the man
    UPDATE video_call_sessions
    SET status = 'ended',
        ended_at = NOW(),
        end_reason = 'partner_offline'
    WHERE man_user_id = NEW.user_id
      AND status IN ('active', 'ringing', 'connecting');
    
    -- End video sessions where this user is the woman
    UPDATE video_call_sessions
    SET status = 'ended',
        ended_at = NOW(),
        end_reason = 'partner_offline'
    WHERE woman_user_id = NEW.user_id
      AND status IN ('active', 'ringing', 'connecting');
  END IF;
  
  RETURN NEW;
END;
$function$;

-- Drop existing trigger if exists and recreate
DROP TRIGGER IF EXISTS trigger_auto_end_video_calls_on_offline ON public.user_status;

CREATE TRIGGER trigger_auto_end_video_calls_on_offline
AFTER UPDATE ON public.user_status
FOR EACH ROW
EXECUTE FUNCTION public.auto_end_video_calls_on_offline();

-- Update the existing auto_end_chats_on_offline to also update women_availability
CREATE OR REPLACE FUNCTION public.auto_end_chats_on_offline()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- When user goes offline, end their active chat sessions
  IF OLD.is_online = true AND NEW.is_online = false THEN
    -- End sessions where this user is the man
    UPDATE active_chat_sessions
    SET status = 'ended',
        ended_at = NOW(),
        end_reason = 'partner_offline'
    WHERE man_user_id = NEW.user_id
      AND status = 'active';
    
    -- End sessions where this user is the woman
    UPDATE active_chat_sessions
    SET status = 'ended',
        ended_at = NOW(),
        end_reason = 'partner_offline'
    WHERE woman_user_id = NEW.user_id
      AND status = 'active';
    
    -- Reset women_availability when woman goes offline
    UPDATE women_availability
    SET current_chat_count = 0,
        is_available = false
    WHERE user_id = NEW.user_id;
  END IF;
  
  RETURN NEW;
END;
$function$;