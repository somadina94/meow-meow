-- Create tutorial_progress table for tracking onboarding progress
CREATE TABLE public.tutorial_progress (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  current_step INTEGER NOT NULL DEFAULT 0,
  completed BOOLEAN NOT NULL DEFAULT false,
  skipped BOOLEAN DEFAULT false,
  steps_viewed INTEGER[] DEFAULT ARRAY[]::INTEGER[],
  theme_preference TEXT DEFAULT 'blue',
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.tutorial_progress ENABLE ROW LEVEL SECURITY;

-- Create policies for user access
CREATE POLICY "Users can view their own tutorial progress" 
ON public.tutorial_progress 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tutorial progress" 
ON public.tutorial_progress 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tutorial progress" 
ON public.tutorial_progress 
FOR UPDATE 
USING (auth.uid() = user_id);

-- Add trigger for updated_at
CREATE TRIGGER update_tutorial_progress_updated_at
BEFORE UPDATE ON public.tutorial_progress
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();