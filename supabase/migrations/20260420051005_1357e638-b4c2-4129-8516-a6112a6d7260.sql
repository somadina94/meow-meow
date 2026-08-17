-- Allow group members to read messages even if has_access was temporarily revoked
-- (e.g. after a spurious presence-leave event during reconnects). This prevents
-- the chat from going dark mid-call. Sending still requires has_access = true.
DROP POLICY IF EXISTS "Members can view group messages" ON public.group_messages;

CREATE POLICY "Members can view group messages"
ON public.group_messages
FOR SELECT
USING (
  -- Sender always sees their own messages
  sender_id = auth.uid()
  OR
  -- Anyone who has joined the group (regardless of current has_access) can view
  EXISTS (
    SELECT 1 FROM public.group_memberships
    WHERE group_memberships.group_id = group_messages.group_id
      AND group_memberships.user_id = auth.uid()
  )
  OR
  -- Group owner always sees
  EXISTS (
    SELECT 1 FROM public.private_groups
    WHERE private_groups.id = group_messages.group_id
      AND private_groups.owner_id = auth.uid()
  )
);