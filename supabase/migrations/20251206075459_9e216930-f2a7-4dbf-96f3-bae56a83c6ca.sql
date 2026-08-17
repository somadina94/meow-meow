-- Create system_metrics table for performance monitoring
CREATE TABLE public.system_metrics (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  cpu_usage FLOAT NOT NULL DEFAULT 0,
  memory_usage FLOAT NOT NULL DEFAULT 0,
  active_connections INTEGER NOT NULL DEFAULT 0,
  response_time FLOAT NOT NULL DEFAULT 0,
  disk_usage FLOAT DEFAULT 0,
  network_in FLOAT DEFAULT 0,
  network_out FLOAT DEFAULT 0,
  error_rate FLOAT DEFAULT 0,
  recorded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create system_alerts table
CREATE TABLE public.system_alerts (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  alert_type TEXT NOT NULL DEFAULT 'warning',
  metric_name TEXT NOT NULL,
  threshold_value FLOAT NOT NULL,
  current_value FLOAT NOT NULL,
  message TEXT NOT NULL,
  is_resolved BOOLEAN NOT NULL DEFAULT false,
  resolved_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.system_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_alerts ENABLE ROW LEVEL SECURITY;

-- RLS policies - only admins can access
CREATE POLICY "Admins can view all metrics" ON public.system_metrics
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can insert metrics" ON public.system_metrics
  FOR INSERT WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can view all alerts" ON public.system_alerts
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can manage alerts" ON public.system_alerts
  FOR ALL USING (has_role(auth.uid(), 'admin'::app_role));

-- Create index for faster queries
CREATE INDEX idx_system_metrics_recorded_at ON public.system_metrics(recorded_at DESC);
CREATE INDEX idx_system_alerts_created_at ON public.system_alerts(created_at DESC);
CREATE INDEX idx_system_alerts_is_resolved ON public.system_alerts(is_resolved);