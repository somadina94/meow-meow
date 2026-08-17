
-- Add separate address proof (Aadhaar) and ID proof columns
ALTER TABLE public.women_kyc 
  ADD COLUMN IF NOT EXISTS aadhaar_number text,
  ADD COLUMN IF NOT EXISTS aadhaar_front_url text,
  ADD COLUMN IF NOT EXISTS aadhaar_back_url text,
  ADD COLUMN IF NOT EXISTS id_proof_front_url text,
  ADD COLUMN IF NOT EXISTS id_proof_back_url text;

-- Migrate existing aadhaar data to new columns
UPDATE public.women_kyc 
SET aadhaar_number = id_number,
    aadhaar_front_url = document_front_url,
    aadhaar_back_url = document_back_url
WHERE id_type = 'aadhaar';

-- For non-aadhaar entries, move to id_proof columns
UPDATE public.women_kyc 
SET id_proof_front_url = document_front_url,
    id_proof_back_url = document_back_url
WHERE id_type != 'aadhaar';
