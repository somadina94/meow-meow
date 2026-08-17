CREATE OR REPLACE FUNCTION public.get_login_billing_seconds_bulk(_user_ids uuid[], _month text)
 RETURNS TABLE(user_id uuid, login_seconds bigint, billing_seconds bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
           ))::bigint))::bigint, 0::bigint) AS secs
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
         COALESCE(ls.secs, 0::bigint)::bigint,
         COALESCE(bs.secs, 0::bigint)::bigint
  FROM ids
  LEFT JOIN ls ON ls.user_id = ids.uid
  LEFT JOIN bs ON bs.user_id = ids.uid;
END;
$function$;