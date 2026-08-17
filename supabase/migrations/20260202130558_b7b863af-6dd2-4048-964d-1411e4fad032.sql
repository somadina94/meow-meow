-- Clean up stale billing_paused and paused sessions (older than 10 minutes)
UPDATE active_chat_sessions
SET status = 'ended',
    end_reason = 'stale_session_cleanup',
    ended_at = NOW()
WHERE status IN ('billing_paused', 'paused')
AND last_activity_at < NOW() - INTERVAL '10 minutes';

-- Reset women_availability counts for users with no active sessions
UPDATE women_availability wa
SET current_chat_count = (
  SELECT COUNT(*) FROM active_chat_sessions acs 
  WHERE acs.woman_user_id = wa.user_id AND acs.status = 'active'
),
is_available = true
WHERE current_chat_count > 0;

-- Reset user_status for users who should be online but marked as busy incorrectly
UPDATE user_status us
SET status_text = CASE 
  WHEN NOT is_online THEN 'offline'
  WHEN (SELECT COUNT(*) FROM active_chat_sessions WHERE (man_user_id = us.user_id OR woman_user_id = us.user_id) AND status = 'active') >= 3 THEN 'busy'
  ELSE 'online'
END,
active_chat_count = (
  SELECT COUNT(*) FROM active_chat_sessions WHERE man_user_id = us.user_id AND status = 'active'
)
WHERE is_online = true;