
-- Allow admins to update chat_messages (for flag / unflag / moderation_status changes)
DROP POLICY IF EXISTS "admin_chat_messages_update" ON public.chat_messages;
CREATE POLICY "admin_chat_messages_update"
ON public.chat_messages
FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (public.has_role(auth.uid(), 'admin'::app_role));
