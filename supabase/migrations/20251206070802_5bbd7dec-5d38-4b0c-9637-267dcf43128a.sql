-- Add extended profile attributes for filtering
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS age integer,
ADD COLUMN IF NOT EXISTS height_cm integer,
ADD COLUMN IF NOT EXISTS body_type text,
ADD COLUMN IF NOT EXISTS education_level text,
ADD COLUMN IF NOT EXISTS occupation text,
ADD COLUMN IF NOT EXISTS religion text,
ADD COLUMN IF NOT EXISTS marital_status text DEFAULT 'single',
ADD COLUMN IF NOT EXISTS has_children boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS smoking_habit text DEFAULT 'never',
ADD COLUMN IF NOT EXISTS drinking_habit text DEFAULT 'never',
ADD COLUMN IF NOT EXISTS dietary_preference text DEFAULT 'no_preference',
ADD COLUMN IF NOT EXISTS fitness_level text DEFAULT 'moderate',
ADD COLUMN IF NOT EXISTS pet_preference text,
ADD COLUMN IF NOT EXISTS travel_frequency text DEFAULT 'occasionally',
ADD COLUMN IF NOT EXISTS personality_type text,
ADD COLUMN IF NOT EXISTS zodiac_sign text,
ADD COLUMN IF NOT EXISTS bio text,
ADD COLUMN IF NOT EXISTS profile_completeness integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_verified boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS is_premium boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS last_active_at timestamp with time zone DEFAULT now(),
ADD COLUMN IF NOT EXISTS life_goals text[],
ADD COLUMN IF NOT EXISTS interests text[];

-- Create index for common filter queries
CREATE INDEX IF NOT EXISTS idx_profiles_gender ON public.profiles(gender);
CREATE INDEX IF NOT EXISTS idx_profiles_country ON public.profiles(country);
CREATE INDEX IF NOT EXISTS idx_profiles_age ON public.profiles(age);
CREATE INDEX IF NOT EXISTS idx_profiles_is_verified ON public.profiles(is_verified);
CREATE INDEX IF NOT EXISTS idx_profiles_last_active_at ON public.profiles(last_active_at);