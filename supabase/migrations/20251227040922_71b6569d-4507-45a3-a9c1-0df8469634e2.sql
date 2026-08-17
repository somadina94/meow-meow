
-- Data retention cleanup function
CREATE OR REPLACE FUNCTION cleanup_expired_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
END;
$$;

-- Media cleanup function (runs every 5 mins for files)
CREATE OR REPLACE FUNCTION cleanup_chat_media()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Clear file references from group messages older than 5 minutes
  UPDATE group_messages
  SET file_url = NULL,
      file_name = NULL,
      file_type = NULL,
      file_size = NULL
  WHERE file_url IS NOT NULL
    AND created_at < NOW() - INTERVAL '5 minutes';

  -- Clear file references from language community messages older than 5 minutes
  UPDATE language_community_messages
  SET file_url = NULL,
      file_name = NULL,
      file_type = NULL,
      file_size = NULL
  WHERE file_url IS NOT NULL
    AND created_at < NOW() - INTERVAL '5 minutes';
END;
$$;

-- Video call session cleanup (content available for 5 mins after end)
CREATE OR REPLACE FUNCTION cleanup_video_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Delete ended video sessions older than 5 minutes
  DELETE FROM video_call_sessions
  WHERE status = 'ended'
    AND ended_at < NOW() - INTERVAL '5 minutes';
END;
$$;

COMMENT ON FUNCTION cleanup_expired_data IS 'Main cleanup: 3min idle chats, 7day chat history, 9yr transactions';
COMMENT ON FUNCTION cleanup_chat_media IS 'Cleanup media files every 5 minutes';
COMMENT ON FUNCTION cleanup_video_sessions IS 'Cleanup video sessions 5 mins after end';
