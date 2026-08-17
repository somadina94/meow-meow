-- ════════════════════════════════════════════════════════════════
-- 1. Rewrite admin analytics to use wallet_transactions + archive
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_analytics_summary(
  p_start_date timestamptz,
  p_end_date timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_result jsonb;
  v_totals jsonb;
  v_chart jsonb;
  v_gender jsonb;
  v_archive_cutoff timestamptz := now() - interval '3 months';
  v_need_archive boolean := (p_start_date < v_archive_cutoff);
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  -- Unified view of wallet_transactions + archive (only when range needs it)
  WITH unified AS (
    SELECT user_id, type, amount, transaction_type, description, created_at
    FROM public.wallet_transactions
    WHERE created_at >= p_start_date AND created_at <= p_end_date AND status='completed'
    UNION ALL
    SELECT user_id, type, amount, transaction_type, description, created_at
    FROM public.wallet_transactions_archive
    WHERE v_need_archive
      AND created_at >= p_start_date AND created_at <= p_end_date AND status='completed'
  )
  SELECT jsonb_build_object(
    'total_users', (SELECT count(*) FROM profiles),
    'active_users', (SELECT count(*) FROM user_status WHERE is_online = true),
    'total_matches', (SELECT count(*) FROM matches),
    'new_users_today', (
      SELECT count(*) FROM profiles
      WHERE created_at >= date_trunc('day', now())
        AND created_at <  date_trunc('day', now()) + interval '1 day'
    ),
    'messages_count', (
      SELECT count(*) FROM chat_messages
      WHERE created_at >= p_start_date AND created_at <= p_end_date
    ),
    'men_recharges', COALESCE((
      SELECT sum(amount) FROM unified
      WHERE type='credit' AND transaction_type='recharge'
    ), 0),
    'men_spent', COALESCE((
      SELECT sum(amount) FROM unified
      WHERE type='debit' AND transaction_type IN (
        'chat','audio_call','video_call','group_call','private_group_call',
        'chat_charge','audio_call_charge','video_call_charge',
        'group_call_charge','private_group_call_charge',
        'tip','tip_charge','tip_debit','gift','gift_charge','gift_debit'
      )
    ), 0),
    'women_earnings', COALESCE((
      SELECT sum(amount) FROM unified
      WHERE type='credit' AND transaction_type IN (
        'chat_earning','audio_call_earning','video_call_earning',
        'group_call_earning','private_group_call_earning',
        'gift_received','gift_earning','gift_credit',
        'tip_received','tip_earning','earning'
      )
    ), 0),
    'women_withdrawals', COALESCE((
      SELECT sum(amount) FROM unified
      WHERE type='debit' AND transaction_type IN ('withdrawal','withdrawal_fee')
    ), 0),
    'avg_session_minutes', COALESCE((
      SELECT avg(total_minutes) FROM active_chat_sessions
      WHERE created_at >= p_start_date AND created_at <= p_end_date
    ), 0)
  ) INTO v_totals;

  SELECT jsonb_build_object(
    'male', (SELECT count(*) FROM profiles WHERE lower(gender) = 'male'),
    'female', (SELECT count(*) FROM profiles WHERE lower(gender) = 'female'),
    'other', (SELECT count(*) FROM profiles
              WHERE gender IS NULL OR lower(gender) NOT IN ('male','female'))
  ) INTO v_gender;

  -- Daily chart with same unified source
  SELECT COALESCE(jsonb_agg(row_data ORDER BY bucket), '[]'::jsonb)
  INTO v_chart
  FROM (
    SELECT
      d.bucket,
      jsonb_build_object(
        'date',        to_char(d.bucket, 'Mon DD'),
        'users',       COALESCE(u.cnt, 0),
        'activeUsers', COALESCE(au.cnt, 0),
        'matches',     COALESCE(m.cnt, 0),
        'messages',    COALESCE(msg.cnt, 0),
        'revenue',     COALESCE(r.recharges, 0) - COALESCE(w.withdrawals, 0)
      ) AS row_data
    FROM generate_series(date_trunc('day', p_start_date), date_trunc('day', p_end_date), '1 day') AS d(bucket)
    LEFT JOIN LATERAL (
      SELECT count(*) AS cnt FROM profiles
      WHERE created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) u ON true
    LEFT JOIN LATERAL (
      SELECT count(DISTINCT sender_id) AS cnt FROM chat_messages
      WHERE created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) au ON true
    LEFT JOIN LATERAL (
      SELECT count(*) AS cnt FROM matches
      WHERE created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) m ON true
    LEFT JOIN LATERAL (
      SELECT count(*) AS cnt FROM chat_messages
      WHERE created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) msg ON true
    LEFT JOIN LATERAL (
      SELECT COALESCE(sum(amount), 0) AS recharges FROM (
        SELECT amount, created_at, type, transaction_type FROM public.wallet_transactions
        UNION ALL
        SELECT amount, created_at, type, transaction_type FROM public.wallet_transactions_archive
          WHERE v_need_archive
      ) wu
      WHERE wu.type='credit' AND wu.transaction_type='recharge'
        AND wu.created_at >= d.bucket AND wu.created_at < d.bucket + interval '1 day'
    ) r ON true
    LEFT JOIN LATERAL (
      SELECT COALESCE(sum(amount), 0) AS withdrawals FROM (
        SELECT amount, created_at, type, transaction_type FROM public.wallet_transactions
        UNION ALL
        SELECT amount, created_at, type, transaction_type FROM public.wallet_transactions_archive
          WHERE v_need_archive
      ) wu
      WHERE wu.type='debit' AND wu.transaction_type IN ('withdrawal','withdrawal_fee')
        AND wu.created_at >= d.bucket AND wu.created_at < d.bucket + interval '1 day'
    ) w ON true
  ) sub;

  v_result := jsonb_build_object('totals', v_totals, 'gender', v_gender, 'chart', v_chart);
  RETURN v_result;
END;
$function$;

-- ════════════════════════════════════════════════════════════════
-- 2. Admin: paginated user transaction history (live + archive)
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.admin_get_user_transactions(
  p_user_id uuid,
  p_limit integer DEFAULT 50,
  p_include_archive boolean DEFAULT true
)
RETURNS TABLE(
  id uuid, user_id uuid, type text, amount numeric, transaction_type text,
  description text, reference_id text, status text, created_at timestamptz,
  session_id uuid, session_type text, balance_after numeric,
  duration_seconds integer, rate_per_minute numeric,
  billing_metadata jsonb, source text
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT id, user_id, type, amount, transaction_type, description, reference_id,
         status, created_at, session_id, session_type, balance_after,
         duration_seconds, rate_per_minute, billing_metadata, 'live'::text
  FROM public.wallet_transactions
  WHERE user_id = p_user_id
    AND (auth.role() = 'service_role' OR public.has_role(auth.uid(), 'admin'))
  UNION ALL
  SELECT id, user_id, type, amount, transaction_type, description, reference_id,
         status, created_at, session_id, session_type, balance_after,
         duration_seconds, rate_per_minute, billing_metadata, 'archive'::text
  FROM public.wallet_transactions_archive
  WHERE p_include_archive
    AND user_id = p_user_id
    AND (auth.role() = 'service_role' OR public.has_role(auth.uid(), 'admin'))
  ORDER BY created_at DESC
  LIMIT p_limit;
$$;

-- ════════════════════════════════════════════════════════════════
-- 3. Group-call history for a user (live + archive)
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_user_group_call_history(
  p_user_id uuid,
  p_is_male boolean,
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  id uuid, amount numeric, description text, duration_seconds integer,
  rate_per_minute numeric, created_at timestamptz, transaction_type text,
  type text, session_id uuid
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT id, amount, description, duration_seconds, rate_per_minute,
         created_at, transaction_type, type, session_id
  FROM (
    SELECT id, amount, description, duration_seconds, rate_per_minute,
           created_at, transaction_type, type, session_id, user_id
    FROM public.wallet_transactions
    UNION ALL
    SELECT id, amount, description, duration_seconds, rate_per_minute,
           created_at, transaction_type, type, session_id, user_id
    FROM public.wallet_transactions_archive
  ) u
  WHERE u.user_id = p_user_id
    AND (
      (p_is_male AND u.transaction_type IN ('group_charge','group_call_charge','private_group_call','private_group_call_charge'))
      OR (NOT p_is_male AND (u.description ILIKE 'Group call earning%' OR u.transaction_type IN ('group_call_earning','private_group_call_earning')))
    )
  ORDER BY created_at DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_user_transactions(uuid,integer,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_group_call_history(uuid,boolean,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_analytics_summary(timestamptz,timestamptz) TO authenticated;