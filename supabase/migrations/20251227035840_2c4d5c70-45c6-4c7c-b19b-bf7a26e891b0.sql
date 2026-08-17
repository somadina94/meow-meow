
-- Fix stale women_availability counts by syncing with actual active sessions
UPDATE women_availability wa
SET current_chat_count = (
  SELECT COALESCE(COUNT(*), 0) 
  FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
);

-- Create a trigger function to automatically sync chat counts
CREATE OR REPLACE FUNCTION sync_women_chat_count()
RETURNS TRIGGER AS $$
BEGIN
  -- On INSERT of active session: increment count
  IF TG_OP = 'INSERT' AND NEW.status = 'active' THEN
    INSERT INTO women_availability (user_id, current_chat_count, is_available)
    VALUES (NEW.woman_user_id, 1, true)
    ON CONFLICT (user_id) DO UPDATE 
    SET current_chat_count = women_availability.current_chat_count + 1;
  END IF;
  
  -- On UPDATE from active to ended: decrement count
  IF TG_OP = 'UPDATE' AND OLD.status = 'active' AND NEW.status = 'ended' THEN
    UPDATE women_availability
    SET current_chat_count = GREATEST(0, current_chat_count - 1)
    WHERE user_id = NEW.woman_user_id;
  END IF;
  
  -- On DELETE of active session: decrement count
  IF TG_OP = 'DELETE' AND OLD.status = 'active' THEN
    UPDATE women_availability
    SET current_chat_count = GREATEST(0, current_chat_count - 1)
    WHERE user_id = OLD.woman_user_id;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS sync_women_chat_count_trigger ON active_chat_sessions;

-- Create trigger on active_chat_sessions
CREATE TRIGGER sync_women_chat_count_trigger
AFTER INSERT OR UPDATE OR DELETE ON active_chat_sessions
FOR EACH ROW
EXECUTE FUNCTION sync_women_chat_count();
