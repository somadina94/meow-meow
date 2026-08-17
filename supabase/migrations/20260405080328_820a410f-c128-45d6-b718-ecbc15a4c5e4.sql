
-- 1. Fix push_subscriptions: remove public read, restrict to owner
DROP POLICY IF EXISTS "Service can read all subscriptions" ON public.push_subscriptions;
CREATE POLICY "Users can read own subscriptions"
  ON public.push_subscriptions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- 2. Fix private_groups: restrict updates to owner only
DROP POLICY IF EXISTS "Authenticated users can update groups" ON public.private_groups;
CREATE POLICY "Owners can update their groups"
  ON public.private_groups FOR UPDATE
  TO authenticated
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- 3. Fix community_disputes: restrict to involved parties + admins
DROP POLICY IF EXISTS "Authenticated users can view disputes" ON public.community_disputes;
CREATE POLICY "Users can view own disputes"
  ON public.community_disputes FOR SELECT
  TO authenticated
  USING (
    auth.uid() = reporter_id
    OR auth.uid() = reported_user_id
    OR public.has_role(auth.uid(), 'admin')
  );

-- 4. Fix user_status: require authentication
DROP POLICY IF EXISTS "Users can view all statuses" ON public.user_status;
CREATE POLICY "Authenticated users can view statuses"
  ON public.user_status FOR SELECT
  TO authenticated
  USING (true);

-- 5. Fix chat-files storage: restrict to folder owner
DROP POLICY IF EXISTS "Authenticated users can view chat files" ON storage.objects;
CREATE POLICY "Chat participants can view chat files"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'chat-files' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 6. Fix voice-messages storage: restrict to folder owner
DROP POLICY IF EXISTS "Authenticated users can view voice messages" ON storage.objects;
CREATE POLICY "Voice message participants can view messages"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'voice-messages' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 7. Fix admin_revenue_transactions: deny inserts from regular users
DROP POLICY IF EXISTS "System can insert admin revenue" ON public.admin_revenue_transactions;
CREATE POLICY "Only service role can insert admin revenue"
  ON public.admin_revenue_transactions FOR INSERT
  TO service_role
  WITH CHECK (true);
