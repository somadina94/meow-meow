-- Enable users to manage their own block relationships
-- Existing policy already allows users to see blocks where they are the blocked_user_id.
-- These policies add support for viewing/creating/deleting blocks where the user is the blocker.

CREATE POLICY "Users can view blocks they created"
ON public.user_blocks
FOR SELECT
USING (auth.uid() = blocked_by);

CREATE POLICY "Users can create blocks"
ON public.user_blocks
FOR INSERT
WITH CHECK (auth.uid() = blocked_by);

CREATE POLICY "Users can delete blocks they created"
ON public.user_blocks
FOR DELETE
USING (auth.uid() = blocked_by);
