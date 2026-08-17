-- Create archive bucket for old payout Excel snapshots
INSERT INTO storage.buckets (id, name, public)
VALUES ('payout-exports-archive', 'payout-exports-archive', false)
ON CONFLICT (id) DO NOTHING;

-- RLS policies: admin + service_role only
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Admins can read payout archive'
  ) THEN
    CREATE POLICY "Admins can read payout archive"
      ON storage.objects FOR SELECT
      USING (
        bucket_id = 'payout-exports-archive'
        AND (public.has_role(auth.uid(), 'admin') OR auth.role() = 'service_role')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Admins can write payout archive'
  ) THEN
    CREATE POLICY "Admins can write payout archive"
      ON storage.objects FOR INSERT
      WITH CHECK (
        bucket_id = 'payout-exports-archive'
        AND (public.has_role(auth.uid(), 'admin') OR auth.role() = 'service_role')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Admins can delete payout archive'
  ) THEN
    CREATE POLICY "Admins can delete payout archive"
      ON storage.objects FOR DELETE
      USING (
        bucket_id = 'payout-exports-archive'
        AND (public.has_role(auth.uid(), 'admin') OR auth.role() = 'service_role')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Admins can update payout archive'
  ) THEN
    CREATE POLICY "Admins can update payout archive"
      ON storage.objects FOR UPDATE
      USING (
        bucket_id = 'payout-exports-archive'
        AND (public.has_role(auth.uid(), 'admin') OR auth.role() = 'service_role')
      );
  END IF;
END $$;
