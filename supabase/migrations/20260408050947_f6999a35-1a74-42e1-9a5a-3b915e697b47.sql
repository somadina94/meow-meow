
-- Fix the trigger to allow service_role, postgres, and supabase_admin
CREATE OR REPLACE FUNCTION public.prevent_direct_wallet_balance_update()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Allow if balance hasn't changed
  IF NEW.balance = OLD.balance THEN
    RETURN NEW;
  END IF;
  
  -- Allow service_role to update balance (used by atomic RPCs)
  IF current_setting('role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Allow postgres/superuser context (used by SECURITY DEFINER functions and migrations)
  IF current_user IN ('postgres', 'supabase_admin') THEN
    RETURN NEW;
  END IF;

  -- Allow if called from within a SECURITY DEFINER function context
  IF session_user IN ('postgres', 'supabase_admin', 'authenticator') THEN
    RETURN NEW;
  END IF;
  
  -- Block direct balance modifications from regular users
  RAISE EXCEPTION 'Direct wallet balance modification is not allowed. Use the provided payment functions.';
END;
$$;

-- Now re-run billing for all unbilled sessions
DO $$
DECLARE
  v_session record;
  v_result jsonb;
  v_call_type text;
BEGIN
  FOR v_session IN
    SELECT call_id, call_type
    FROM public.video_call_sessions
    WHERE status IN ('completed', 'ended')
      AND started_at IS NOT NULL
      AND ended_at IS NOT NULL
      AND (total_minutes = 0 OR total_minutes IS NULL)
      AND (total_earned = 0 OR total_earned IS NULL)
  LOOP
    v_call_type := COALESCE(v_session.call_type, 'video');
    SELECT public.process_call_billing(v_session.call_id, v_call_type) INTO v_result;
    RAISE NOTICE 'Billed %: %', v_session.call_id, v_result;
  END LOOP;
END;
$$;
