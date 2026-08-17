
-- Create male_profiles table
CREATE TABLE public.male_profiles (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE,
  full_name text,
  date_of_birth date,
  age integer,
  phone text,
  bio text,
  photo_url text,
  country text,
  state text,
  occupation text,
  education_level text,
  body_type text,
  height_cm integer,
  marital_status text DEFAULT 'single',
  religion text,
  interests text[],
  life_goals text[],
  primary_language text,
  preferred_language text,
  is_verified boolean DEFAULT false,
  is_premium boolean DEFAULT false,
  account_status text NOT NULL DEFAULT 'active',
  profile_completeness integer DEFAULT 0,
  last_active_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Create female_profiles table
CREATE TABLE public.female_profiles (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE,
  full_name text,
  date_of_birth date,
  age integer,
  phone text,
  bio text,
  photo_url text,
  country text,
  state text,
  occupation text,
  education_level text,
  body_type text,
  height_cm integer,
  marital_status text DEFAULT 'single',
  religion text,
  interests text[],
  life_goals text[],
  primary_language text,
  preferred_language text,
  is_verified boolean DEFAULT false,
  is_premium boolean DEFAULT false,
  account_status text NOT NULL DEFAULT 'active',
  approval_status text NOT NULL DEFAULT 'pending',
  ai_approved boolean DEFAULT false,
  ai_disapproval_reason text,
  performance_score integer DEFAULT 100,
  avg_response_time_seconds integer DEFAULT 0,
  total_chats_count integer DEFAULT 0,
  profile_completeness integer DEFAULT 0,
  last_active_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS on both tables
ALTER TABLE public.male_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.female_profiles ENABLE ROW LEVEL SECURITY;

-- RLS policies for male_profiles
CREATE POLICY "Users can view their own male profile" ON public.male_profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own male profile" ON public.male_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own male profile" ON public.male_profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all male profiles" ON public.male_profiles
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can update all male profiles" ON public.male_profiles
  FOR UPDATE USING (has_role(auth.uid(), 'admin'::app_role));

-- RLS policies for female_profiles
CREATE POLICY "Users can view their own female profile" ON public.female_profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own female profile" ON public.female_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own female profile" ON public.female_profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all female profiles" ON public.female_profiles
  FOR SELECT USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can update all female profiles" ON public.female_profiles
  FOR UPDATE USING (has_role(auth.uid(), 'admin'::app_role));

-- Policy for women to be visible to men for matching
CREATE POLICY "Approved women visible to authenticated users" ON public.female_profiles
  FOR SELECT USING (approval_status = 'approved' AND account_status = 'active');

-- Triggers for updated_at
CREATE TRIGGER update_male_profiles_updated_at
  BEFORE UPDATE ON public.male_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER update_female_profiles_updated_at
  BEFORE UPDATE ON public.female_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
