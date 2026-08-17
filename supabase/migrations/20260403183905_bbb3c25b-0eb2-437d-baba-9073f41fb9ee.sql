
-- 1. Fix private_groups UPDATE policy: remove zero-UUID bypass, add admin check
DROP POLICY IF EXISTS "Owners or hosts can update groups" ON public.private_groups;
CREATE POLICY "Owners or hosts can update groups" ON public.private_groups
FOR UPDATE TO authenticated
USING (
  (auth.uid() = owner_id)
  OR (auth.uid() = current_host_id)
  OR public.has_role(auth.uid(), 'admin')
);

-- 2. Fix voice-messages bucket: make private
UPDATE storage.buckets SET public = false WHERE id = 'voice-messages';

-- Drop public SELECT policy
DROP POLICY IF EXISTS "Anyone can view voice messages" ON storage.objects;

-- Add authenticated-only SELECT policy for voice-messages
CREATE POLICY "Authenticated users can view voice messages" ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'voice-messages');

-- 3. Fix chat-files bucket: make private
UPDATE storage.buckets SET public = false WHERE id = 'chat-files';

-- Drop public SELECT policy
DROP POLICY IF EXISTS "Public can view chat files" ON storage.objects;

-- Add authenticated-only SELECT policy for chat-files
CREATE POLICY "Authenticated users can view chat files" ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'chat-files');

-- 4. Add RLS policies for rate_limit_tracking
CREATE POLICY "Service role only for rate limiting" ON public.rate_limit_tracking
FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 5. Add RLS policies for password_reset_tokens
CREATE POLICY "Users can view own reset tokens" ON public.password_reset_tokens
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can create own reset tokens" ON public.password_reset_tokens
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);
