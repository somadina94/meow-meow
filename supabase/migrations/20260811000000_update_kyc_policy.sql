DROP POLICY IF EXISTS "Users can update own pending KYC" ON public.women_kyc;

CREATE POLICY "Users can update own KYC"
ON public.women_kyc
FOR UPDATE
USING (auth.uid() = user_id);
