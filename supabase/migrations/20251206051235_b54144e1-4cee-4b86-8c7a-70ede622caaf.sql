-- Create user_languages table for storing optional language preferences
CREATE TABLE public.user_languages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  language_code TEXT NOT NULL,
  language_name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, language_code)
);

-- Enable Row Level Security
ALTER TABLE public.user_languages ENABLE ROW LEVEL SECURITY;

-- Create policies for user access
CREATE POLICY "Users can view their own languages" 
ON public.user_languages 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own languages" 
ON public.user_languages 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own languages" 
ON public.user_languages 
FOR DELETE 
USING (auth.uid() = user_id);