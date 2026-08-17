-- Update default max_women_users to 150
ALTER TABLE public.language_groups 
ALTER COLUMN max_women_users SET DEFAULT 150;

-- Update existing language groups to have 150 max women users
UPDATE public.language_groups SET max_women_users = 150 WHERE max_women_users = 100;

-- Add performance tracking columns to profiles for women
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS performance_score integer DEFAULT 100,
ADD COLUMN IF NOT EXISTS total_chats_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS avg_response_time_seconds integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS ai_approved boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS ai_disapproval_reason text;

-- Create index for performance queries
CREATE INDEX IF NOT EXISTS idx_profiles_performance ON public.profiles(performance_score);
CREATE INDEX IF NOT EXISTS idx_profiles_last_active ON public.profiles(last_active_at);
CREATE INDEX IF NOT EXISTS idx_profiles_ai_approved ON public.profiles(ai_approved);

-- Add comments
COMMENT ON COLUMN public.profiles.performance_score IS 'AI calculated performance score 0-100';
COMMENT ON COLUMN public.profiles.ai_approved IS 'Whether AI auto-approved this user';
COMMENT ON COLUMN public.profiles.ai_disapproval_reason IS 'Reason for AI disapproval if any';