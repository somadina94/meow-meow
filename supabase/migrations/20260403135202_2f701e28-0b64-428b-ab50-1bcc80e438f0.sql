
ALTER TABLE public.rate_limit_tracking ENABLE ROW LEVEL SECURITY;

-- Only allow the service role / security definer functions to access this table
-- No direct user access needed - check_rate_limit is SECURITY DEFINER
