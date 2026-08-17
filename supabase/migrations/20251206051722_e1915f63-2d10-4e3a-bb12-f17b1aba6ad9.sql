-- Create processing_logs table for AI verification status tracking
CREATE TABLE public.processing_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  processing_status TEXT NOT NULL DEFAULT 'pending',
  current_step TEXT,
  progress_percent INTEGER DEFAULT 0,
  gender_verified BOOLEAN DEFAULT false,
  age_verified BOOLEAN DEFAULT false,
  language_detected BOOLEAN DEFAULT false,
  photo_verified BOOLEAN DEFAULT false,
  errors TEXT[] DEFAULT ARRAY[]::TEXT[],
  started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.processing_logs ENABLE ROW LEVEL SECURITY;

-- Create policies for user access
CREATE POLICY "Users can view their own processing logs" 
ON public.processing_logs 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own processing logs" 
ON public.processing_logs 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own processing logs" 
ON public.processing_logs 
FOR UPDATE 
USING (auth.uid() = user_id);

-- Add trigger for updated_at
CREATE TRIGGER update_processing_logs_updated_at
BEFORE UPDATE ON public.processing_logs
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();