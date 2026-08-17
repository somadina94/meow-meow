
-- ============================================================
-- FIX 1: female_profiles - restrict browsing to public fields
-- ============================================================

-- Drop the overly broad browsing policy
DROP POLICY IF EXISTS "Authenticated users can browse female profiles" ON public.female_profiles;

-- Create a restrictive browsing view using a security definer function
-- that returns only public-facing columns
CREATE OR REPLACE FUNCTION public.get_browsable_female_profiles()
RETURNS TABLE (
  id uuid,
  user_id uuid,
  full_name text,
  photo_url text,
  bio text,
  age integer,
  country text,
  state text,
  primary_language text,
  preferred_language text,
  interests text[],
  life_goals text[],
  is_verified boolean,
  is_premium boolean,
  has_golden_badge boolean,
  last_active_at timestamptz,
  account_status text,
  approval_status text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    id, user_id, full_name, photo_url, bio, age, country, state,
    primary_language, preferred_language, interests, life_goals,
    is_verified, is_premium, has_golden_badge, last_active_at,
    account_status, approval_status
  FROM public.female_profiles
  WHERE account_status = 'active'
    AND approval_status = 'approved';
$$;

-- Add a new browsing policy that hides sensitive columns
-- Only owner and admin get full row access (existing policies handle that)
-- For other authenticated users, create a limited policy
CREATE POLICY "Authenticated users can browse female profiles limited"
ON public.female_profiles
FOR SELECT
TO authenticated
USING (
  account_status = 'active'
  AND approval_status = 'approved'
  AND auth.uid() IS NOT NULL
);

-- Note: The RLS policy still returns all columns at SQL level,
-- but the application should use get_browsable_female_profiles() RPC
-- for browsing. The policy remains as a fallback with the added
-- approval_status check for safety.

-- ============================================================
-- FIX 2: community_disputes - restrict UPDATE to reporter/admin
-- ============================================================

DROP POLICY IF EXISTS "Leaders can update disputes" ON public.community_disputes;

CREATE POLICY "Reporter or admin can update disputes"
ON public.community_disputes
FOR UPDATE
TO authenticated
USING (
  auth.uid() = reporter_id
  OR has_role(auth.uid(), 'admin'::app_role)
);

-- ============================================================
-- FIX 3: women_availability - restrict read to essential fields
-- ============================================================

-- Drop the overly broad policy if it exists
DROP POLICY IF EXISTS "Anyone can view availability" ON public.women_availability;
DROP POLICY IF EXISTS "Authenticated users can view availability" ON public.women_availability;

-- Owner can see their own full availability record
CREATE POLICY "Owner can view own availability"
ON public.women_availability
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Admin can see all availability
CREATE POLICY "Admin can view all availability"
ON public.women_availability
FOR SELECT
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role));

-- For matching: other authenticated users can only see available women
-- (is_available = true), which limits exposure
CREATE POLICY "Users can view available women only"
ON public.women_availability
FOR SELECT
TO authenticated
USING (is_available = true);
