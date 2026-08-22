-- Mutual engagement = both sides sent a real message (not 👋 join/leave lines).
-- Do NOT require left_at IS NULL here — that made post-session checks false and could
-- race with leave/end_live. Active men in the room is enforced separately by
-- group_chat_active_men_count inside bill_session_minute.

CREATE OR REPLACE FUNCTION public.group_chat_has_mutual_engagement(p_session_id uuid, p_host_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.group_chat_messages m
     WHERE m.session_id = p_session_id
       AND m.deleted_at IS NULL
       AND m.sender_id = p_host_id
       AND (
         (COALESCE(trim(m.body), '') <> '' AND left(trim(m.body), 1) <> '👋')
         OR COALESCE(m.media_url, '') <> ''
       )
  )
  AND EXISTS (
    SELECT 1
      FROM public.group_chat_messages m
     WHERE m.session_id = p_session_id
       AND m.deleted_at IS NULL
       AND m.sender_id IS DISTINCT FROM p_host_id
       AND (
         (COALESCE(trim(m.body), '') <> '' AND left(trim(m.body), 1) <> '👋')
         OR COALESCE(m.media_url, '') <> ''
       )
       AND EXISTS (
         SELECT 1
           FROM public.group_chat_participants gcp
          WHERE gcp.session_id = p_session_id
            AND gcp.user_id = m.sender_id
            AND gcp.user_id IS DISTINCT FROM p_host_id
       )
  );
$$;

GRANT EXECUTE ON FUNCTION public.group_chat_has_mutual_engagement(uuid, uuid) TO authenticated, service_role;
