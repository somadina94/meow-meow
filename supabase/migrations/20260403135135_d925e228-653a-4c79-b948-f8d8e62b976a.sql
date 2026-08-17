
-- VID-C-01: Trigger to initialize billing when video call becomes active
CREATE OR REPLACE FUNCTION public.init_video_call_billing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rate NUMERIC;
BEGIN
  IF NEW.status = 'active' AND (OLD.status IS NULL OR OLD.status != 'active') THEN
    SELECT video_rate_per_minute INTO v_rate
    FROM chat_pricing WHERE is_active = true LIMIT 1;
    v_rate := COALESCE(v_rate, 8.0);
    IF NEW.rate_per_minute IS NULL OR NEW.rate_per_minute = 0 THEN
      NEW.rate_per_minute := v_rate;
    END IF;
    IF NEW.started_at IS NULL THEN
      NEW.started_at := now();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_init_video_billing ON public.video_call_sessions;
CREATE TRIGGER trg_init_video_billing
  BEFORE UPDATE ON public.video_call_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.init_video_call_billing();

-- TEC-H-03: Rate limiting infrastructure
CREATE TABLE IF NOT EXISTS public.rate_limit_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  function_name TEXT NOT NULL,
  request_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rate_limit_user_func 
  ON public.rate_limit_tracking (user_id, function_name, request_at DESC);

CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_user_id UUID,
  p_function_name TEXT,
  p_max_requests INT DEFAULT 10,
  p_window_seconds INT DEFAULT 60
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  DELETE FROM rate_limit_tracking 
  WHERE user_id = p_user_id 
    AND function_name = p_function_name
    AND request_at < now() - (p_window_seconds || ' seconds')::interval;
  
  SELECT COUNT(*) INTO v_count
  FROM rate_limit_tracking
  WHERE user_id = p_user_id
    AND function_name = p_function_name
    AND request_at > now() - (p_window_seconds || ' seconds')::interval;
  
  IF v_count >= p_max_requests THEN
    RETURN FALSE;
  END IF;
  
  INSERT INTO rate_limit_tracking (user_id, function_name)
  VALUES (p_user_id, p_function_name);
  
  RETURN TRUE;
END;
$$;

-- TEC-H-02: Ensure RLS on active_chat_sessions covers all statuses
-- Using CREATE POLICY IF NOT EXISTS pattern
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'active_chat_sessions' 
    AND policyname = 'Participants can view own sessions'
  ) THEN
    CREATE POLICY "Participants can view own sessions"
      ON public.active_chat_sessions FOR SELECT TO authenticated
      USING (man_user_id = auth.uid() OR woman_user_id = auth.uid());
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'active_chat_sessions' 
    AND policyname = 'Participants can update own sessions'
  ) THEN
    CREATE POLICY "Participants can update own sessions"
      ON public.active_chat_sessions FOR UPDATE TO authenticated
      USING (man_user_id = auth.uid() OR woman_user_id = auth.uid());
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'active_chat_sessions' 
    AND policyname = 'Participants can insert own sessions'
  ) THEN
    CREATE POLICY "Participants can insert own sessions"
      ON public.active_chat_sessions FOR INSERT TO authenticated
      WITH CHECK (man_user_id = auth.uid() OR woman_user_id = auth.uid());
  END IF;
END $$;
