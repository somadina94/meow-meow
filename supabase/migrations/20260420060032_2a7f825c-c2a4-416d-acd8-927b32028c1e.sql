-- Remove Golden Badge subscription system entirely

-- 1. Drop trigger + supporting function
DROP TRIGGER IF EXISTS sync_golden_badge_trigger ON public.profiles;
DROP FUNCTION IF EXISTS public.sync_golden_badge_to_female() CASCADE;

-- 2. Drop dependent view
DROP VIEW IF EXISTS public.public_female_profiles;

-- 3. Drop the dedicated RPC
DROP FUNCTION IF EXISTS public.purchase_golden_badge(uuid);

-- 4. Drop the subscriptions table
DROP TABLE IF EXISTS public.golden_badge_subscriptions CASCADE;

-- 5. Drop columns from female_profiles
ALTER TABLE public.female_profiles
  DROP COLUMN IF EXISTS has_golden_badge,
  DROP COLUMN IF EXISTS golden_badge_expires_at;

-- 6. Drop columns from profiles
ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS has_golden_badge,
  DROP COLUMN IF EXISTS golden_badge_expires_at;

-- 7. Recreate the public_female_profiles view without golden badge fields
CREATE VIEW public.public_female_profiles AS
SELECT id,
    user_id,
    full_name,
    photo_url,
    age,
    country,
    state,
    primary_language,
    preferred_language,
    bio,
    interests,
    is_earning_eligible,
    is_indian,
    is_premium,
    is_verified,
    earning_badge_type,
    approval_status,
    account_status,
    last_active_at,
    created_at
FROM public.female_profiles
WHERE approval_status = 'approved'::text AND account_status = 'active'::text;
