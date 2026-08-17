-- 1. Create private backups bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('backups', 'backups', false, 524288000, ARRAY['application/json'])
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 524288000,
  allowed_mime_types = ARRAY['application/json'];

-- 2. Storage policies — admins only
CREATE POLICY "Admins can read backups"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'backups' AND public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can upload backups"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'backups' AND public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can update backups"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'backups' AND public.has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can delete backups"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'backups' AND public.has_role(auth.uid(), 'admin'::app_role));

-- 3. Enable realtime on backup_logs
ALTER TABLE public.backup_logs REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.backup_logs;

-- 4. Auto-mark stalled in_progress backups as failed (called by client on load)
CREATE OR REPLACE FUNCTION public.mark_stalled_backups()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  affected integer;
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin'::app_role) THEN
    RAISE EXCEPTION 'admin role required';
  END IF;

  UPDATE public.backup_logs
  SET status = 'failed',
      error_message = COALESCE(error_message, '') || ' [Backup stalled — exceeded 30 min in_progress]',
      completed_at = COALESCE(completed_at, now())
  WHERE status = 'in_progress'
    AND started_at < (now() - interval '30 minutes');

  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_stalled_backups() TO authenticated;