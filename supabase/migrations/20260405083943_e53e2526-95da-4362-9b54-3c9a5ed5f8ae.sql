-- Drop the restrictive owner-only UPDATE policy
DROP POLICY IF EXISTS "Owners can update their groups" ON public.private_groups;

-- Create a new UPDATE policy that allows:
-- 1. The current host to update (e.g., stop live, update participant count)
-- 2. Any authenticated user to go live on a group that has no current host
-- 3. Admins can update anything
CREATE POLICY "Authenticated users can update groups"
ON public.private_groups
FOR UPDATE
TO authenticated
USING (
  auth.uid() = owner_id
  OR auth.uid() = current_host_id
  OR current_host_id IS NULL
  OR has_role(auth.uid(), 'admin'::app_role)
)
WITH CHECK (
  auth.uid() = owner_id
  OR auth.uid() = current_host_id
  OR current_host_id IS NULL
  OR has_role(auth.uid(), 'admin'::app_role)
);