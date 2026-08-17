-- Create function to sync profiles to gender-specific tables
CREATE OR REPLACE FUNCTION public.sync_profile_to_gender_tables()
RETURNS TRIGGER AS $$
BEGIN
  -- Only proceed if gender is set
  IF NEW.gender IS NULL THEN
    RETURN NEW;
  END IF;

  -- Sync to male_profiles if male
  IF NEW.gender = 'male' OR NEW.gender = 'Male' THEN
    INSERT INTO public.male_profiles (
      user_id,
      full_name,
      age,
      date_of_birth,
      phone,
      photo_url,
      bio,
      country,
      state,
      primary_language,
      preferred_language,
      interests,
      life_goals,
      occupation,
      education_level,
      height_cm,
      body_type,
      marital_status,
      religion,
      is_verified,
      is_premium,
      account_status,
      last_active_at,
      profile_completeness,
      created_at,
      updated_at
    ) VALUES (
      NEW.user_id,
      NEW.full_name,
      NEW.age,
      NEW.date_of_birth,
      NEW.phone,
      NEW.photo_url,
      NEW.bio,
      NEW.country,
      NEW.state,
      NEW.primary_language,
      NEW.preferred_language,
      NEW.interests,
      NEW.life_goals,
      NEW.occupation,
      NEW.education_level,
      NEW.height_cm,
      NEW.body_type,
      NEW.marital_status,
      NEW.religion,
      NEW.is_verified,
      NEW.is_premium,
      NEW.account_status,
      NEW.last_active_at,
      NEW.profile_completeness,
      COALESCE(NEW.created_at, now()),
      now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
      full_name = EXCLUDED.full_name,
      age = EXCLUDED.age,
      date_of_birth = EXCLUDED.date_of_birth,
      phone = EXCLUDED.phone,
      photo_url = EXCLUDED.photo_url,
      bio = EXCLUDED.bio,
      country = EXCLUDED.country,
      state = EXCLUDED.state,
      primary_language = EXCLUDED.primary_language,
      preferred_language = EXCLUDED.preferred_language,
      interests = EXCLUDED.interests,
      life_goals = EXCLUDED.life_goals,
      occupation = EXCLUDED.occupation,
      education_level = EXCLUDED.education_level,
      height_cm = EXCLUDED.height_cm,
      body_type = EXCLUDED.body_type,
      marital_status = EXCLUDED.marital_status,
      religion = EXCLUDED.religion,
      is_verified = EXCLUDED.is_verified,
      is_premium = EXCLUDED.is_premium,
      account_status = EXCLUDED.account_status,
      last_active_at = EXCLUDED.last_active_at,
      profile_completeness = EXCLUDED.profile_completeness,
      updated_at = now();

    -- Clean up from female_profiles if exists
    DELETE FROM public.female_profiles WHERE user_id = NEW.user_id;
  END IF;

  -- Sync to female_profiles if female
  IF NEW.gender = 'female' OR NEW.gender = 'Female' THEN
    INSERT INTO public.female_profiles (
      user_id,
      full_name,
      age,
      date_of_birth,
      phone,
      photo_url,
      bio,
      country,
      state,
      primary_language,
      preferred_language,
      interests,
      life_goals,
      occupation,
      education_level,
      height_cm,
      body_type,
      marital_status,
      religion,
      is_verified,
      is_premium,
      account_status,
      approval_status,
      ai_approved,
      ai_disapproval_reason,
      performance_score,
      avg_response_time_seconds,
      total_chats_count,
      last_active_at,
      profile_completeness,
      created_at,
      updated_at
    ) VALUES (
      NEW.user_id,
      NEW.full_name,
      NEW.age,
      NEW.date_of_birth,
      NEW.phone,
      NEW.photo_url,
      NEW.bio,
      NEW.country,
      NEW.state,
      NEW.primary_language,
      NEW.preferred_language,
      NEW.interests,
      NEW.life_goals,
      NEW.occupation,
      NEW.education_level,
      NEW.height_cm,
      NEW.body_type,
      NEW.marital_status,
      NEW.religion,
      NEW.is_verified,
      NEW.is_premium,
      NEW.account_status,
      NEW.approval_status,
      NEW.ai_approved,
      NEW.ai_disapproval_reason,
      NEW.performance_score,
      NEW.avg_response_time_seconds,
      NEW.total_chats_count,
      NEW.last_active_at,
      NEW.profile_completeness,
      COALESCE(NEW.created_at, now()),
      now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
      full_name = EXCLUDED.full_name,
      age = EXCLUDED.age,
      date_of_birth = EXCLUDED.date_of_birth,
      phone = EXCLUDED.phone,
      photo_url = EXCLUDED.photo_url,
      bio = EXCLUDED.bio,
      country = EXCLUDED.country,
      state = EXCLUDED.state,
      primary_language = EXCLUDED.primary_language,
      preferred_language = EXCLUDED.preferred_language,
      interests = EXCLUDED.interests,
      life_goals = EXCLUDED.life_goals,
      occupation = EXCLUDED.occupation,
      education_level = EXCLUDED.education_level,
      height_cm = EXCLUDED.height_cm,
      body_type = EXCLUDED.body_type,
      marital_status = EXCLUDED.marital_status,
      religion = EXCLUDED.religion,
      is_verified = EXCLUDED.is_verified,
      is_premium = EXCLUDED.is_premium,
      account_status = EXCLUDED.account_status,
      approval_status = EXCLUDED.approval_status,
      ai_approved = EXCLUDED.ai_approved,
      ai_disapproval_reason = EXCLUDED.ai_disapproval_reason,
      performance_score = EXCLUDED.performance_score,
      avg_response_time_seconds = EXCLUDED.avg_response_time_seconds,
      total_chats_count = EXCLUDED.total_chats_count,
      last_active_at = EXCLUDED.last_active_at,
      profile_completeness = EXCLUDED.profile_completeness,
      updated_at = now();

    -- Clean up from male_profiles if exists
    DELETE FROM public.male_profiles WHERE user_id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS sync_profile_to_gender_tables_trigger ON public.profiles;

-- Create trigger to sync on INSERT or UPDATE
CREATE TRIGGER sync_profile_to_gender_tables_trigger
  AFTER INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_profile_to_gender_tables();

-- Sync existing profiles to gender-specific tables
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT * FROM public.profiles WHERE gender IS NOT NULL LOOP
    -- Trigger the sync manually for existing records
    IF r.gender = 'male' OR r.gender = 'Male' THEN
      INSERT INTO public.male_profiles (
        user_id, full_name, age, date_of_birth, phone, photo_url, bio, country, state,
        primary_language, preferred_language, interests, life_goals, occupation,
        education_level, height_cm, body_type, marital_status, religion,
        is_verified, is_premium, account_status, last_active_at, profile_completeness,
        created_at, updated_at
      ) VALUES (
        r.user_id, r.full_name, r.age, r.date_of_birth, r.phone, r.photo_url, r.bio,
        r.country, r.state, r.primary_language, r.preferred_language, r.interests,
        r.life_goals, r.occupation, r.education_level, r.height_cm, r.body_type,
        r.marital_status, r.religion, r.is_verified, r.is_premium, r.account_status,
        r.last_active_at, r.profile_completeness, r.created_at, now()
      )
      ON CONFLICT (user_id) DO UPDATE SET
        full_name = EXCLUDED.full_name, primary_language = EXCLUDED.primary_language,
        preferred_language = EXCLUDED.preferred_language, updated_at = now();
    END IF;

    IF r.gender = 'female' OR r.gender = 'Female' THEN
      INSERT INTO public.female_profiles (
        user_id, full_name, age, date_of_birth, phone, photo_url, bio, country, state,
        primary_language, preferred_language, interests, life_goals, occupation,
        education_level, height_cm, body_type, marital_status, religion,
        is_verified, is_premium, account_status, approval_status, ai_approved,
        ai_disapproval_reason, performance_score, avg_response_time_seconds,
        total_chats_count, last_active_at, profile_completeness, created_at, updated_at
      ) VALUES (
        r.user_id, r.full_name, r.age, r.date_of_birth, r.phone, r.photo_url, r.bio,
        r.country, r.state, r.primary_language, r.preferred_language, r.interests,
        r.life_goals, r.occupation, r.education_level, r.height_cm, r.body_type,
        r.marital_status, r.religion, r.is_verified, r.is_premium, r.account_status,
        r.approval_status, r.ai_approved, r.ai_disapproval_reason, r.performance_score,
        r.avg_response_time_seconds, r.total_chats_count, r.last_active_at,
        r.profile_completeness, r.created_at, now()
      )
      ON CONFLICT (user_id) DO UPDATE SET
        full_name = EXCLUDED.full_name, primary_language = EXCLUDED.primary_language,
        preferred_language = EXCLUDED.preferred_language, approval_status = EXCLUDED.approval_status,
        updated_at = now();
    END IF;
  END LOOP;
END $$;