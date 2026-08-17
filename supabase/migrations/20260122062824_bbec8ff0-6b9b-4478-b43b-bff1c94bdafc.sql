-- Drop old function first
DROP FUNCTION IF EXISTS public.should_woman_earn(uuid);

-- Recreate function to check if a woman should earn
CREATE OR REPLACE FUNCTION public.should_woman_earn(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_eligible boolean;
BEGIN
    SELECT is_earning_eligible INTO v_is_eligible
    FROM public.female_profiles
    WHERE user_id = p_user_id;
    
    IF v_is_eligible IS NULL THEN
        SELECT is_earning_eligible INTO v_is_eligible
        FROM public.profiles
        WHERE user_id = p_user_id;
    END IF;
    
    RETURN COALESCE(v_is_eligible, false);
END;
$$;

-- Function to assign earning slots to Indian women based on language limits
CREATE OR REPLACE FUNCTION public.assign_earning_slots()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_language RECORD;
    v_woman RECORD;
    v_slots_assigned integer := 0;
    v_slots_removed integer := 0;
    v_current_count integer;
BEGIN
    -- First, reset all earning slots (as per user requirement: "Reset all slots")
    UPDATE public.female_profiles
    SET is_earning_eligible = false,
        earning_slot_assigned_at = NULL,
        earning_badge_type = NULL
    WHERE is_earning_eligible = true;
    
    UPDATE public.profiles
    SET is_earning_eligible = false,
        earning_slot_assigned_at = NULL,
        earning_badge_type = NULL
    WHERE is_earning_eligible = true;
    
    -- Reset all language_limits current_earning_women counts
    UPDATE public.language_limits
    SET current_earning_women = 0,
        updated_at = now();
    
    -- For each language, assign slots to Indian women (first registered priority)
    FOR v_language IN 
        SELECT * FROM public.language_limits WHERE is_active = true
    LOOP
        v_current_count := 0;
        
        -- Get Indian women for this language, ordered by created_at (first registered first)
        FOR v_woman IN 
            SELECT fp.id, fp.user_id, fp.full_name, fp.primary_language, fp.created_at
            FROM public.female_profiles fp
            WHERE fp.country = 'India'
              AND fp.approval_status = 'approved'
              AND fp.account_status = 'active'
              AND LOWER(COALESCE(fp.primary_language, '')) = LOWER(v_language.language_name)
            ORDER BY fp.created_at ASC
            LIMIT v_language.max_earning_women
        LOOP
            -- Assign earning slot
            UPDATE public.female_profiles
            SET is_earning_eligible = true,
                is_indian = true,
                earning_slot_assigned_at = now(),
                earning_badge_type = 'star',
                updated_at = now()
            WHERE id = v_woman.id;
            
            -- Sync to profiles table
            UPDATE public.profiles
            SET is_earning_eligible = true,
                is_indian = true,
                earning_slot_assigned_at = now(),
                earning_badge_type = 'star',
                updated_at = now()
            WHERE user_id = v_woman.user_id;
            
            v_current_count := v_current_count + 1;
            v_slots_assigned := v_slots_assigned + 1;
        END LOOP;
        
        -- Update the language limit current count
        UPDATE public.language_limits
        SET current_earning_women = v_current_count,
            updated_at = now()
        WHERE id = v_language.id;
    END LOOP;
    
    -- Mark all other Indian women as is_indian but not earning eligible
    UPDATE public.female_profiles
    SET is_indian = true
    WHERE country = 'India'
      AND is_indian IS NOT true;
    
    UPDATE public.profiles
    SET is_indian = true
    WHERE country = 'India'
      AND is_indian IS NOT true
      AND gender = 'female';
    
    RETURN jsonb_build_object(
        'success', true,
        'slots_assigned', v_slots_assigned,
        'message', 'Earning slots assigned to Indian women based on language limits'
    );
END;
$$;