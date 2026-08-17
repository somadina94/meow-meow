CREATE TABLE IF NOT EXISTS public.screen_capture_events (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN ('screenshot', 'recording_started', 'recording_stopped')),
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_screen_capture_events_user_id ON public.screen_capture_events(user_id);
CREATE INDEX IF NOT EXISTS idx_screen_capture_events_created_at ON public.screen_capture_events(created_at DESC);

ALTER TABLE public.screen_capture_events ENABLE ROW LEVEL SECURITY;

-- Users may insert their own capture events (audit log entries from their device)
CREATE POLICY "Users can log their own capture events"
  ON public.screen_capture_events
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users cannot read the audit log (admin-only forensic data)
-- Admins can read all events
CREATE POLICY "Admins can view all capture events"
  ON public.screen_capture_events
  FOR SELECT
  TO authenticated
  USING (public.has_role(auth.uid(), 'admin'::app_role));