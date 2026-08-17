-- Allow admins to insert and update app_settings (read-only previously)
CREATE POLICY "Admins can insert app_settings"
ON public.app_settings FOR INSERT TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can update app_settings"
ON public.app_settings FOR UPDATE TO authenticated
USING (public.has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can delete app_settings"
ON public.app_settings FOR DELETE TO authenticated
USING (public.has_role(auth.uid(), 'admin'::app_role));

-- Enable realtime on the four admin tables
ALTER TABLE public.audit_logs REPLICA IDENTITY FULL;
ALTER TABLE public.admin_user_messages REPLICA IDENTITY FULL;
ALTER TABLE public.admin_settings REPLICA IDENTITY FULL;
ALTER TABLE public.app_settings REPLICA IDENTITY FULL;
ALTER TABLE public.women_payout_snapshots REPLICA IDENTITY FULL;

ALTER PUBLICATION supabase_realtime ADD TABLE public.audit_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.admin_user_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.admin_settings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_settings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.women_payout_snapshots;

-- Index for inbox query performance
CREATE INDEX IF NOT EXISTS idx_admin_user_messages_inbox
ON public.admin_user_messages (sender_role, target_user_id, created_at DESC)
WHERE target_user_id IS NOT NULL;