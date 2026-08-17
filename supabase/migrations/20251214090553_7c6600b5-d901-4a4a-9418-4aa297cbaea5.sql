-- Fix all 3 security issues: Restrict sensitive data access

-- 1. Update profiles RLS - Only owner sees full data, others get limited view via function
DROP POLICY IF EXISTS "Users can view own full profile" ON public.profiles;

CREATE POLICY "Only owner sees own full profile"
ON public.profiles
FOR SELECT
USING (auth.uid() = user_id OR has_role(auth.uid(), 'admin'));

-- 2. Create secure function for limited profile data (no phone, no coordinates, no DOB)
CREATE OR REPLACE FUNCTION public.get_matched_profile(target_user_id uuid)
RETURNS TABLE(
  id uuid,
  full_name text,
  age integer,
  state text,
  country text,
  bio text,
  photo_url text,
  gender text,
  interests text[],
  occupation text,
  is_verified boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify caller has active chat or match with target
  IF NOT (
    EXISTS (
      SELECT 1 FROM active_chat_sessions
      WHERE status = 'active' AND (
        (man_user_id = auth.uid() AND woman_user_id = target_user_id) OR
        (woman_user_id = auth.uid() AND man_user_id = target_user_id)
      )
    ) OR
    EXISTS (
      SELECT 1 FROM matches
      WHERE status = 'accepted' AND (
        (user_id = auth.uid() AND matched_user_id = target_user_id) OR
        (matched_user_id = auth.uid() AND user_id = target_user_id)
      )
    )
  ) THEN
    RETURN; -- Return empty if no relationship
  END IF;

  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.age,
    p.state,
    p.country,
    p.bio,
    p.photo_url,
    p.gender,
    p.interests,
    p.occupation,
    p.is_verified
  FROM profiles p
  WHERE p.user_id = target_user_id;
END;
$$;

-- 3. Fix female_profiles - Only owner sees phone, matched users get limited data
DROP POLICY IF EXISTS "Users can view own or matched female profiles" ON public.female_profiles;

CREATE POLICY "Owner sees own female profile"
ON public.female_profiles
FOR SELECT
USING (auth.uid() = user_id OR has_role(auth.uid(), 'admin'));

-- Create secure function for female profile without phone
CREATE OR REPLACE FUNCTION public.get_matched_female_profile(target_user_id uuid)
RETURNS TABLE(
  id uuid,
  full_name text,
  age integer,
  state text,
  country text,
  bio text,
  photo_url text,
  interests text[],
  occupation text,
  is_verified boolean,
  approval_status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify caller has active chat or match
  IF NOT (
    EXISTS (
      SELECT 1 FROM active_chat_sessions
      WHERE status = 'active' AND (
        (man_user_id = auth.uid() AND woman_user_id = target_user_id) OR
        (woman_user_id = auth.uid() AND man_user_id = target_user_id)
      )
    ) OR
    EXISTS (
      SELECT 1 FROM matches
      WHERE status = 'accepted' AND (
        (user_id = auth.uid() AND matched_user_id = target_user_id) OR
        (matched_user_id = auth.uid() AND user_id = target_user_id)
      )
    )
  ) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 
    fp.id,
    fp.full_name,
    fp.age,
    fp.state,
    fp.country,
    fp.bio,
    fp.photo_url,
    fp.interests,
    fp.occupation,
    fp.is_verified,
    fp.approval_status
  FROM female_profiles fp
  WHERE fp.user_id = target_user_id
  AND fp.approval_status = 'approved'
  AND fp.account_status = 'active';
END;
$$;

-- 4. Fix wallets - Strictly owner only (remove any admin loophole for balance viewing)
DROP POLICY IF EXISTS "Users can view their own wallet" ON public.wallets;
DROP POLICY IF EXISTS "Admins can view all wallets" ON public.wallets;

CREATE POLICY "Only owner can view wallet"
ON public.wallets
FOR SELECT
USING (auth.uid() = user_id);

-- Admins can update but not casually view all balances
CREATE POLICY "Admins can manage wallets"
ON public.wallets
FOR UPDATE
USING (has_role(auth.uid(), 'admin'));

-- Grant execute on new functions
GRANT EXECUTE ON FUNCTION public.get_matched_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_matched_female_profile(uuid) TO authenticated;