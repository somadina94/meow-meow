-- Create video call sessions table
CREATE TABLE public.video_call_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  call_id text NOT NULL UNIQUE,
  man_user_id uuid NOT NULL,
  woman_user_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending', -- pending, ringing, active, ended, declined, missed
  started_at timestamp with time zone,
  ended_at timestamp with time zone,
  end_reason text,
  rate_per_minute numeric NOT NULL DEFAULT 5.00,
  total_minutes numeric NOT NULL DEFAULT 0,
  total_earned numeric NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Create language limits table for admin to set max women per language
CREATE TABLE public.language_limits (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  language_name text NOT NULL UNIQUE,
  max_chat_women integer NOT NULL DEFAULT 50,
  max_call_women integer NOT NULL DEFAULT 20,
  current_chat_women integer NOT NULL DEFAULT 0,
  current_call_women integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Add last_activity_at and auto_approved fields to female_profiles if not exists
ALTER TABLE public.female_profiles 
ADD COLUMN IF NOT EXISTS auto_approved boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS suspended_at timestamp with time zone,
ADD COLUMN IF NOT EXISTS suspension_reason text;

-- Add video call availability to women_availability
ALTER TABLE public.women_availability 
ADD COLUMN IF NOT EXISTS is_available_for_calls boolean DEFAULT true,
ADD COLUMN IF NOT EXISTS current_call_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS max_concurrent_calls integer DEFAULT 1;

-- Enable RLS
ALTER TABLE public.video_call_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.language_limits ENABLE ROW LEVEL SECURITY;

-- RLS policies for video_call_sessions
CREATE POLICY "Users can view their own video calls" 
ON public.video_call_sessions 
FOR SELECT 
USING ((auth.uid() = man_user_id) OR (auth.uid() = woman_user_id));

CREATE POLICY "Men can insert video calls" 
ON public.video_call_sessions 
FOR INSERT 
WITH CHECK (auth.uid() = man_user_id);

CREATE POLICY "Users can update their own video calls" 
ON public.video_call_sessions 
FOR UPDATE 
USING ((auth.uid() = man_user_id) OR (auth.uid() = woman_user_id));

CREATE POLICY "Admins can view all video calls" 
ON public.video_call_sessions 
FOR SELECT 
USING (has_role(auth.uid(), 'admin'::app_role));

-- RLS policies for language_limits
CREATE POLICY "Anyone can view language limits" 
ON public.language_limits 
FOR SELECT 
USING (true);

CREATE POLICY "Admins can manage language limits" 
ON public.language_limits 
FOR ALL 
USING (has_role(auth.uid(), 'admin'::app_role));

-- Create trigger for updated_at
CREATE TRIGGER update_video_call_sessions_updated_at
BEFORE UPDATE ON public.video_call_sessions
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_language_limits_updated_at
BEFORE UPDATE ON public.language_limits
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Seed initial language limits for common languages
INSERT INTO public.language_limits (language_name, max_chat_women, max_call_women) VALUES
('Hindi', 100, 30),
('English', 100, 30),
('Tamil', 50, 20),
('Telugu', 50, 20),
('Bengali', 50, 20),
('Marathi', 50, 20),
('Gujarati', 40, 15),
('Kannada', 40, 15),
('Malayalam', 40, 15),
('Punjabi', 40, 15),
('Odia', 30, 10),
('Urdu', 30, 10),
('Arabic', 30, 10),
('Spanish', 30, 10),
('French', 30, 10),
('German', 20, 10),
('Portuguese', 20, 10),
('Chinese', 20, 10),
('Japanese', 20, 10),
('Korean', 20, 10)
ON CONFLICT (language_name) DO NOTHING;