-- Fix female_profiles security: Require authentication to view profiles
DROP POLICY IF EXISTS "Approved female profiles visible to authenticated users" ON public.female_profiles;

-- Recreate with proper authentication check
CREATE POLICY "Approved female profiles visible to authenticated users"
ON public.female_profiles
FOR SELECT
USING (
  auth.uid() IS NOT NULL AND (
    user_id = auth.uid() OR 
    (approval_status = 'approved' AND account_status = 'active') OR 
    has_role(auth.uid(), 'admin')
  )
);