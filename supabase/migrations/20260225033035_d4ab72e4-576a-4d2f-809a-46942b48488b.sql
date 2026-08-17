-- Drop and recreate the INSERT policy for video_call_sessions
-- to ensure authenticated users can insert when they are the man_user_id
DROP POLICY IF EXISTS "Men can insert video calls" ON video_call_sessions;

CREATE POLICY "Men can insert video calls" ON video_call_sessions
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = man_user_id);

-- Also add a policy for service role / anon to allow edge functions
DROP POLICY IF EXISTS "Service can insert video calls" ON video_call_sessions;

CREATE POLICY "Service can insert video calls" ON video_call_sessions
  FOR INSERT TO anon
  WITH CHECK (true);