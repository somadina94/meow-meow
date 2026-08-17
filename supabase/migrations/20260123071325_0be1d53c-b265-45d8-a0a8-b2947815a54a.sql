-- Fix stale women_availability.current_chat_count that doesn't match actual active sessions
-- This causes status mismatch where users appear busy when they have no active chats

-- Step 1: Sync women_availability.current_chat_count with actual active session count
UPDATE women_availability wa
SET 
  current_chat_count = (
    SELECT COALESCE(COUNT(*), 0) 
    FROM active_chat_sessions acs 
    WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
  ),
  is_available = (
    SELECT COALESCE(COUNT(*), 0) < 3
    FROM active_chat_sessions acs 
    WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
  );

-- Step 2: Fix user_status.status_text based on ACTUAL active sessions (not stale count)
UPDATE user_status us
SET status_text = CASE 
  WHEN us.is_online = false THEN 'offline'
  WHEN (
    SELECT COALESCE(COUNT(*), 0) 
    FROM active_chat_sessions acs 
    WHERE (acs.man_user_id = us.user_id OR acs.woman_user_id = us.user_id) 
    AND acs.status = 'active'
  ) >= 3 THEN 'busy'
  ELSE 'online'
END;

-- Step 3: Create a trigger to automatically sync status when active_chat_sessions changes
CREATE OR REPLACE FUNCTION sync_user_availability_on_session_change()
RETURNS TRIGGER AS $$
DECLARE
  woman_active_count INTEGER;
  man_active_count INTEGER;
BEGIN
  -- Get actual counts for the woman
  IF NEW.woman_user_id IS NOT NULL OR (TG_OP = 'UPDATE' AND OLD.woman_user_id IS NOT NULL) THEN
    SELECT COUNT(*) INTO woman_active_count
    FROM active_chat_sessions
    WHERE woman_user_id = COALESCE(NEW.woman_user_id, OLD.woman_user_id)
    AND status = 'active';
    
    -- Update women_availability
    UPDATE women_availability
    SET 
      current_chat_count = woman_active_count,
      is_available = woman_active_count < 3
    WHERE user_id = COALESCE(NEW.woman_user_id, OLD.woman_user_id);
    
    -- Update user_status for woman
    UPDATE user_status
    SET status_text = CASE 
      WHEN is_online = false THEN 'offline'
      WHEN woman_active_count >= 3 THEN 'busy'
      ELSE 'online'
    END
    WHERE user_id = COALESCE(NEW.woman_user_id, OLD.woman_user_id);
  END IF;
  
  -- Get actual counts for the man
  IF NEW.man_user_id IS NOT NULL OR (TG_OP = 'UPDATE' AND OLD.man_user_id IS NOT NULL) THEN
    SELECT COUNT(*) INTO man_active_count
    FROM active_chat_sessions
    WHERE man_user_id = COALESCE(NEW.man_user_id, OLD.man_user_id)
    AND status = 'active';
    
    -- Update user_status for man
    UPDATE user_status
    SET status_text = CASE 
      WHEN is_online = false THEN 'offline'
      WHEN man_active_count >= 3 THEN 'busy'
      ELSE 'online'
    END
    WHERE user_id = COALESCE(NEW.man_user_id, OLD.man_user_id);
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop existing trigger if exists and create new one
DROP TRIGGER IF EXISTS sync_availability_on_session_change ON active_chat_sessions;

CREATE TRIGGER sync_availability_on_session_change
AFTER INSERT OR UPDATE OR DELETE ON active_chat_sessions
FOR EACH ROW
EXECUTE FUNCTION sync_user_availability_on_session_change();