
-- Drop and recreate get_online_men_dashboard with correct return type
DROP FUNCTION IF EXISTS public.get_online_men_dashboard();

CREATE OR REPLACE FUNCTION public.get_online_men_dashboard()
RETURNS TABLE(
  user_id uuid,
  full_name text,
  photo_url text,
  country text,
  state text,
  preferred_language text,
  primary_language text,
  age integer,
  mother_tongue text,
  wallet_balance numeric,
  last_seen timestamptz,
  active_chat_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.user_id,
    p.full_name,
    p.photo_url,
    p.country,
    p.state,
    p.preferred_language,
    p.primary_language,
    p.age,
    COALESCE(ul.language_name, p.primary_language, p.preferred_language, 'English')::text AS mother_tongue,
    COALESCE(w.balance, 0)::numeric AS wallet_balance,
    us.last_seen,
    COALESCE(chat_counts.cnt, 0)::bigint AS active_chat_count
  FROM profiles p
  INNER JOIN user_status us ON us.user_id = p.user_id AND us.is_online = true
  LEFT JOIN LATERAL (
    SELECT ul2.language_name
    FROM user_languages ul2
    WHERE ul2.user_id = p.user_id
    ORDER BY ul2.created_at ASC
    LIMIT 1
  ) ul ON true
  LEFT JOIN wallets w ON w.user_id = p.user_id
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::bigint AS cnt
    FROM active_chat_sessions acs
    WHERE acs.man_user_id = p.user_id AND acs.status = 'active'
  ) chat_counts ON true
  WHERE p.gender IN ('male', 'Male')
    AND p.photo_url IS NOT NULL
    AND p.photo_url != ''
    AND p.account_status = 'active'
  ORDER BY COALESCE(chat_counts.cnt, 0) ASC, COALESCE(w.balance, 0) DESC;
END;
$$;
