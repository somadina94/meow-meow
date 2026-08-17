-- Add index for sorting groups by participant count
CREATE INDEX IF NOT EXISTS idx_private_groups_participant_count ON public.private_groups(participant_count DESC, created_at DESC);

-- Create function to cleanup old group messages (5 minutes)
CREATE OR REPLACE FUNCTION public.cleanup_old_group_messages()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  DELETE FROM public.group_messages 
  WHERE created_at < NOW() - INTERVAL '5 minutes';
END;
$$;

-- Create function to cleanup old video sessions (15 minutes)
CREATE OR REPLACE FUNCTION public.cleanup_old_group_video_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Reset is_live and stream_id for groups inactive for 15 minutes
  UPDATE public.private_groups
  SET is_live = false, stream_id = NULL
  WHERE is_live = true 
  AND updated_at < NOW() - INTERVAL '15 minutes';
END;
$$;