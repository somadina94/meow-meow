-- Create policy violation alerts table
CREATE TABLE IF NOT EXISTS public.policy_violation_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  alert_type text NOT NULL DEFAULT 'policy_violation',
  violation_type text NOT NULL,
  severity text NOT NULL DEFAULT 'medium',
  content text,
  source_message_id uuid,
  source_chat_id text,
  detected_by text NOT NULL DEFAULT 'system',
  status text NOT NULL DEFAULT 'pending',
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  action_taken text,
  admin_notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.policy_violation_alerts ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_policy_alerts_user_id ON public.policy_violation_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_policy_alerts_status ON public.policy_violation_alerts(status);
CREATE INDEX IF NOT EXISTS idx_policy_alerts_severity ON public.policy_violation_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_policy_alerts_violation_type ON public.policy_violation_alerts(violation_type);
CREATE INDEX IF NOT EXISTS idx_policy_alerts_created_at ON public.policy_violation_alerts(created_at DESC);

-- RLS Policies
CREATE POLICY "Admins can view all alerts" ON public.policy_violation_alerts
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role) OR has_role(auth.uid(), 'moderator'::app_role));

CREATE POLICY "Admins can update alerts" ON public.policy_violation_alerts
  FOR UPDATE USING (has_role(auth.uid(), 'admin'::app_role) OR has_role(auth.uid(), 'moderator'::app_role));

CREATE POLICY "System can insert alerts" ON public.policy_violation_alerts
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can delete alerts" ON public.policy_violation_alerts
  FOR DELETE USING (has_role(auth.uid(), 'admin'::app_role));

-- Add comment
COMMENT ON TABLE public.policy_violation_alerts IS 'Stores policy violation alerts for admin review';
COMMENT ON COLUMN public.policy_violation_alerts.violation_type IS 'Type: sexual_content, harassment, spam, tos_violation, guidelines_violation, hate_speech, scam, other';
COMMENT ON COLUMN public.policy_violation_alerts.severity IS 'Severity: low, medium, high, critical';
COMMENT ON COLUMN public.policy_violation_alerts.status IS 'Status: pending, reviewing, resolved, dismissed';