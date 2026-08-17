-- Create backup_logs table for tracking database backups
CREATE TABLE public.backup_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  backup_type TEXT NOT NULL DEFAULT 'manual',
  status TEXT NOT NULL DEFAULT 'pending',
  size_bytes BIGINT,
  storage_path TEXT,
  triggered_by UUID,
  error_message TEXT,
  started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.backup_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can view backup logs
CREATE POLICY "Admins can view all backup logs"
ON public.backup_logs
FOR SELECT
USING (has_role(auth.uid(), 'admin'));

-- Only admins can insert backup logs
CREATE POLICY "Admins can insert backup logs"
ON public.backup_logs
FOR INSERT
WITH CHECK (has_role(auth.uid(), 'admin'));

-- Only admins can update backup logs
CREATE POLICY "Admins can update backup logs"
ON public.backup_logs
FOR UPDATE
USING (has_role(auth.uid(), 'admin'));

-- Create index for faster queries
CREATE INDEX idx_backup_logs_status ON public.backup_logs(status);
CREATE INDEX idx_backup_logs_started_at ON public.backup_logs(started_at DESC);

-- Add updated_at trigger
CREATE TRIGGER update_backup_logs_updated_at
BEFORE UPDATE ON public.backup_logs
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();