-- Fix password_reset_tokens security: Remove all permissive policies
-- Only service_role should access this table (via edge functions)

DROP POLICY IF EXISTS "System can delete reset tokens" ON public.password_reset_tokens;
DROP POLICY IF EXISTS "System can insert reset tokens" ON public.password_reset_tokens;
DROP POLICY IF EXISTS "System can read reset tokens" ON public.password_reset_tokens;
DROP POLICY IF EXISTS "System can update reset tokens" ON public.password_reset_tokens;

-- The remaining policy "Only service role can access password reset tokens" 
-- with USING (false) will block all client access
-- Edge functions using service_role key bypass RLS entirely