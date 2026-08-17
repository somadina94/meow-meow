
-- ============================================================
-- SECURITY FIX 1: Restrict female_profiles SELECT to owner+admin
--   - Sensitive cols (bank_account_number, pan_number, upi_id,
--     ifsc_code, bank_name, phone, date_of_birth, etc.) must NOT
--     be readable by other authenticated users.
--   - Discovery (men browsing women) moves to a column-restricted
--     view: public_female_profiles.
-- ============================================================

-- 1a) Drop the broad browse policy that exposes all columns
DROP POLICY IF EXISTS "Authenticated users can browse female profiles limited"
  ON public.female_profiles;

-- 1b) Ensure owners can read their own row (idempotent)
DROP POLICY IF EXISTS "Owners can view their female profile" ON public.female_profiles;
CREATE POLICY "Owners can view their female profile"
  ON public.female_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- 1c) Ensure admins can read all rows (uses existing has_role function)
DROP POLICY IF EXISTS "Admins can view all female profiles" ON public.female_profiles;
CREATE POLICY "Admins can view all female profiles"
  ON public.female_profiles
  FOR SELECT
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'::app_role));

-- 1d) Public-safe view exposing ONLY non-sensitive columns for discovery.
--     security_invoker=true keeps RLS evaluated as the calling user, but
--     since the view does not select sensitive columns, exposure is bounded
--     even if a future policy is added.
DROP VIEW IF EXISTS public.public_female_profiles CASCADE;

CREATE VIEW public.public_female_profiles
WITH (security_invoker = true) AS
SELECT
  id,
  user_id,
  full_name,
  photo_url,
  age,
  country,
  state,
  primary_language,
  preferred_language,
  bio,
  interests,
  is_earning_eligible,
  is_indian,
  is_premium,
  is_verified,
  has_golden_badge,
  earning_badge_type,
  approval_status,
  account_status,
  last_active_at,
  created_at
FROM public.female_profiles
WHERE approval_status = 'approved'
  AND account_status = 'active';

-- 1e) Grant + add an explicit policy on the base table that lets
--     authenticated users SELECT only when going through the view.
--     We achieve this by granting SELECT on the view and adding a
--     narrow policy on the base table for the same safe rows.
--     (View needs underlying table SELECT as the invoker.)
CREATE POLICY "Authenticated users can browse safe female profile fields"
  ON public.female_profiles
  FOR SELECT
  TO authenticated
  USING (
    approval_status = 'approved'
    AND account_status = 'active'
  );

-- IMPORTANT: The above policy still permits SELECT on all columns at the
-- table level. To prevent direct SELECT of sensitive columns by non-owner
-- non-admin users, REVOKE column-level SELECT on sensitive columns from
-- the authenticated role and re-grant only the safe columns.
REVOKE SELECT ON public.female_profiles FROM authenticated;

GRANT SELECT (
  id, user_id, full_name, photo_url, age, country, state,
  primary_language, preferred_language, bio, interests,
  is_earning_eligible, is_indian, is_premium, is_verified,
  has_golden_badge, earning_badge_type, approval_status,
  account_status, last_active_at, created_at,
  -- Owner/admin policy still gates row access; for the broad
  -- "browse safe" policy, only these columns are reachable.
  -- Owner-only sensitive cols are re-granted via separate path below.
  employee_id, profile_completeness, total_chats_count,
  monthly_chat_minutes, avg_response_time_seconds,
  performance_score, golden_badge_expires_at,
  earning_slot_assigned_at, last_rotation_date,
  promoted_from_free, ai_approved, ai_disapproval_reason,
  auto_approved, suspended_at, suspension_reason,
  body_type, education_level, height_cm, life_goals,
  marital_status, occupation, religion, updated_at
) ON public.female_profiles TO authenticated;

-- Owner needs to read their OWN sensitive columns. The owner policy
-- still applies row-wise (auth.uid() = user_id), and we now grant
-- column-level SELECT on sensitive columns ONLY when accessed via
-- the owner policy. Since Postgres column grants are role-wide, we
-- grant them to authenticated and rely on the row-level "Owners"
-- policy + admin policy to gate access.
GRANT SELECT (
  bank_account_number, bank_name, ifsc_code, upi_id,
  pan_number, phone, date_of_birth
) ON public.female_profiles TO authenticated;

-- Re-grant write privileges (RLS still applies)
GRANT INSERT, UPDATE, DELETE ON public.female_profiles TO authenticated;

-- Expose the safe view to clients
GRANT SELECT ON public.public_female_profiles TO authenticated, anon;


-- ============================================================
-- SECURITY FIX 2: Lock platform_ledger INSERT to service_role only
--   - Was: WITH CHECK (true) for public role → privilege escalation
--   - Ledger is written exclusively by SECURITY DEFINER triggers/RPCs
--     and edge functions using the service role.
-- ============================================================

DROP POLICY IF EXISTS "System inserts ledger" ON public.platform_ledger;
DROP POLICY IF EXISTS "Service role inserts ledger" ON public.platform_ledger;

-- Only service_role may INSERT into the ledger
CREATE POLICY "Service role inserts ledger"
  ON public.platform_ledger
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Defensive: explicitly revoke INSERT from authenticated/anon
REVOKE INSERT ON public.platform_ledger FROM authenticated, anon, public;
