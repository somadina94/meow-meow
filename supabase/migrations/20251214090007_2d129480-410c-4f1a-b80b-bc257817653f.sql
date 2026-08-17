-- Fix all 3 security issues with stronger RLS

-- 1. female_profiles - Only viewable by matched users or active chat participants
DROP POLICY IF EXISTS "Approved female profiles visible to authenticated users" ON public.female_profiles;
DROP POLICY IF EXISTS "Users can view their own female profile" ON public.female_profiles;

CREATE POLICY "Users can view own or matched female profiles"
ON public.female_profiles
FOR SELECT
USING (
  auth.uid() IS NOT NULL AND (
    -- Own profile
    user_id = auth.uid() OR
    -- Admin access
    has_role(auth.uid(), 'admin') OR
    -- Has active chat session with this user
    EXISTS (
      SELECT 1 FROM active_chat_sessions
      WHERE status = 'active' AND (
        (man_user_id = auth.uid() AND woman_user_id = female_profiles.user_id) OR
        (woman_user_id = auth.uid() AND man_user_id = female_profiles.user_id)
      )
    ) OR
    -- Has a match with this user
    EXISTS (
      SELECT 1 FROM matches
      WHERE status = 'accepted' AND (
        (user_id = auth.uid() AND matched_user_id = female_profiles.user_id) OR
        (matched_user_id = auth.uid() AND user_id = female_profiles.user_id)
      )
    )
  )
);

-- 2. chat_messages - Strengthen to only exact participants
DROP POLICY IF EXISTS "Users can view their own messages" ON public.chat_messages;

CREATE POLICY "Only chat participants can view messages"
ON public.chat_messages
FOR SELECT
USING (
  auth.uid() IS NOT NULL AND (
    sender_id = auth.uid() OR 
    receiver_id = auth.uid() OR
    has_role(auth.uid(), 'admin')
  )
);

-- 3. user_photos - Only viewable by owner, matched users, or chat participants
DROP POLICY IF EXISTS "Authenticated users can view photos" ON public.user_photos;
DROP POLICY IF EXISTS "Users can view their own photos" ON public.user_photos;

CREATE POLICY "Users can view own or matched user photos"
ON public.user_photos
FOR SELECT
USING (
  auth.uid() IS NOT NULL AND (
    -- Own photos
    user_id = auth.uid() OR
    -- Admin access
    has_role(auth.uid(), 'admin') OR
    -- Has active chat session
    EXISTS (
      SELECT 1 FROM active_chat_sessions
      WHERE status = 'active' AND (
        (man_user_id = auth.uid() AND woman_user_id = user_photos.user_id) OR
        (woman_user_id = auth.uid() AND man_user_id = user_photos.user_id)
      )
    ) OR
    -- Has match
    EXISTS (
      SELECT 1 FROM matches
      WHERE status = 'accepted' AND (
        (user_id = auth.uid() AND matched_user_id = user_photos.user_id) OR
        (matched_user_id = auth.uid() AND user_id = user_photos.user_id)
      )
    )
  )
);