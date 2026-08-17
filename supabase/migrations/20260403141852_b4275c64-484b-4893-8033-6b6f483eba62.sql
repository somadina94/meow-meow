
-- Fix function search_path with exact signatures
ALTER FUNCTION public.check_session_balance(uuid, text) SET search_path = public;
ALTER FUNCTION public.ensure_wallet_exists() SET search_path = public;
ALTER FUNCTION public.get_ledger_statement(uuid, timestamptz, timestamptz) SET search_path = public;
ALTER FUNCTION public.get_men_with_balance(uuid[]) SET search_path = public;
ALTER FUNCTION public.get_online_men_dashboard() SET search_path = public;
ALTER FUNCTION public.get_top_earner_today() SET search_path = public;
ALTER FUNCTION public.ledger_bill_group_call(uuid, uuid, uuid[], integer, numeric, numeric) SET search_path = public;
ALTER FUNCTION public.process_wallet_transaction(uuid, numeric, text, text, uuid, text) SET search_path = public;
ALTER FUNCTION public.r2(numeric) SET search_path = public;
ALTER FUNCTION public.reset_private_group_counts() SET search_path = public;

-- Fix group_memberships UPDATE policy
DROP POLICY IF EXISTS "System can update memberships" ON public.group_memberships;
CREATE POLICY "Owner or member can update memberships"
ON public.group_memberships
FOR UPDATE
TO authenticated
USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.private_groups pg
    WHERE pg.id = group_memberships.group_id
    AND pg.owner_id = auth.uid()
  )
);

-- Fix group_video_access INSERT policy
DROP POLICY IF EXISTS "System can insert video access" ON public.group_video_access;
CREATE POLICY "Auth users can insert video access"
ON public.group_video_access
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.private_groups pg
    WHERE pg.id = group_video_access.group_id
    AND pg.owner_id = auth.uid()
  )
);

-- Fix group_video_access UPDATE policy
DROP POLICY IF EXISTS "System can update video access" ON public.group_video_access;
CREATE POLICY "Owner or user can update video access"
ON public.group_video_access
FOR UPDATE
TO authenticated
USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.private_groups pg
    WHERE pg.id = group_video_access.group_id
    AND pg.owner_id = auth.uid()
  )
);

-- Fix translation_cache INSERT
DROP POLICY IF EXISTS "Authenticated users can insert translations" ON public.translation_cache;
CREATE POLICY "Authenticated users can insert translations"
ON public.translation_cache
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);

-- Fix translation_cache UPDATE
DROP POLICY IF EXISTS "Authenticated users can update cache hits" ON public.translation_cache;
CREATE POLICY "Authenticated users can update cache hits"
ON public.translation_cache
FOR UPDATE
TO authenticated
USING (auth.uid() IS NOT NULL)
WITH CHECK (auth.uid() IS NOT NULL);

-- Fix video_call_sessions INSERT (uses man_user_id/woman_user_id)
DROP POLICY IF EXISTS "Service can insert video calls" ON public.video_call_sessions;
CREATE POLICY "Participants can insert video calls"
ON public.video_call_sessions
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = man_user_id OR auth.uid() = woman_user_id);

-- Fix user_roles ALL policy
DROP POLICY IF EXISTS "user_roles_service_role_write" ON public.user_roles;
CREATE POLICY "Admin can manage user roles"
ON public.user_roles
FOR ALL
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
