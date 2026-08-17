-- Add RLS policies for password_reset_tokens table
-- This table should only be accessible by the system/service role for security

-- Policy: Allow system to insert tokens (for password reset requests)
CREATE POLICY "System can insert reset tokens" 
ON public.password_reset_tokens 
FOR INSERT 
WITH CHECK (true);

-- Policy: Allow system to select tokens (for verification)
CREATE POLICY "System can read reset tokens" 
ON public.password_reset_tokens 
FOR SELECT 
USING (true);

-- Policy: Allow system to update tokens (mark as used)
CREATE POLICY "System can update reset tokens" 
ON public.password_reset_tokens 
FOR UPDATE 
USING (true);

-- Policy: Allow system to delete expired tokens
CREATE POLICY "System can delete reset tokens" 
ON public.password_reset_tokens 
FOR DELETE 
USING (true);