
-- Table to track auto-ping messages to avoid spam
CREATE TABLE public.women_auto_ping_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  woman_user_id uuid NOT NULL,
  man_user_id uuid NOT NULL,
  ping_type text NOT NULL DEFAULT 'online', -- 'online' or 'offline'
  last_sent_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(woman_user_id, man_user_id, ping_type)
);

ALTER TABLE public.women_auto_ping_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Women can view own ping logs"
ON public.women_auto_ping_log FOR SELECT
TO authenticated
USING (auth.uid() = woman_user_id);

CREATE POLICY "Service role can manage ping logs"
ON public.women_auto_ping_log FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

CREATE POLICY "Admin can view all ping logs"
ON public.women_auto_ping_log FOR SELECT
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role));

-- Index for efficient lookups
CREATE INDEX idx_auto_ping_woman_man ON public.women_auto_ping_log(woman_user_id, man_user_id);
CREATE INDEX idx_auto_ping_last_sent ON public.women_auto_ping_log(last_sent_at);

-- Function to get men with zero balance (not recharged)
CREATE OR REPLACE FUNCTION public.get_unrecharged_men()
RETURNS TABLE(user_id uuid, full_name text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT mp.user_id, mp.full_name
  FROM male_profiles mp
  JOIN wallets w ON w.user_id = mp.user_id
  WHERE w.balance <= 0
    AND mp.account_status = 'active'
$$;

-- Function to get online women for pinging
CREATE OR REPLACE FUNCTION public.get_online_women_for_ping()
RETURNS TABLE(user_id uuid, full_name text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT fp.user_id, fp.full_name
  FROM female_profiles fp
  WHERE fp.account_status = 'active'
    AND fp.approval_status = 'approved'
    AND fp.last_active_at > (now() - interval '5 minutes')
$$;

-- Function to get offline women (active in last 24h but not last 5 min)
CREATE OR REPLACE FUNCTION public.get_offline_women_for_daily_ping()
RETURNS TABLE(user_id uuid, full_name text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT fp.user_id, fp.full_name
  FROM female_profiles fp
  WHERE fp.account_status = 'active'
    AND fp.approval_status = 'approved'
    AND (fp.last_active_at <= (now() - interval '5 minutes') OR fp.last_active_at IS NULL)
$$;
