
-- Sync existing approved women to female_profiles
INSERT INTO public.female_profiles (
  user_id, full_name, age, country, state,
  primary_language, preferred_language, bio,
  approval_status, ai_approved, auto_approved, account_status,
  photo_url, profile_completeness, performance_score
)
SELECT 
  p.user_id, p.full_name, p.age, p.country, p.state,
  p.primary_language, p.preferred_language, p.bio,
  p.approval_status, p.ai_approved, true, p.account_status,
  p.photo_url, p.profile_completeness, COALESCE(p.performance_score, 100)
FROM profiles p
WHERE p.gender = 'female' 
  AND p.approval_status = 'approved'
  AND NOT EXISTS (
    SELECT 1 FROM female_profiles fp WHERE fp.user_id = p.user_id
  );

-- Create women_availability entries for approved women
INSERT INTO public.women_availability (
  user_id, is_available, is_available_for_calls,
  current_chat_count, current_call_count,
  max_concurrent_chats, max_concurrent_calls
)
SELECT 
  p.user_id, true, true, 0, 0, 3, 1
FROM profiles p
WHERE p.gender = 'female' 
  AND p.approval_status = 'approved'
  AND NOT EXISTS (
    SELECT 1 FROM women_availability wa WHERE wa.user_id = p.user_id
  );
