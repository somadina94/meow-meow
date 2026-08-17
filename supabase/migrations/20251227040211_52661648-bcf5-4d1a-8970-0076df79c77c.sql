
-- Sync men's chat count in user_status when sessions change
CREATE OR REPLACE FUNCTION sync_user_chat_count()
RETURNS TRIGGER AS $$
BEGIN
  -- On INSERT of active session: increment count for man
  IF TG_OP = 'INSERT' AND NEW.status = 'active' THEN
    UPDATE user_status
    SET active_chat_count = COALESCE(active_chat_count, 0) + 1
    WHERE user_id = NEW.man_user_id;
  END IF;
  
  -- On UPDATE from active to ended: decrement count for man
  IF TG_OP = 'UPDATE' AND OLD.status = 'active' AND NEW.status = 'ended' THEN
    UPDATE user_status
    SET active_chat_count = GREATEST(0, COALESCE(active_chat_count, 0) - 1)
    WHERE user_id = NEW.man_user_id;
  END IF;
  
  -- On DELETE of active session: decrement count for man
  IF TG_OP = 'DELETE' AND OLD.status = 'active' THEN
    UPDATE user_status
    SET active_chat_count = GREATEST(0, COALESCE(active_chat_count, 0) - 1)
    WHERE user_id = OLD.man_user_id;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS sync_user_chat_count_trigger ON active_chat_sessions;

-- Create trigger for men's chat count
CREATE TRIGGER sync_user_chat_count_trigger
AFTER INSERT OR UPDATE OR DELETE ON active_chat_sessions
FOR EACH ROW
EXECUTE FUNCTION sync_user_chat_count();

-- Auto-end active chats when user goes offline
CREATE OR REPLACE FUNCTION auto_end_chats_on_offline()
RETURNS TRIGGER AS $$
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
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS auto_end_chats_on_offline_trigger ON user_status;

-- Create trigger for auto-ending chats when offline
CREATE TRIGGER auto_end_chats_on_offline_trigger
AFTER UPDATE ON user_status
FOR EACH ROW
EXECUTE FUNCTION auto_end_chats_on_offline();

-- Reset all stale chat counts to match actual active sessions
UPDATE user_status us
SET active_chat_count = (
  SELECT COALESCE(COUNT(*), 0) 
  FROM active_chat_sessions acs 
  WHERE acs.man_user_id = us.user_id AND acs.status = 'active'
);

UPDATE women_availability wa
SET current_chat_count = (
  SELECT COALESCE(COUNT(*), 0) 
  FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
);
