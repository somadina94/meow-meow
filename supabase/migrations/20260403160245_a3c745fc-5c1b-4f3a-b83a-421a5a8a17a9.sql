
-- =============================================
-- FIX 1: Remove direct wallet UPDATE policy for users
-- =============================================
DROP POLICY IF EXISTS "Users can update their own wallet" ON public.wallets;

-- Add trigger to prevent direct balance updates except from service_role
CREATE OR REPLACE FUNCTION public.prevent_direct_wallet_balance_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Allow if balance hasn't changed
  IF NEW.balance = OLD.balance THEN
    RETURN NEW;
  END IF;
  
  -- Allow service_role to update balance (used by atomic RPCs)
  IF current_setting('role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;
  
  -- Block direct balance modifications from regular users
  RAISE EXCEPTION 'Direct wallet balance modification is not allowed. Use the provided payment functions.';
END;
$$;

DROP TRIGGER IF EXISTS prevent_wallet_balance_direct_update ON public.wallets;
CREATE TRIGGER prevent_wallet_balance_direct_update
  BEFORE UPDATE ON public.wallets
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_direct_wallet_balance_update();

-- =============================================
-- FIX 2: Make selfies bucket private
-- =============================================
UPDATE storage.buckets SET public = false WHERE id = 'selfies';

-- Add policy for admins to view selfies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname = 'Admins can view selfies' 
    AND tablename = 'objects' 
    AND schemaname = 'storage'
  ) THEN
    CREATE POLICY "Admins can view selfies"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'selfies' AND has_role(auth.uid(), 'admin'::app_role));
  END IF;
END $$;

-- Add policy for users to view their own selfies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname = 'Users can view own selfies' 
    AND tablename = 'objects' 
    AND schemaname = 'storage'
  ) THEN
    CREATE POLICY "Users can view own selfies"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'selfies' AND (auth.uid())::text = (storage.foldername(name))[1]);
  END IF;
END $$;

-- Add policy for users to upload their own selfies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname = 'Users can upload own selfies' 
    AND tablename = 'objects' 
    AND schemaname = 'storage'
  ) THEN
    CREATE POLICY "Users can upload own selfies"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'selfies' AND (auth.uid())::text = (storage.foldername(name))[1]);
  END IF;
END $$;

-- =============================================
-- FIX 3: Ensure password_reset_tokens has RLS with deny-all
-- =============================================
ALTER TABLE public.password_reset_tokens ENABLE ROW LEVEL SECURITY;

-- Drop any existing permissive policies that might exist
DROP POLICY IF EXISTS "Anyone can read tokens" ON public.password_reset_tokens;
DROP POLICY IF EXISTS "Users can read tokens" ON public.password_reset_tokens;

-- No policies = deny-all for anon/authenticated, only service_role can access

-- =============================================
-- FIX 4: Harden women_kyc policies to authenticated role
-- =============================================
DROP POLICY IF EXISTS "Users can create own KYC" ON public.women_kyc;
CREATE POLICY "Users can create own KYC"
ON public.women_kyc FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own pending KYC" ON public.women_kyc;
CREATE POLICY "Users can update own pending KYC"
ON public.women_kyc FOR UPDATE
TO authenticated
USING (auth.uid() = user_id AND verification_status IN ('pending', 'rejected'));

DROP POLICY IF EXISTS "Users can view own KYC" ON public.women_kyc;
CREATE POLICY "Users can view own KYC"
ON public.women_kyc FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Fix KYC document storage policies to use authenticated role
DROP POLICY IF EXISTS "Users can upload own KYC documents" ON storage.objects;
CREATE POLICY "Users can upload own KYC documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'kyc-documents' AND (auth.uid())::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Users can view own KYC documents" ON storage.objects;
CREATE POLICY "Users can view own KYC documents"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'kyc-documents' AND (auth.uid())::text = (storage.foldername(name))[1]);

-- =============================================
-- FIX 5: Add user SELECT policy for monthly_statements
-- =============================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname = 'Users can view own statements' 
    AND tablename = 'monthly_statements'
  ) THEN
    CREATE POLICY "Users can view own statements"
    ON public.monthly_statements FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);
  END IF;
END $$;
