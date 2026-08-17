-- Create user_consent table for storing legal consent with timestamps
CREATE TABLE public.user_consent (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  agreed_terms BOOLEAN NOT NULL DEFAULT false,
  terms_version TEXT NOT NULL DEFAULT '1.0',
  gdpr_consent BOOLEAN DEFAULT false,
  ccpa_consent BOOLEAN DEFAULT false,
  dpdp_consent BOOLEAN DEFAULT false,
  consent_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.user_consent ENABLE ROW LEVEL SECURITY;

-- Create policies for user access
CREATE POLICY "Users can view their own consent" 
ON public.user_consent 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own consent" 
ON public.user_consent 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own consent" 
ON public.user_consent 
FOR UPDATE 
USING (auth.uid() = user_id);

-- Add trigger for updated_at
CREATE TRIGGER update_user_consent_updated_at
BEFORE UPDATE ON public.user_consent
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();