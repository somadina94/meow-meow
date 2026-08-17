
-- Fix duplicate RLS policy names that cause deployment failures
-- This migration drops-if-exists before re-creating to make the migration history idempotent

-- 1. "Admins can view all wallets" on public.wallets
--    Created in 20251206072223, dropped in 20251214090553, re-created WITHOUT drop in 20251226040726
DROP POLICY IF EXISTS "Admins can view all wallets" ON public.wallets;
CREATE POLICY "Admins can view all wallets"
ON public.wallets
FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));

-- 2. "Admins can view all KYC documents" on storage.objects
--    Created in 20260201033419, duplicated WITHOUT drop in 20260314170233
DROP POLICY IF EXISTS "Admins can view all KYC documents" ON storage.objects;
CREATE POLICY "Admins can view all KYC documents"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'kyc-documents'
  AND public.has_role(auth.uid(), 'admin')
);

-- 3. "Authenticated users can view women availability" on public.women_availability
--    Created in 20251214084310, duplicated WITHOUT drop in 20260316141645
DROP POLICY IF EXISTS "Authenticated users can view women availability" ON public.women_availability;
CREATE POLICY "Authenticated users can view women availability"
ON public.women_availability
FOR SELECT
TO authenticated
USING (true);

-- 4. "admin_women_availability_all" on public.women_availability (also from the same duplicate migration)
DROP POLICY IF EXISTS "admin_women_availability_all" ON public.women_availability;
CREATE POLICY "admin_women_availability_all"
ON public.women_availability
FOR ALL
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
