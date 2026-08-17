-- Comprehensive fix for all public access issues

-- 1. chat_pricing - Remove ALL public policies, keep only admin access
DROP POLICY IF EXISTS "Admins can view all pricing" ON public.chat_pricing;
DROP POLICY IF EXISTS "Anyone can view pricing" ON public.chat_pricing;
DROP POLICY IF EXISTS "Public can view pricing" ON public.chat_pricing;
DROP POLICY IF EXISTS "Users can view pricing" ON public.chat_pricing;

-- Only admins can see full pricing
CREATE POLICY "Only admins can view pricing"
ON public.chat_pricing
FOR SELECT
USING (has_role(auth.uid(), 'admin'));

-- 2. gifts - Require authentication
DROP POLICY IF EXISTS "Authenticated users can view active gifts" ON public.gifts;
DROP POLICY IF EXISTS "Anyone can view gifts" ON public.gifts;
DROP POLICY IF EXISTS "Public can view gifts" ON public.gifts;

CREATE POLICY "Auth users can view active gifts"
ON public.gifts
FOR SELECT
USING (auth.uid() IS NOT NULL AND is_active = true);

-- 3. app_settings - Only authenticated users, and only truly public settings
DROP POLICY IF EXISTS "Authenticated users can view public settings" ON public.app_settings;
DROP POLICY IF EXISTS "Anyone can view public settings" ON public.app_settings;
DROP POLICY IF EXISTS "Public can view settings" ON public.app_settings;

CREATE POLICY "Auth users can view public settings"
ON public.app_settings
FOR SELECT
USING (auth.uid() IS NOT NULL AND is_public = true);

-- 4. language_limits - Admin only (operational data)
DROP POLICY IF EXISTS "Authenticated users can view language limits" ON public.language_limits;
DROP POLICY IF EXISTS "Anyone can view language limits" ON public.language_limits;
DROP POLICY IF EXISTS "Public can view limits" ON public.language_limits;

CREATE POLICY "Only admins can view language limits"
ON public.language_limits
FOR SELECT
USING (has_role(auth.uid(), 'admin'));