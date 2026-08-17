
-- Admin messaging table for group broadcasts and individual chats
CREATE TABLE public.admin_user_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL,
  target_group TEXT NOT NULL DEFAULT 'all',
  target_user_id UUID,
  sender_role TEXT NOT NULL DEFAULT 'admin',
  sender_id UUID NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast lookups
CREATE INDEX idx_admin_user_messages_target ON public.admin_user_messages(target_group, created_at DESC);
CREATE INDEX idx_admin_user_messages_user ON public.admin_user_messages(target_user_id, created_at DESC);
CREATE INDEX idx_admin_user_messages_created ON public.admin_user_messages(created_at);

-- Enable RLS
ALTER TABLE public.admin_user_messages ENABLE ROW LEVEL SECURITY;

-- Admins can do everything
CREATE POLICY "Admins full access" ON public.admin_user_messages
  FOR ALL USING (true) WITH CHECK (true);

-- Auto-delete messages older than 7 days
CREATE OR REPLACE FUNCTION public.cleanup_old_admin_messages()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.admin_user_messages
  WHERE created_at < now() - interval '7 days';
END;
$$;
