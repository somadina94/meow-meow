-- Add account_status to profiles for block/suspend/approve status
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS account_status text NOT NULL DEFAULT 'active';

-- Add approval_status for women (men auto-approved)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'pending';

-- Add primary_language to profiles if not exists (for language group matching)
-- Already exists based on schema

-- Add max_women_users to language_groups table
ALTER TABLE public.language_groups 
ADD COLUMN IF NOT EXISTS max_women_users integer NOT NULL DEFAULT 100;

-- Add current_women_count to language_groups for tracking
ALTER TABLE public.language_groups 
ADD COLUMN IF NOT EXISTS current_women_count integer NOT NULL DEFAULT 0;

-- Create index for faster filtering
CREATE INDEX IF NOT EXISTS idx_profiles_account_status ON public.profiles(account_status);
CREATE INDEX IF NOT EXISTS idx_profiles_approval_status ON public.profiles(approval_status);
CREATE INDEX IF NOT EXISTS idx_profiles_gender ON public.profiles(gender);

-- Add comment for clarity
COMMENT ON COLUMN public.profiles.account_status IS 'User account status: active, blocked, suspended';
COMMENT ON COLUMN public.profiles.approval_status IS 'Approval status: pending, approved, disapproved (men auto-approved)';
COMMENT ON COLUMN public.language_groups.max_women_users IS 'Maximum number of women users allowed in this language group';
COMMENT ON COLUMN public.language_groups.current_women_count IS 'Current count of approved women users in this language group';