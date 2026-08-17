-- Create audit_logs table for compliance tracking
CREATE TABLE public.audit_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_id UUID NOT NULL,
  admin_email TEXT,
  action TEXT NOT NULL,
  action_type TEXT NOT NULL DEFAULT 'update',
  resource_type TEXT NOT NULL,
  resource_id TEXT,
  old_value JSONB,
  new_value JSONB,
  ip_address TEXT,
  user_agent TEXT,
  details TEXT,
  status TEXT NOT NULL DEFAULT 'success',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- RLS policies - only admins can view audit logs
CREATE POLICY "Admins can view all audit logs" ON public.audit_logs
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

-- System/service role can insert logs (for edge functions)
CREATE POLICY "System can insert audit logs" ON public.audit_logs
  FOR INSERT WITH CHECK (true);

-- Create indexes for performance
CREATE INDEX idx_audit_logs_admin_id ON public.audit_logs(admin_id);
CREATE INDEX idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX idx_audit_logs_action_type ON public.audit_logs(action_type);
CREATE INDEX idx_audit_logs_resource_type ON public.audit_logs(resource_type);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_status ON public.audit_logs(status);

-- Insert sample audit logs for demo
INSERT INTO public.audit_logs (admin_id, admin_email, action, action_type, resource_type, resource_id, details, status) VALUES
(gen_random_uuid(), 'admin@meowchat.com', 'Updated chat pricing', 'update', 'settings', 'chat_pricing_1', 'Changed rate from ₹2.00 to ₹2.50 per minute', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Created new gift', 'create', 'gifts', 'gift_001', 'Added "Diamond Ring" gift at ₹500', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Deleted user account', 'delete', 'users', 'user_123', 'Removed inactive user account', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Updated RLS policy', 'update', 'security', 'rls_profiles', 'Modified profiles table access policy', 'success'),
(gen_random_uuid(), 'moderator@meowchat.com', 'Flagged message', 'update', 'messages', 'msg_456', 'Flagged message for inappropriate content', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Triggered backup', 'create', 'backup', 'backup_789', 'Manual database backup initiated', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Updated language group', 'update', 'language_groups', 'lg_hindi', 'Added new dialects to Hindi group', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Login attempt', 'auth', 'session', 'session_001', 'Admin login from new device', 'success'),
(gen_random_uuid(), 'admin@meowchat.com', 'Failed login attempt', 'auth', 'session', 'session_002', 'Invalid credentials provided', 'failed'),
(gen_random_uuid(), 'admin@meowchat.com', 'Updated withdrawal status', 'update', 'withdrawals', 'wd_101', 'Approved withdrawal request for ₹15,000', 'success');