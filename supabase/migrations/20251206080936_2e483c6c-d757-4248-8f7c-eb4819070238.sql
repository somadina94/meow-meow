-- Create moderation_reports table for user reports
CREATE TABLE public.moderation_reports (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  reporter_id UUID NOT NULL,
  reported_user_id UUID NOT NULL,
  report_type TEXT NOT NULL DEFAULT 'inappropriate_behavior',
  content TEXT,
  chat_message_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  action_taken TEXT,
  action_reason TEXT,
  reviewed_by UUID,
  reviewed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create user_blocks table to track blocked users
CREATE TABLE public.user_blocks (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  blocked_user_id UUID NOT NULL,
  blocked_by UUID NOT NULL,
  reason TEXT,
  block_type TEXT NOT NULL DEFAULT 'temporary',
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create user_warnings table
CREATE TABLE public.user_warnings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  warning_type TEXT NOT NULL DEFAULT 'behavior',
  message TEXT NOT NULL,
  issued_by UUID NOT NULL,
  acknowledged_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.moderation_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_warnings ENABLE ROW LEVEL SECURITY;

-- Moderation reports policies
CREATE POLICY "Admins can view all reports"
ON public.moderation_reports FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role) OR has_role(auth.uid(), 'moderator'::app_role));

CREATE POLICY "Users can create reports"
ON public.moderation_reports FOR INSERT
WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Admins can update reports"
ON public.moderation_reports FOR UPDATE
USING (has_role(auth.uid(), 'admin'::app_role) OR has_role(auth.uid(), 'moderator'::app_role));

-- User blocks policies
CREATE POLICY "Admins can manage blocks"
ON public.user_blocks FOR ALL
USING (has_role(auth.uid(), 'admin'::app_role) OR has_role(auth.uid(), 'moderator'::app_role));

CREATE POLICY "Users can view if they are blocked"
ON public.user_blocks FOR SELECT
USING (auth.uid() = blocked_user_id);

-- User warnings policies
CREATE POLICY "Admins can manage warnings"
ON public.user_warnings FOR ALL
USING (has_role(auth.uid(), 'admin'::app_role) OR has_role(auth.uid(), 'moderator'::app_role));

CREATE POLICY "Users can view their own warnings"
ON public.user_warnings FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can acknowledge their warnings"
ON public.user_warnings FOR UPDATE
USING (auth.uid() = user_id);

-- Create indexes for performance
CREATE INDEX idx_moderation_reports_status ON public.moderation_reports(status);
CREATE INDEX idx_moderation_reports_reported_user ON public.moderation_reports(reported_user_id);
CREATE INDEX idx_user_blocks_user ON public.user_blocks(blocked_user_id);
CREATE INDEX idx_user_warnings_user ON public.user_warnings(user_id);

-- Add trigger for updated_at
CREATE TRIGGER update_moderation_reports_updated_at
BEFORE UPDATE ON public.moderation_reports
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();