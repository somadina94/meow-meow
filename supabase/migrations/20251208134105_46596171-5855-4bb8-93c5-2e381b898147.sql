-- Add notifications table to realtime publication for real-time updates
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- Add to supabase_realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;