-- Create table to track group session extensions (replaces localStorage)
-- Enforces "one extension per user per group per calendar month" server-side
CREATE TABLE public.group_session_extensions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  group_id uuid NOT NULL REFERENCES public.private_groups(id) ON DELETE CASCADE,
  reason text,
  extension_month integer NOT NULL,
  extension_year integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, group_id, extension_month, extension_year)
);

-- Enable RLS
ALTER TABLE public.group_session_extensions ENABLE ROW LEVEL SECURITY;

-- Users can view their own extension records
CREATE POLICY "Users can view own extensions"
  ON public.group_session_extensions FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own extension records (unique constraint enforces one per month)
CREATE POLICY "Users can insert own extensions"
  ON public.group_session_extensions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Admin read access
CREATE POLICY "Admins can view all extensions"
  ON public.group_session_extensions FOR SELECT
  TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role));