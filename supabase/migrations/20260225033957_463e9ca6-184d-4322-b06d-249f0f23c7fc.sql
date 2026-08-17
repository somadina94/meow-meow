-- Clean up stale video call sessions older than 2 minutes that are still ringing/connecting
UPDATE video_call_sessions 
SET status = 'ended', 
    ended_at = now(), 
    end_reason = 'timeout_cleanup'
WHERE status IN ('ringing', 'connecting') 
AND created_at < now() - interval '2 minutes';