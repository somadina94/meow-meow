-- Enable realtime (postgres_changes) for video calls so women receive incoming call events
ALTER PUBLICATION supabase_realtime ADD TABLE public.video_call_sessions;