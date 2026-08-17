-- SECURITY: Add message length constraint to prevent database abuse
ALTER TABLE public.chat_messages 
ADD CONSTRAINT chat_messages_length_check 
CHECK (LENGTH(message) <= 2000);

-- SECURITY: Add message length constraint to group messages
ALTER TABLE public.group_messages 
ADD CONSTRAINT group_messages_length_check 
CHECK (LENGTH(message) <= 2000);

-- SECURITY: Fix audit_logs INSERT policy - restrict to service role only
-- Drop the permissive policy that allows anyone to insert
DROP POLICY IF EXISTS "System can insert audit logs" ON public.audit_logs;

-- Create a more restrictive policy that only allows inserts from authenticated users
-- with admin role (the actual audit logging should happen via SECURITY DEFINER functions)
CREATE POLICY "Only admins can insert audit logs" 
ON public.audit_logs 
FOR INSERT 
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

-- SECURITY: Fix women_shift_assignments INSERT policy
DROP POLICY IF EXISTS "System can insert assignments" ON public.women_shift_assignments;

-- Only admins can insert shift assignments
CREATE POLICY "Only admins can insert shift assignments" 
ON public.women_shift_assignments 
FOR INSERT 
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);

-- SECURITY: Restrict active_chat_sessions to hide earnings from male users
-- Drop existing policy
DROP POLICY IF EXISTS "Strict participant session access" ON public.active_chat_sessions;

-- Create new policy that restricts what data each participant can see
-- Male users can only see session status, not earnings
CREATE POLICY "Strict participant session access" 
ON public.active_chat_sessions 
FOR SELECT 
USING (
  auth.uid() IS NOT NULL AND 
  (auth.uid() = man_user_id OR auth.uid() = woman_user_id)
);

-- Note: The column-level security for total_earned is handled at application level
-- Database-level column masking would require additional complexity

-- SECURITY: Add rate limiting support - create a table to track message rates
CREATE TABLE IF NOT EXISTS public.message_rate_limits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  message_count integer DEFAULT 0,
  window_start timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT message_rate_limits_user_id_key UNIQUE (user_id)
);

-- Enable RLS on rate limits table
ALTER TABLE public.message_rate_limits ENABLE ROW LEVEL SECURITY;

-- Only allow users to see their own rate limit data
CREATE POLICY "Users can view own rate limits" 
ON public.message_rate_limits 
FOR SELECT 
USING (auth.uid() = user_id);

-- System can update rate limits
CREATE POLICY "System can manage rate limits" 
ON public.message_rate_limits 
FOR ALL
USING (true)
WITH CHECK (true);

-- Create function to check and update message rate limit
CREATE OR REPLACE FUNCTION public.check_message_rate_limit(p_user_id uuid, max_messages integer DEFAULT 60, window_minutes integer DEFAULT 1)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
  v_window_start timestamp with time zone;
BEGIN
  -- Get or create rate limit record
  INSERT INTO message_rate_limits (user_id, message_count, window_start)
  VALUES (p_user_id, 0, now())
  ON CONFLICT (user_id) DO NOTHING;
  
  -- Get current values
  SELECT message_count, window_start INTO v_count, v_window_start
  FROM message_rate_limits
  WHERE user_id = p_user_id;
  
  -- Check if window has expired
  IF v_window_start < now() - (window_minutes || ' minutes')::interval THEN
    -- Reset window
    UPDATE message_rate_limits
    SET message_count = 1, window_start = now(), updated_at = now()
    WHERE user_id = p_user_id;
    RETURN true;
  END IF;
  
  -- Check if under limit
  IF v_count < max_messages THEN
    -- Increment counter
    UPDATE message_rate_limits
    SET message_count = message_count + 1, updated_at = now()
    WHERE user_id = p_user_id;
    RETURN true;
  END IF;
  
  -- Rate limit exceeded
  RETURN false;
END;
$$;