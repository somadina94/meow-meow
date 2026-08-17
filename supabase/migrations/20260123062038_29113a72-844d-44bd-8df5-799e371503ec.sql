-- Fix stale busy status: Sync women_availability and user_status with actual active sessions

-- First, update women_availability to reflect actual active session counts
UPDATE women_availability wa
SET current_chat_count = (
  SELECT COALESCE(COUNT(*), 0) 
  FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
),
is_available = (
  SELECT COALESCE(COUNT(*), 0) < 3
  FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
);

-- Update user_status to reflect correct status based on actual active sessions
UPDATE user_status us
SET status_text = CASE 
  WHEN (
    SELECT COALESCE(COUNT(*), 0) 
    FROM active_chat_sessions acs 
    WHERE (acs.man_user_id = us.user_id OR acs.woman_user_id = us.user_id) 
    AND acs.status = 'active'
  ) >= 3 THEN 'busy'
  ELSE 'online'
END
WHERE us.is_online = true;

-- For offline users, ensure status is not busy
UPDATE user_status
SET status_text = 'offline'
WHERE is_online = false AND status_text = 'busy';