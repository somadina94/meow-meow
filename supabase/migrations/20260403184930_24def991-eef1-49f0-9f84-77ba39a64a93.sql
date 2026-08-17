
-- Drop the view approach
DROP VIEW IF EXISTS public.public_profiles;

-- Create RPC for fetching multiple public profiles (for browsing/matching)
CREATE OR REPLACE FUNCTION public.get_public_profiles(user_ids uuid[] DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  full_name text,
  gender text,
  age integer,
  bio text,
  country text,
  state text,
  city text,
  photo_url text,
  primary_language text,
  preferred_language text,
  language text,
  interests text[],
  life_goals text[],
  occupation text,
  education_level text,
  religion text,
  marital_status text,
  height_cm integer,
  body_type text,
  is_verified boolean,
  is_premium boolean,
  has_golden_badge boolean,
  golden_badge_expires_at timestamp with time zone,
  account_status text,
  approval_status text,
  profile_completeness integer,
  last_active_at timestamp with time zone,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  is_indian boolean,
  is_earning_eligible boolean,
  earning_badge_type text,
  performance_score numeric,
  avg_response_time_seconds numeric,
  total_chats_count integer,
  monthly_chat_minutes integer,
  verification_status boolean,
  promoted_from_free boolean,
  ai_approved boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.id, p.user_id, p.full_name, p.gender, p.age, p.bio,
    p.country, p.state, p.city, p.photo_url,
    p.primary_language, p.preferred_language, p.language,
    p.interests, p.life_goals, p.occupation, p.education_level,
    p.religion, p.marital_status, p.height_cm, p.body_type,
    p.is_verified, p.is_premium, p.has_golden_badge, p.golden_badge_expires_at,
    p.account_status, p.approval_status, p.profile_completeness,
    p.last_active_at, p.created_at, p.updated_at,
    p.is_indian, p.is_earning_eligible, p.earning_badge_type,
    p.performance_score, p.avg_response_time_seconds,
    p.total_chats_count, p.monthly_chat_minutes,
    p.verification_status, p.promoted_from_free, p.ai_approved
  FROM public.profiles p
  WHERE (user_ids IS NULL OR p.user_id = ANY(user_ids))
    AND auth.uid() IS NOT NULL;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.get_public_profiles(uuid[]) TO authenticated;
