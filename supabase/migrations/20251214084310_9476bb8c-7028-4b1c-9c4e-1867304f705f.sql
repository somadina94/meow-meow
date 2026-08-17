-- ============================================================================
-- SECURITY FIX: Tighten RLS policies for sensitive tables
-- ============================================================================

-- 1. FIX: password_reset_tokens - Remove all public access (CRITICAL)
-- Drop existing overly permissive policies
DROP POLICY IF EXISTS "Anyone can view password reset tokens" ON public.password_reset_tokens;
DROP POLICY IF EXISTS "Users can view their password reset tokens" ON public.password_reset_tokens;
DROP POLICY IF EXISTS "Public can view tokens" ON public.password_reset_tokens;

-- Only allow service role to access password_reset_tokens (no public SELECT)
-- Users should never be able to see these tokens directly
CREATE POLICY "Only service role can access password reset tokens"
ON public.password_reset_tokens
FOR ALL
USING (false)
WITH CHECK (false);

-- 2. FIX: user_status - Restrict to authenticated users viewing relevant statuses
DROP POLICY IF EXISTS "Users can view all online statuses" ON public.user_status;
DROP POLICY IF EXISTS "Anyone can view online statuses" ON public.user_status;

-- Only authenticated users can view status of users they're chatting with or matched with
CREATE POLICY "Authenticated users can view statuses of connections"
ON public.user_status
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM public.active_chat_sessions
        WHERE status = 'active'
        AND (man_user_id = auth.uid() AND woman_user_id = user_status.user_id
             OR woman_user_id = auth.uid() AND man_user_id = user_status.user_id)
    )
    OR EXISTS (
        SELECT 1 FROM public.matches
        WHERE status = 'active'
        AND (user_id = auth.uid() AND matched_user_id = user_status.user_id
             OR matched_user_id = auth.uid() AND user_id = user_status.user_id)
    )
    OR public.has_role(auth.uid(), 'admin')
);

-- 3. FIX: user_photos - Restrict to authenticated users only
DROP POLICY IF EXISTS "Anyone can view user photos" ON public.user_photos;
DROP POLICY IF EXISTS "Public can view user photos" ON public.user_photos;

-- Only authenticated users can view photos
CREATE POLICY "Authenticated users can view photos"
ON public.user_photos
FOR SELECT
TO authenticated
USING (true);

-- 4. FIX: women_availability - Restrict to authenticated users and admins
DROP POLICY IF EXISTS "Anyone can view availability" ON public.women_availability;
DROP POLICY IF EXISTS "Public can view availability" ON public.women_availability;

-- Only authenticated users can view availability (needed for matching)
CREATE POLICY "Authenticated users can view women availability"
ON public.women_availability
FOR SELECT
TO authenticated
USING (
    -- Women can see their own availability
    user_id = auth.uid()
    -- Men can see availability for matching
    OR EXISTS (
        SELECT 1 FROM public.profiles
        WHERE user_id = auth.uid()
        AND LOWER(gender) = 'male'
    )
    -- Admins can see all
    OR public.has_role(auth.uid(), 'admin')
);

-- 5. FIX: female_profiles - Remove phone from visible columns, tighten access
-- First, let's update the select policy to be more restrictive
DROP POLICY IF EXISTS "Approved women visible to authenticated users" ON public.female_profiles;

-- Create a more restrictive policy
CREATE POLICY "Approved female profiles visible to authenticated users"
ON public.female_profiles
FOR SELECT
TO authenticated
USING (
    -- User can see their own profile
    user_id = auth.uid()
    -- Approved profiles visible to authenticated users (but RLS can't filter columns)
    OR (approval_status = 'approved' AND account_status = 'active')
    -- Admins can see all
    OR public.has_role(auth.uid(), 'admin')
);

-- 6. FIX: chat_pricing - Restrict to authenticated users only
DROP POLICY IF EXISTS "Anyone can view active pricing" ON public.chat_pricing;
DROP POLICY IF EXISTS "Public can view pricing" ON public.chat_pricing;
DROP POLICY IF EXISTS "Chat pricing is publicly readable" ON public.chat_pricing;

-- Only authenticated users can view pricing
CREATE POLICY "Authenticated users can view active pricing"
ON public.chat_pricing
FOR SELECT
TO authenticated
USING (is_active = true OR public.has_role(auth.uid(), 'admin'));

-- ============================================================================
-- Additional security hardening
-- ============================================================================

-- Ensure user_roles table has proper policies
DROP POLICY IF EXISTS "Users can view their own roles" ON public.user_roles;
DROP POLICY IF EXISTS "Admins can manage roles" ON public.user_roles;

CREATE POLICY "Users can view their own roles"
ON public.user_roles
FOR SELECT
TO authenticated
USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Only admins can insert roles"
ON public.user_roles
FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Only admins can update roles"
ON public.user_roles
FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Only admins can delete roles"
ON public.user_roles
FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));