-- 1. Add app_id to profiles (GESS-M-<n> / GESS-F-<n>) and app_sno (the integer)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS app_sno integer,
  ADD COLUMN IF NOT EXISTS app_id text;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_app_id_unique ON public.profiles(app_id) WHERE app_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_gender_app_sno_unique ON public.profiles(gender, app_sno) WHERE app_sno IS NOT NULL;

-- 2. Add new bank-KYC fields (keep all existing fields untouched)
ALTER TABLE public.women_kyc
  ADD COLUMN IF NOT EXISTS app_sno integer,
  ADD COLUMN IF NOT EXISTS beneficiary_purpose text NOT NULL DEFAULT 'others',
  ADD COLUMN IF NOT EXISTS upi_vpa text;

-- SNO in KYC must be unique per row (one SNO per woman, no duplicates)
CREATE UNIQUE INDEX IF NOT EXISTS women_kyc_app_sno_unique ON public.women_kyc(app_sno) WHERE app_sno IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS women_kyc_user_id_unique ON public.women_kyc(user_id);

-- 3. Sequences for per-gender SNO assignment
CREATE SEQUENCE IF NOT EXISTS public.app_sno_male_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.app_sno_female_seq START 1;

-- 4. Function: assign app_id + app_sno on profile insert based on gender
CREATE OR REPLACE FUNCTION public.assign_app_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.app_id IS NOT NULL AND NEW.app_sno IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.gender = 'male' THEN
    NEW.app_sno := nextval('public.app_sno_male_seq');
    NEW.app_id  := 'GESS-M-' || NEW.app_sno::text;
  ELSIF NEW.gender = 'female' THEN
    NEW.app_sno := nextval('public.app_sno_female_seq');
    NEW.app_id  := 'GESS-F-' || NEW.app_sno::text;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_app_id ON public.profiles;
CREATE TRIGGER trg_assign_app_id
BEFORE INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.assign_app_id();

-- 5. Function: when a woman's KYC row is inserted/updated, mirror her profile.app_sno into women_kyc.app_sno
CREATE OR REPLACE FUNCTION public.sync_kyc_app_sno()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sno integer;
BEGIN
  IF NEW.app_sno IS NULL THEN
    SELECT app_sno INTO v_sno FROM public.profiles WHERE user_id = NEW.user_id AND gender = 'female';
    NEW.app_sno := v_sno;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_kyc_app_sno ON public.women_kyc;
CREATE TRIGGER trg_sync_kyc_app_sno
BEFORE INSERT OR UPDATE ON public.women_kyc
FOR EACH ROW EXECUTE FUNCTION public.sync_kyc_app_sno();

-- 6. Backfill existing profiles (deterministic order: created_at, then id)
DO $$
DECLARE
  r RECORD;
  m_counter integer := 0;
  f_counter integer := 0;
BEGIN
  FOR r IN
    SELECT id, gender FROM public.profiles
    WHERE gender IN ('male','female') AND (app_sno IS NULL OR app_id IS NULL)
    ORDER BY created_at ASC, id ASC
  LOOP
    IF r.gender = 'male' THEN
      m_counter := m_counter + 1;
      UPDATE public.profiles
        SET app_sno = m_counter, app_id = 'GESS-M-' || m_counter::text
        WHERE id = r.id;
    ELSE
      f_counter := f_counter + 1;
      UPDATE public.profiles
        SET app_sno = f_counter, app_id = 'GESS-F-' || f_counter::text
        WHERE id = r.id;
    END IF;
  END LOOP;

  -- Advance sequences past the highest assigned values so new inserts don't collide
  PERFORM setval('public.app_sno_male_seq',  GREATEST(COALESCE((SELECT MAX(app_sno) FROM public.profiles WHERE gender='male'),0), 1), true);
  PERFORM setval('public.app_sno_female_seq',GREATEST(COALESCE((SELECT MAX(app_sno) FROM public.profiles WHERE gender='female'),0), 1), true);
END $$;

-- 7. Backfill women_kyc.app_sno from profiles for existing rows
UPDATE public.women_kyc k
SET app_sno = p.app_sno
FROM public.profiles p
WHERE k.user_id = p.user_id
  AND p.gender = 'female'
  AND k.app_sno IS NULL;