
-- Create admin_broadcast_messages table for admin-to-user messaging
CREATE TABLE public.admin_broadcast_messages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_id UUID NOT NULL,
  recipient_id UUID, -- NULL means broadcast to all
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  is_broadcast BOOLEAN NOT NULL DEFAULT false,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.admin_broadcast_messages ENABLE ROW LEVEL SECURITY;

-- Admins can insert messages
CREATE POLICY "Admins can insert broadcast messages"
ON public.admin_broadcast_messages
FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Admins can view all messages
CREATE POLICY "Admins can view all broadcast messages"
ON public.admin_broadcast_messages
FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Users can view messages sent to them or broadcast
CREATE POLICY "Users can view their own messages"
ON public.admin_broadcast_messages
FOR SELECT
TO authenticated
USING (recipient_id = auth.uid() OR is_broadcast = true);

-- Users can mark their messages as read
CREATE POLICY "Users can update read status"
ON public.admin_broadcast_messages
FOR UPDATE
TO authenticated
USING (recipient_id = auth.uid() OR is_broadcast = true)
WITH CHECK (recipient_id = auth.uid() OR is_broadcast = true);
