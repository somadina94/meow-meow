-- Fix stale women_availability: set is_available=false for women who are NOT online
UPDATE women_availability wa
SET is_available = false, 
    is_available_for_calls = false,
    updated_at = now()
WHERE NOT EXISTS (
  SELECT 1 FROM user_status us 
  WHERE us.user_id = wa.user_id 
  AND us.is_online = true
);

-- Also ensure current_chat_count is reset for women with no active sessions
UPDATE women_availability wa
SET current_chat_count = 0
WHERE current_chat_count > 0
AND NOT EXISTS (
  SELECT 1 FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id 
  AND acs.status = 'active'
);

-- Reset current_call_count for women with no active calls
UPDATE women_availability wa
SET current_call_count = 0
WHERE current_call_count > 0
AND NOT EXISTS (
  SELECT 1 FROM video_call_sessions vcs 
  WHERE vcs.woman_user_id = wa.user_id 
  AND vcs.status IN ('active', 'ringing', 'connecting')
);