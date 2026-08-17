-- Create secure function to list online men + wallet balances for Women Dashboard premium sorting
CREATE OR REPLACE FUNCTION public.get_online_men_dashboard()
RETURNS TABLE (
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
  active_chat_count integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.user_id,
    COALESCE(p.full_name, 'Anonymous') AS full_name,
    p.photo_url,
    p.country,
    p.state,
    p.preferred_language,
    p.primary_language,
    p.age,
    COALESCE(ul.language_name, p.primary_language, p.preferred_language, 'Unknown') AS mother_tongue,
    COALESCE(w.balance, 0) AS wallet_balance,
    us.last_seen,
    COALESCE(cs.cnt, 0)::int AS active_chat_count
  FROM public.user_status us
  JOIN public.profiles p ON p.user_id = us.user_id
  LEFT JOIN public.wallets w ON w.user_id = p.user_id
  LEFT JOIN LATERAL (
    SELECT u.language_name
    FROM public.user_languages u
    WHERE u.user_id = p.user_id
    ORDER BY u.created_at DESC
    LIMIT 1
  ) ul ON TRUE
  LEFT JOIN LATERAL (
    SELECT COUNT(*) AS cnt
    FROM public.active_chat_sessions s
    WHERE s.man_user_id = p.user_id
      AND s.status = 'active'
  ) cs ON TRUE
  WHERE us.is_online = TRUE
    AND auth.uid() IS NOT NULL
    AND LOWER(COALESCE(p.gender, '')) = 'male'
    AND (
      has_role(auth.uid(), 'admin'::app_role)
      OR EXISTS (
        SELECT 1
        FROM public.profiles me
        WHERE me.user_id = auth.uid()
          AND LOWER(COALESCE(me.gender, '')) = 'female'
      )
    );
$$;

-- Lock down execution
REVOKE ALL ON FUNCTION public.get_online_men_dashboard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_online_men_dashboard() TO authenticated;
