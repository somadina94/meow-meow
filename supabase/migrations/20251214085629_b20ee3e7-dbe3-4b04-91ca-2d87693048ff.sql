-- Fix all security issues: Require authentication for sensitive tables

-- 1. Fix chat_pricing - already restricted to admins, ensure no public access
DROP POLICY IF EXISTS "Anyone can view pricing" ON public.chat_pricing;
DROP POLICY IF EXISTS "Public can view pricing" ON public.chat_pricing;

-- 2. Fix language_limits - require authentication
DROP POLICY IF EXISTS "Anyone can view language limits" ON public.language_limits;
CREATE POLICY "Authenticated users can view language limits"
ON public.language_limits
FOR SELECT
USING (auth.uid() IS NOT NULL);

-- 3. Fix language_groups - require authentication  
DROP POLICY IF EXISTS "Anyone can view active language groups" ON public.language_groups;
CREATE POLICY "Authenticated users can view active language groups"
ON public.language_groups
FOR SELECT
USING (auth.uid() IS NOT NULL AND is_active = true);

-- 4. Fix shift_templates - require authentication (add RLS if not exists)
ALTER TABLE IF EXISTS public.shift_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view shift templates" ON public.shift_templates;
DROP POLICY IF EXISTS "Public can view shift templates" ON public.shift_templates;
CREATE POLICY "Authenticated users can view shift templates"
ON public.shift_templates
FOR SELECT
USING (auth.uid() IS NOT NULL);

-- 5. Fix app_settings - restrict non-public settings to authenticated users
DROP POLICY IF EXISTS "Anyone can view public settings" ON public.app_settings;
CREATE POLICY "Authenticated users can view public settings"
ON public.app_settings
FOR SELECT
USING (auth.uid() IS NOT NULL AND is_public = true);

-- 6. Fix gifts - require authentication to view
DROP POLICY IF EXISTS "Anyone can view active gifts" ON public.gifts;
CREATE POLICY "Authenticated users can view active gifts"
ON public.gifts
FOR SELECT
USING (auth.uid() IS NOT NULL AND is_active = true);