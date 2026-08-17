-- Create KYC table for Indian women users
CREATE TABLE public.women_kyc (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  
  -- Basic Details
  full_name_as_per_bank TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  gender TEXT,
  country_of_residence TEXT NOT NULL DEFAULT 'India',
  
  -- Bank Details
  bank_name TEXT NOT NULL,
  account_holder_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  ifsc_code TEXT NOT NULL,
  
  -- KYC Documents
  id_type TEXT NOT NULL CHECK (id_type IN ('aadhaar', 'pan', 'passport', 'voter_id')),
  id_number TEXT NOT NULL,
  document_front_url TEXT,
  document_back_url TEXT,
  selfie_url TEXT,
  
  -- Verification Status
  verification_status TEXT NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending', 'under_review', 'approved', 'rejected')),
  rejection_reason TEXT,
  verified_at TIMESTAMP WITH TIME ZONE,
  verified_by UUID,
  
  -- Compliance
  consent_given BOOLEAN NOT NULL DEFAULT false,
  consent_timestamp TIMESTAMP WITH TIME ZONE,
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.women_kyc ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own KYC
CREATE POLICY "Users can view own KYC"
ON public.women_kyc
FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert their own KYC (only once)
CREATE POLICY "Users can create own KYC"
ON public.women_kyc
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own KYC only if not yet approved
CREATE POLICY "Users can update own pending KYC"
ON public.women_kyc
FOR UPDATE
USING (auth.uid() = user_id AND verification_status IN ('pending', 'rejected'));

-- Admins can view all KYC records
CREATE POLICY "Admins can view all KYC"
ON public.women_kyc
FOR SELECT
USING (public.has_role(auth.uid(), 'admin'));

-- Admins can update KYC status
CREATE POLICY "Admins can update KYC"
ON public.women_kyc
FOR UPDATE
USING (public.has_role(auth.uid(), 'admin'));

-- Create updated_at trigger
CREATE TRIGGER update_women_kyc_updated_at
BEFORE UPDATE ON public.women_kyc
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Create storage bucket for KYC documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('kyc-documents', 'kyc-documents', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for KYC documents
CREATE POLICY "Users can upload own KYC documents"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'kyc-documents' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can view own KYC documents"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'kyc-documents' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Admins can view all KYC documents"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'kyc-documents' 
  AND public.has_role(auth.uid(), 'admin')
);

-- Create index for faster lookups
CREATE INDEX idx_women_kyc_user_id ON public.women_kyc(user_id);
CREATE INDEX idx_women_kyc_status ON public.women_kyc(verification_status);