
-- Fix SECURITY DEFINER view issue - recreate as SECURITY INVOKER
DROP VIEW IF EXISTS public.public_profiles;

CREATE VIEW public.public_profiles
WITH (security_invoker = true)
AS
SELECT
  id,
  user_id,
  full_name,
  gender,
  age,
  bio,
  country,
  state,
  city,
  photo_url,
  primary_language,
  preferred_language,
  language,
  interests,
  life_goals,
  occupation,
  education_level,
  religion,
  marital_status,
  height_cm,
  body_type,
  zodiac_sign,
  personality_type,
  smoking_habit,
  drinking_habit,
  dietary_preference,
  fitness_level,
  pet_preference,
  travel_frequency,
  has_children,
  is_verified,
  is_premium,
  has_golden_badge,
  golden_badge_expires_at,
  account_status,
  approval_status,
  profile_completeness,
  last_active_at,
  created_at,
  updated_at,
  is_indian,
  is_earning_eligible,
  earning_badge_type,
  performance_score,
  avg_response_time_seconds,
  total_chats_count,
  monthly_chat_minutes,
  verification_status,
  promoted_from_free,
  ai_approved
FROM public.profiles;

-- Grant access
GRANT SELECT ON public.public_profiles TO authenticated;
GRANT SELECT ON public.public_profiles TO anon;

-- Since the view uses SECURITY INVOKER, we need a policy that allows
-- authenticated users to read profiles through the view (non-sensitive fields only)
-- The view itself filters columns, and this policy allows row access
CREATE POLICY "Authenticated users can read public profile fields" ON public.profiles
FOR SELECT TO authenticated
USING (true);
