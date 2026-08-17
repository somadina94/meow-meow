
-- ============================================================
-- O-005: admin_half_rule_audit view (derives video woman_earned)
-- ============================================================
DROP VIEW IF EXISTS public.admin_half_rule_audit CASCADE;

CREATE VIEW public.admin_half_rule_audit
WITH (security_invoker = on) AS
WITH unified AS (
  SELECT session_id, transaction_type, type, amount, user_id, created_at
  FROM public.wallet_transactions
  WHERE status = 'completed' AND session_id IS NOT NULL
  UNION ALL
  SELECT session_id, transaction_type, type, amount, user_id, created_at
  FROM public.wallet_transactions_archive
  WHERE status = 'completed' AND session_id IS NOT NULL
),
agg AS (
  SELECT
    session_id,
    -- session-type label, normalized
    MAX(CASE
      WHEN transaction_type IN ('chat','chat_charge','chat_earning') THEN 'chat'
      WHEN transaction_type IN ('audio_call','audio_call_charge','audio_call_earning') THEN 'audio_call'
      WHEN transaction_type IN ('video_call','video_call_charge','video_call_earning') THEN 'video_call'
      WHEN transaction_type IN ('group_call','group_call_charge','group_call_earning',
                                'private_group_call','private_group_call_charge',
                                'private_group_call_earning') THEN 'group_call'
      ELSE NULL
    END) AS session_type,
    SUM(CASE WHEN type = 'debit'  THEN amount ELSE 0 END) AS men_charged,
    SUM(CASE WHEN type = 'credit' AND transaction_type IN (
      'chat_earning','audio_call_earning','video_call_earning',
      'group_call_earning','private_group_call_earning'
    ) THEN amount ELSE 0 END) AS woman_earned,
    MIN(created_at) AS started_at,
    MAX(created_at) AS ended_at
  FROM unified
  GROUP BY session_id
)
SELECT
  session_id,
  session_type,
  men_charged,
  woman_earned,
  ROUND(men_charged / 2.0, 2) AS expected_woman_earned,
  (woman_earned = ROUND(men_charged / 2.0, 2)) AS half_rule_ok,
  started_at,
  ended_at
FROM agg
WHERE session_type IS NOT NULL;

REVOKE ALL ON public.admin_half_rule_audit FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.admin_half_rule_audit TO service_role;

-- Wrap in admin-only RPC for client access
CREATE OR REPLACE FUNCTION public.admin_get_half_rule_audit(
  p_limit int DEFAULT 200,
  p_only_violations boolean DEFAULT false
)
RETURNS SETOF public.admin_half_rule_audit
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM public.admin_half_rule_audit
  WHERE (NOT p_only_violations OR half_rule_ok = false)
    AND public.has_role(auth.uid(), 'admin')
  ORDER BY ended_at DESC
  LIMIT GREATEST(p_limit, 1);
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_half_rule_audit(int, boolean) TO authenticated;

-- ============================================================
-- O-004: batch RPCs for active chats (eliminate N+1)
-- ============================================================

-- Man's active chats: one row per chat
CREATE OR REPLACE FUNCTION public.get_man_active_chats(p_user_id uuid)
RETURNS TABLE(
  chat_id text,
  partner_id uuid,
  partner_name text,
  partner_photo text,
  last_message text,
  last_message_at timestamptz,
  last_message_sender_id uuid,
  unread_count integer,
  partner_is_online boolean,
  partner_status text,
  partner_active_chat_count integer,
  session_status text
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := public.resolve_wallet_user_id(p_user_id);
BEGIN
  IF v_uid IS NULL THEN RETURN; END IF;
  IF auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_uid
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Not allowed';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT acs.chat_id, acs.woman_user_id AS partner_id,
           acs.last_activity_at, acs.status
    FROM public.active_chat_sessions acs
    WHERE acs.man_user_id = v_uid
      AND acs.status IN ('active','pending')
    UNION
    -- Include ended sessions where man still has unread messages
    SELECT acs.chat_id, acs.woman_user_id, acs.last_activity_at, acs.status
    FROM public.active_chat_sessions acs
    WHERE acs.man_user_id = v_uid
      AND EXISTS (
        SELECT 1 FROM public.chat_messages cm
        WHERE cm.chat_id = acs.chat_id
          AND cm.receiver_id = v_uid
          AND cm.is_read = false
      )
  ),
  last_msg AS (
    SELECT DISTINCT ON (cm.chat_id)
      cm.chat_id, cm.message, cm.created_at, cm.sender_id
    FROM public.chat_messages cm
    WHERE cm.chat_id IN (SELECT b.chat_id FROM base b)
    ORDER BY cm.chat_id, cm.created_at DESC
  ),
  unread AS (
    SELECT cm.chat_id, COUNT(*)::int AS cnt
    FROM public.chat_messages cm
    WHERE cm.chat_id IN (SELECT b.chat_id FROM base b)
      AND cm.receiver_id = v_uid
      AND cm.is_read = false
    GROUP BY cm.chat_id
  )
  SELECT
    b.chat_id::text,
    b.partner_id,
    COALESCE(p.full_name, 'User')::text,
    p.photo_url::text,
    COALESCE(lm.message, '')::text,
    COALESCE(lm.created_at, b.last_activity_at),
    lm.sender_id,
    COALESCE(u.cnt, 0),
    COALESCE(us.is_online, false),
    COALESCE(us.status, 'offline')::text,
    COALESCE(us.active_chat_count, 0),
    b.status::text
  FROM base b
  LEFT JOIN public.profiles p ON p.user_id = b.partner_id
  LEFT JOIN last_msg lm ON lm.chat_id = b.chat_id
  LEFT JOIN unread u    ON u.chat_id  = b.chat_id
  LEFT JOIN public.user_status us ON us.user_id = b.partner_id
  ORDER BY COALESCE(lm.created_at, b.last_activity_at) DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_man_active_chats(uuid) TO authenticated;

-- Woman's active chats: mirror, with man as partner
CREATE OR REPLACE FUNCTION public.get_woman_active_chats(p_user_id uuid)
RETURNS TABLE(
  chat_id text,
  partner_id uuid,
  partner_name text,
  partner_photo text,
  last_message text,
  last_message_at timestamptz,
  last_message_sender_id uuid,
  unread_count integer,
  partner_is_online boolean,
  partner_status text,
  partner_active_chat_count integer,
  session_status text
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := public.resolve_wallet_user_id(p_user_id);
BEGIN
  IF v_uid IS NULL THEN RETURN; END IF;
  IF auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_uid
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Not allowed';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT acs.chat_id, acs.man_user_id AS partner_id,
           acs.last_activity_at, acs.status
    FROM public.active_chat_sessions acs
    WHERE acs.woman_user_id = v_uid
      AND acs.status IN ('active','pending')
    UNION
    SELECT acs.chat_id, acs.man_user_id, acs.last_activity_at, acs.status
    FROM public.active_chat_sessions acs
    WHERE acs.woman_user_id = v_uid
      AND EXISTS (
        SELECT 1 FROM public.chat_messages cm
        WHERE cm.chat_id = acs.chat_id
          AND cm.receiver_id = v_uid
          AND cm.is_read = false
      )
  ),
  last_msg AS (
    SELECT DISTINCT ON (cm.chat_id)
      cm.chat_id, cm.message, cm.created_at, cm.sender_id
    FROM public.chat_messages cm
    WHERE cm.chat_id IN (SELECT b.chat_id FROM base b)
    ORDER BY cm.chat_id, cm.created_at DESC
  ),
  unread AS (
    SELECT cm.chat_id, COUNT(*)::int AS cnt
    FROM public.chat_messages cm
    WHERE cm.chat_id IN (SELECT b.chat_id FROM base b)
      AND cm.receiver_id = v_uid
      AND cm.is_read = false
    GROUP BY cm.chat_id
  )
  SELECT
    b.chat_id::text,
    b.partner_id,
    COALESCE(p.full_name, 'User')::text,
    p.photo_url::text,
    COALESCE(lm.message, '')::text,
    COALESCE(lm.created_at, b.last_activity_at),
    lm.sender_id,
    COALESCE(u.cnt, 0),
    COALESCE(us.is_online, false),
    COALESCE(us.status, 'offline')::text,
    COALESCE(us.active_chat_count, 0),
    b.status::text
  FROM base b
  LEFT JOIN public.profiles p ON p.user_id = b.partner_id
  LEFT JOIN last_msg lm ON lm.chat_id = b.chat_id
  LEFT JOIN unread u    ON u.chat_id  = b.chat_id
  LEFT JOIN public.user_status us ON us.user_id = b.partner_id
  ORDER BY COALESCE(lm.created_at, b.last_activity_at) DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_woman_active_chats(uuid) TO authenticated;
