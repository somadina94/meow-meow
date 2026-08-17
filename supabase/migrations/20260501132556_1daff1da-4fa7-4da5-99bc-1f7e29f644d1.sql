-- 1) Track each woman's (and man's) app login sessions for "total login time"
CREATE TABLE IF NOT EXISTS public.login_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  duration_seconds integer,
  client_info jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_login_sessions_user_started
  ON public.login_sessions(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_login_sessions_open
  ON public.login_sessions(user_id) WHERE ended_at IS NULL;

ALTER TABLE public.login_sessions ENABLE ROW LEVEL SECURITY;

-- Users can read their own sessions
CREATE POLICY "Users read own login sessions"
  ON public.login_sessions FOR SELECT
  USING (auth.uid() = user_id);

-- Admins can read all
CREATE POLICY "Admins read all login sessions"
  ON public.login_sessions FOR SELECT
  USING (public.has_role(auth.uid(), 'admin'));

-- No direct insert/update/delete from clients (use RPCs)
-- (No INSERT/UPDATE/DELETE policies => denied for non-service role)

-- 2) RPC: start a login session (closes any stale open session first)
CREATE OR REPLACE FUNCTION public.start_login_session(_client_info jsonb DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Auto-close any open session older than 30 min (stale)
  UPDATE public.login_sessions
  SET ended_at = COALESCE(ended_at, now()),
      duration_seconds = GREATEST(0, EXTRACT(EPOCH FROM (now() - started_at))::int),
      updated_at = now()
  WHERE user_id = v_uid AND ended_at IS NULL;

  INSERT INTO public.login_sessions (user_id, client_info)
  VALUES (v_uid, _client_info)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- 3) RPC: heartbeat / end a login session
CREATE OR REPLACE FUNCTION public.end_login_session(_session_id uuid DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RETURN; END IF;

  UPDATE public.login_sessions
  SET ended_at = now(),
      duration_seconds = GREATEST(0, EXTRACT(EPOCH FROM (now() - started_at))::int),
      updated_at = now()
  WHERE user_id = v_uid
    AND ended_at IS NULL
    AND (_session_id IS NULL OR id = _session_id);
END;
$$;

-- 4) Helper: total login seconds for a user within an IST month "YYYY-MM"
CREATE OR REPLACE FUNCTION public.get_login_seconds_for_month(_user_id uuid, _month text)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start timestamptz;
  v_end   timestamptz;
  v_total bigint := 0;
BEGIN
  -- IST month bounds
  v_start := (to_timestamp(_month || '-01', 'YYYY-MM-DD') AT TIME ZONE 'Asia/Kolkata');
  v_end   := v_start + interval '1 month';

  SELECT COALESCE(SUM(
           GREATEST(0, EXTRACT(EPOCH FROM (
             LEAST(COALESCE(ended_at, now()), v_end) - GREATEST(started_at, v_start)
           ))::bigint)
         ), 0)
    INTO v_total
  FROM public.login_sessions
  WHERE user_id = _user_id
    AND started_at < v_end
    AND COALESCE(ended_at, now()) > v_start;

  RETURN v_total;
END;
$$;

-- 5) Helper: total billing seconds (earned) for a woman within an IST month
CREATE OR REPLACE FUNCTION public.get_billing_seconds_for_month(_user_id uuid, _month text)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start timestamptz;
  v_end   timestamptz;
  v_total bigint := 0;
BEGIN
  v_start := (to_timestamp(_month || '-01', 'YYYY-MM-DD') AT TIME ZONE 'Asia/Kolkata');
  v_end   := v_start + interval '1 month';

  SELECT COALESCE(SUM(duration_seconds), 0)::bigint
    INTO v_total
  FROM public.wallet_transactions
  WHERE user_id = _user_id
    AND transaction_type = 'session_earning'
    AND amount > 0
    AND COALESCE(duration_seconds, 0) > 0
    AND created_at >= v_start
    AND created_at <  v_end;

  RETURN v_total;
END;
$$;

-- 6) Bulk helper: returns login + billing seconds for many users in a month
CREATE OR REPLACE FUNCTION public.get_login_billing_seconds_bulk(_user_ids uuid[], _month text)
RETURNS TABLE(user_id uuid, login_seconds bigint, billing_seconds bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start timestamptz;
  v_end   timestamptz;
BEGIN
  v_start := (to_timestamp(_month || '-01', 'YYYY-MM-DD') AT TIME ZONE 'Asia/Kolkata');
  v_end   := v_start + interval '1 month';

  RETURN QUERY
  WITH ids AS (SELECT unnest(_user_ids) AS uid),
  ls AS (
    SELECT s.user_id,
           COALESCE(SUM(GREATEST(0, EXTRACT(EPOCH FROM (
             LEAST(COALESCE(s.ended_at, now()), v_end) - GREATEST(s.started_at, v_start)
           ))::bigint)), 0) AS secs
    FROM public.login_sessions s
    WHERE s.user_id = ANY(_user_ids)
      AND s.started_at < v_end
      AND COALESCE(s.ended_at, now()) > v_start
    GROUP BY s.user_id
  ),
  bs AS (
    SELECT w.user_id,
           COALESCE(SUM(w.duration_seconds), 0)::bigint AS secs
    FROM public.wallet_transactions w
    WHERE w.user_id = ANY(_user_ids)
      AND w.transaction_type = 'session_earning'
      AND w.amount > 0
      AND COALESCE(w.duration_seconds, 0) > 0
      AND w.created_at >= v_start
      AND w.created_at <  v_end
    GROUP BY w.user_id
  )
  SELECT ids.uid,
         COALESCE(ls.secs, 0),
         COALESCE(bs.secs, 0)
  FROM ids
  LEFT JOIN ls ON ls.user_id = ids.uid
  LEFT JOIN bs ON bs.user_id = ids.uid;
END;
$$;

-- Permissions for authenticated callers
GRANT EXECUTE ON FUNCTION public.start_login_session(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.end_login_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_login_seconds_for_month(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_billing_seconds_for_month(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_login_billing_seconds_bulk(uuid[], text) TO authenticated;