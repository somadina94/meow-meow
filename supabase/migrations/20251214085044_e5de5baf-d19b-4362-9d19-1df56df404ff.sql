-- Fix chat_pricing security: Only admins should see full pricing details
-- Remove public access policy for authenticated users

DROP POLICY IF EXISTS "Authenticated users can view active pricing" ON public.chat_pricing;

-- Keep only admin access policies (already exist):
-- "Admins can view all pricing" with USING (true) - this is for admin role
-- "Admins can update pricing" 
-- "Admins can insert pricing"
-- "Admins can delete pricing"

-- Create a secure function for clients to get only their applicable rate
CREATE OR REPLACE FUNCTION public.get_current_chat_rate()
RETURNS TABLE(chat_rate numeric, video_rate numeric, currency text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT rate_per_minute, video_rate_per_minute, currency
  FROM public.chat_pricing
  WHERE is_active = true
  LIMIT 1;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.get_current_chat_rate() TO authenticated;