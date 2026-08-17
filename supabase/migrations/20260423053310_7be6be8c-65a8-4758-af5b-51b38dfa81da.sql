-- Function to delete chat messages older than 7 days
CREATE OR REPLACE FUNCTION public.cleanup_old_chat_messages()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
BEGIN
  -- Delete message reactions linked to old messages first (FK)
  DELETE FROM public.message_reactions
  WHERE message_id IN (
    SELECT id FROM public.chat_messages
    WHERE created_at < (now() - interval '7 days')
  );

  -- Delete chat messages older than 7 days
  DELETE FROM public.chat_messages
  WHERE created_at < (now() - interval '7 days');

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE '[cleanup_old_chat_messages] Deleted % messages older than 7 days', deleted_count;
END;
$$;

-- Remove any previous schedule with the same name (ignore if not exists), then schedule daily at 03:00 UTC
DO $$
BEGIN
  PERFORM cron.unschedule('cleanup-chat-messages-7days');
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

SELECT cron.schedule(
  'cleanup-chat-messages-7days',
  '0 3 * * *',
  $$ SELECT public.cleanup_old_chat_messages(); $$
);