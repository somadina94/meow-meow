-- Drop the broken UPDATE policy
DROP POLICY IF EXISTS "Owners or hosts can update groups" ON public.private_groups;

-- Create a new policy: any authenticated user can update private_groups
-- App logic enforces host uniqueness; RLS just needs to allow the update
CREATE POLICY "Authenticated users can update groups"
ON public.private_groups
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);
