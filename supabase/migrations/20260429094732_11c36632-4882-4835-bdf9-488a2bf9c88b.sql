-- Create payout-exports storage bucket for archived payout Excel snapshots
INSERT INTO storage.buckets (id, name, public)
VALUES ('payout-exports', 'payout-exports', false)
ON CONFLICT (id) DO NOTHING;

-- Admins can read all payout exports
CREATE POLICY "Admins can read payout exports"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'payout-exports' AND public.has_role(auth.uid(), 'admin'));

-- Admins can upload payout exports
CREATE POLICY "Admins can upload payout exports"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'payout-exports' AND public.has_role(auth.uid(), 'admin'));

-- Service role (edge functions) can insert payout exports for monthly auto-run
CREATE POLICY "Service role can manage payout exports"
ON storage.objects FOR ALL
TO service_role
USING (bucket_id = 'payout-exports')
WITH CHECK (bucket_id = 'payout-exports');