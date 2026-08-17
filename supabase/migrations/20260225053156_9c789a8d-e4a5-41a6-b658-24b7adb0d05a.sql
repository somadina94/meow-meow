
-- Create men_free_minutes table (used by men's dashboard for free chat minutes tracking)
CREATE TABLE IF NOT EXISTS public.men_free_minutes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  free_minutes_total INT NOT NULL DEFAULT 10,
  free_minutes_used INT NOT NULL DEFAULT 0,
  last_reset_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  next_reset_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (now() + interval '15 days'),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

-- RLS for men_free_minutes
ALTER TABLE public.men_free_minutes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own free minutes" ON public.men_free_minutes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own free minutes" ON public.men_free_minutes
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "System can insert free minutes" ON public.men_free_minutes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create get_online_women_dashboard RPC (counterpart to get_online_men_dashboard)
-- Used by men's dashboard to see online women with availability and earning status
CREATE OR REPLACE FUNCTION public.get_online_women_dashboard()
RETURNS TABLE (
  user_id UUID,
  full_name TEXT,
  photo_url TEXT,
  country TEXT,
  primary_language TEXT,
  age INT,
  mother_tongue TEXT,
  is_earning_eligible BOOLEAN,
  is_available BOOLEAN,
  current_chat_count INT,
  max_concurrent_chats INT,
  last_seen TIMESTAMP WITH TIME ZONE
)
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.user_id,
    COALESCE(p.full_name, 'Anonymous') AS full_name,
    p.photo_url,
    p.country,
    p.primary_language,
    p.age,
    COALESCE(ul.language_name, p.primary_language, p.preferred_language, 'Unknown') AS mother_tongue,
    COALESCE(p.is_earning_eligible, false) AS is_earning_eligible,
    COALESCE(wa.is_available, true) AS is_available,
    COALESCE(wa.current_chat_count, 0)::int AS current_chat_count,
    COALESCE(wa.max_concurrent_chats, 3)::int AS max_concurrent_chats,
    us.last_seen
  FROM public.user_status us
  JOIN public.profiles p ON p.user_id = us.user_id
  LEFT JOIN public.women_availability wa ON wa.user_id = p.user_id
  LEFT JOIN LATERAL (
    SELECT u.language_name
    FROM public.user_languages u
    WHERE u.user_id = p.user_id
    ORDER BY u.created_at DESC
    LIMIT 1
  ) ul ON TRUE
  WHERE us.is_online = TRUE
    AND auth.uid() IS NOT NULL
    AND LOWER(COALESCE(p.gender, '')) = 'female'
    AND COALESCE(p.approval_status, 'pending') = 'approved'
    AND (
      has_role(auth.uid(), 'admin'::app_role)
      OR EXISTS (
        SELECT 1
        FROM public.profiles me
        WHERE me.user_id = auth.uid()
          AND LOWER(COALESCE(me.gender, '')) = 'male'
      )
    );
$$;

-- Create get_dashboard_stats RPC for both dashboards
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender TEXT;
  v_online_count INT;
  v_match_count INT;
  v_unread_notifications INT;
  v_wallet_balance NUMERIC;
  v_today_earnings NUMERIC;
  v_active_chats INT;
BEGIN
  -- Get user gender
  SELECT LOWER(COALESCE(gender, '')) INTO v_gender
  FROM profiles WHERE user_id = p_user_id;

  -- Online users count
  SELECT COUNT(*) INTO v_online_count
  FROM user_status WHERE is_online = true;

  -- Match count
  SELECT COUNT(*) INTO v_match_count
  FROM matches
  WHERE (user_id = p_user_id OR matched_user_id = p_user_id)
    AND status = 'accepted';

  -- Unread notifications
  SELECT COUNT(*) INTO v_unread_notifications
  FROM notifications
  WHERE user_id = p_user_id AND is_read = false;

  -- Active chats
  IF v_gender = 'male' THEN
    SELECT COUNT(*) INTO v_active_chats
    FROM active_chat_sessions
    WHERE man_user_id = p_user_id AND status = 'active';
  ELSE
    SELECT COUNT(*) INTO v_active_chats
    FROM active_chat_sessions
    WHERE woman_user_id = p_user_id AND status = 'active';
  END IF;

  -- Wallet balance
  IF v_gender = 'male' THEN
    SELECT COALESCE(balance, 0) INTO v_wallet_balance
    FROM wallets WHERE user_id = p_user_id;
  ELSE
    -- Women: earnings - withdrawals
    SELECT COALESCE(SUM(amount), 0) INTO v_wallet_balance
    FROM women_earnings WHERE user_id = p_user_id;
    
    v_wallet_balance := v_wallet_balance - COALESCE((
      SELECT SUM(amount) FROM wallet_transactions
      WHERE user_id = p_user_id AND type = 'debit'
    ), 0);
  END IF;

  -- Today's earnings (women only)
  v_today_earnings := 0;
  IF v_gender = 'female' THEN
    SELECT COALESCE(SUM(amount), 0) INTO v_today_earnings
    FROM women_earnings
    WHERE user_id = p_user_id
      AND created_at >= date_trunc('day', now())
      AND created_at < date_trunc('day', now()) + interval '1 day';
  END IF;

  RETURN jsonb_build_object(
    'gender', v_gender,
    'online_count', v_online_count,
    'match_count', v_match_count,
    'unread_notifications', v_unread_notifications,
    'wallet_balance', COALESCE(v_wallet_balance, 0),
    'today_earnings', v_today_earnings,
    'active_chats', v_active_chats
  );
END;
$$;
