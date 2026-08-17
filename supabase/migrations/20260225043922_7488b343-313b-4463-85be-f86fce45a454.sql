
-- Drop the old restrictive update policy
DROP POLICY IF EXISTS "Owners can update their groups" ON public.private_groups;

-- Create a new policy that allows owners OR current hosts to update
CREATE POLICY "Owners or hosts can update groups"
  ON public.private_groups FOR UPDATE
  USING (auth.uid() = owner_id OR auth.uid() = current_host_id OR owner_id = '00000000-0000-0000-0000-000000000000'::uuid)
  WITH CHECK (true);
