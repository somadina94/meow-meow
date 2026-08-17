-- Fix profiles and chat_messages security

-- 1. Profiles - Create secure function to get limited profile data for matched users
CREATE OR REPLACE FUNCTION public.get_safe_profile(target_user_id uuid)
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
  occupation text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
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
    p.occupation
  FROM profiles p
  WHERE p.user_id = target_user_id
  AND (
    -- Own profile - full access handled elsewhere
    target_user_id = auth.uid() OR
    -- Has active chat or match
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
  );
$$;

GRANT EXECUTE ON FUNCTION public.get_safe_profile(uuid) TO authenticated;

-- 2. Update profiles RLS - Only owner and admin see full data including phone
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Matched users can view profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;

-- Owner sees their own full profile
CREATE POLICY "Users can view own full profile"
ON public.profiles
FOR SELECT
USING (auth.uid() = user_id);

-- Admins see all profiles
CREATE POLICY "Admins can view all profiles"
ON public.profiles
FOR SELECT
USING (has_role(auth.uid(), 'admin'));

-- 3. Chat messages - Add audit trigger for admin access
CREATE OR REPLACE FUNCTION public.audit_admin_message_access()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Log admin access to chat messages
  IF has_role(auth.uid(), 'admin') AND 
     auth.uid() != NEW.sender_id AND 
     auth.uid() != NEW.receiver_id THEN
    INSERT INTO audit_logs (
      admin_id, 
      action, 
      resource_type, 
      resource_id, 
      action_type,
      details
    ) VALUES (
      auth.uid(),
      'view_message',
      'chat_messages',
      NEW.id::text,
      'read',
      'Admin accessed private message'
    );
  END IF;
  RETURN NEW;
END;
$$;

-- Note: Trigger on SELECT not supported, audit via application layer instead