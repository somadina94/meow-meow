
-- Create function to cleanup idle sessions (10 mins without activity)
CREATE OR REPLACE FUNCTION cleanup_idle_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- End sessions where last_activity_at is more than 10 minutes ago
  UPDATE active_chat_sessions
  SET status = 'ended',
      ended_at = NOW(),
      end_reason = 'session_idle_10min'
  WHERE status = 'active'
    AND last_activity_at < NOW() - INTERVAL '10 minutes';
    
  -- Also mark users as offline if their last_seen is more than 10 minutes ago
  UPDATE user_status
  SET is_online = false
  WHERE is_online = true
    AND last_seen < NOW() - INTERVAL '10 minutes';
END;
$$;

-- Create a function that can be called periodically to cleanup idle sessions
-- This will be called by the application or a scheduled job
COMMENT ON FUNCTION cleanup_idle_sessions IS 'Cleanup function to end idle sessions after 10 minutes of inactivity';
