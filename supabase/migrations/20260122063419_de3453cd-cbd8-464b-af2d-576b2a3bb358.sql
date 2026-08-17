-- Add fields to track monthly performance for rotation
ALTER TABLE public.female_profiles 
ADD COLUMN IF NOT EXISTS monthly_chat_minutes numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_rotation_date date,
ADD COLUMN IF NOT EXISTS promoted_from_free boolean DEFAULT false;

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS monthly_chat_minutes numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_rotation_date date,
ADD COLUMN IF NOT EXISTS promoted_from_free boolean DEFAULT false;

-- Add promotion limit per language to language_limits
ALTER TABLE public.language_limits 
ADD COLUMN IF NOT EXISTS max_monthly_promotions integer DEFAULT 10;

-- Function to calculate monthly chat time for a woman
CREATE OR REPLACE FUNCTION public.get_woman_monthly_chat_minutes(p_user_id uuid, p_month_start date)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_minutes numeric;
BEGIN
    SELECT COALESCE(SUM(total_minutes), 0) INTO v_total_minutes
    FROM public.active_chat_sessions
    WHERE woman_user_id = p_user_id
      AND started_at >= p_month_start
      AND started_at < (p_month_start + interval '1 month');
    
    RETURN v_total_minutes;
END;
$$;

-- Function to perform monthly rotation of earning slots
-- Called on 1st of each month
CREATE OR REPLACE FUNCTION public.perform_monthly_earning_rotation()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_language RECORD;
    v_woman RECORD;
    v_top_earner_minutes numeric;
    v_threshold_minutes numeric;
    v_demoted_count integer := 0;
    v_promoted_count integer := 0;
    v_month_start date;
    v_current_earning_count integer;
BEGIN
    -- Get first day of previous month for calculations
    v_month_start := date_trunc('month', current_date - interval '1 month')::date;
    
    -- Process each language
    FOR v_language IN 
        SELECT * FROM public.language_limits WHERE is_active = true
    LOOP
        -- Step 1: Find top earner's minutes for this language (paid users only)
        SELECT MAX(get_woman_monthly_chat_minutes(fp.user_id, v_month_start)) INTO v_top_earner_minutes
        FROM public.female_profiles fp
        WHERE fp.is_earning_eligible = true
          AND fp.country = 'India'
          AND LOWER(COALESCE(fp.primary_language, '')) = LOWER(v_language.language_name);
        
        IF v_top_earner_minutes IS NULL OR v_top_earner_minutes = 0 THEN
            v_top_earner_minutes := 1; -- Avoid division by zero
        END IF;
        
        -- Threshold is 10% of top earner
        v_threshold_minutes := v_top_earner_minutes * 0.10;
        
        -- Step 2: Demote paid women with less than 10% of top earner's time
        FOR v_woman IN 
            SELECT fp.id, fp.user_id, fp.full_name, 
                   get_woman_monthly_chat_minutes(fp.user_id, v_month_start) as monthly_minutes
            FROM public.female_profiles fp
            WHERE fp.is_earning_eligible = true
              AND fp.country = 'India'
              AND LOWER(COALESCE(fp.primary_language, '')) = LOWER(v_language.language_name)
        LOOP
            IF v_woman.monthly_minutes < v_threshold_minutes THEN
                -- Demote to free user
                UPDATE public.female_profiles
                SET is_earning_eligible = false,
                    earning_slot_assigned_at = NULL,
                    earning_badge_type = NULL,
                    monthly_chat_minutes = v_woman.monthly_minutes,
                    last_rotation_date = current_date,
                    updated_at = now()
                WHERE id = v_woman.id;
                
                UPDATE public.profiles
                SET is_earning_eligible = false,
                    earning_slot_assigned_at = NULL,
                    earning_badge_type = NULL,
                    monthly_chat_minutes = v_woman.monthly_minutes,
                    last_rotation_date = current_date,
                    updated_at = now()
                WHERE user_id = v_woman.user_id;
                
                v_demoted_count := v_demoted_count + 1;
            END IF;
        END LOOP;
        
        -- Step 3: Count current earning women after demotions
        SELECT COUNT(*) INTO v_current_earning_count
        FROM public.female_profiles fp
        WHERE fp.is_earning_eligible = true
          AND fp.country = 'India'
          AND LOWER(COALESCE(fp.primary_language, '')) = LOWER(v_language.language_name);
        
        -- Step 4: Promote top 5 free Indian women by chat time (up to 10 promotions, filling available slots)
        FOR v_woman IN 
            SELECT fp.id, fp.user_id, fp.full_name,
                   get_woman_monthly_chat_minutes(fp.user_id, v_month_start) as monthly_minutes
            FROM public.female_profiles fp
            WHERE fp.is_earning_eligible = false
              AND fp.country = 'India'
              AND LOWER(COALESCE(fp.primary_language, '')) = LOWER(v_language.language_name)
              AND fp.approval_status = 'approved'
              AND fp.account_status = 'active'
            ORDER BY get_woman_monthly_chat_minutes(fp.user_id, v_month_start) DESC
            LIMIT LEAST(5, v_language.max_earning_women - v_current_earning_count, v_language.max_monthly_promotions)
        LOOP
            -- Only promote if they have meaningful activity (at least some minutes)
            IF v_woman.monthly_minutes > 0 THEN
                -- Promote to paid user
                UPDATE public.female_profiles
                SET is_earning_eligible = true,
                    earning_slot_assigned_at = now(),
                    earning_badge_type = 'star',
                    monthly_chat_minutes = v_woman.monthly_minutes,
                    last_rotation_date = current_date,
                    promoted_from_free = true,
                    updated_at = now()
                WHERE id = v_woman.id;
                
                UPDATE public.profiles
                SET is_earning_eligible = true,
                    earning_slot_assigned_at = now(),
                    earning_badge_type = 'star',
                    monthly_chat_minutes = v_woman.monthly_minutes,
                    last_rotation_date = current_date,
                    promoted_from_free = true,
                    updated_at = now()
                WHERE user_id = v_woman.user_id;
                
                v_promoted_count := v_promoted_count + 1;
                v_current_earning_count := v_current_earning_count + 1;
            END IF;
        END LOOP;
        
        -- Update language limit count
        UPDATE public.language_limits
        SET current_earning_women = v_current_earning_count,
            updated_at = now()
        WHERE id = v_language.id;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'month_processed', v_month_start,
        'demoted', v_demoted_count,
        'promoted', v_promoted_count
    );
END;
$$;