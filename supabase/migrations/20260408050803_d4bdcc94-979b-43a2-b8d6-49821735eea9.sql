
-- Add 'completed' to the status check constraint
ALTER TABLE public.video_call_sessions DROP CONSTRAINT video_call_sessions_status_check;
ALTER TABLE public.video_call_sessions ADD CONSTRAINT video_call_sessions_status_check 
  CHECK (status = ANY (ARRAY['pending','ringing','connecting','active','ended','completed','declined','missed','timeout_cleanup']));
