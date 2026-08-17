
-- 1) Sequences (per gender)
CREATE SEQUENCE IF NOT EXISTS public.gess_male_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.gess_female_seq START 1;

-- 2) Column
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS user_code text;

-- 3) Backfill existing rows in registration order (males then females, by created_at)
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT id FROM public.profiles
    WHERE user_code IS NULL AND gender = 'male'
    ORDER BY created_at ASC, id ASC
  LOOP
    UPDATE public.profiles
       SET user_code = 'GESS_M_' || LPAD(nextval('public.gess_male_seq')::text, 3, '0')
     WHERE id = r.id;
  END LOOP;

  FOR r IN
    SELECT id FROM public.profiles
    WHERE user_code IS NULL AND gender = 'female'
    ORDER BY created_at ASC, id ASC
  LOOP
    UPDATE public.profiles
       SET user_code = 'GESS_F_' || LPAD(nextval('public.gess_female_seq')::text, 3, '0')
     WHERE id = r.id;
  END LOOP;
END $$;

-- 4) Uniqueness
CREATE UNIQUE INDEX IF NOT EXISTS profiles_user_code_key ON public.profiles(user_code);

-- 5) Auto-assign trigger on INSERT
CREATE OR REPLACE FUNCTION public.assign_user_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.user_code IS NULL OR NEW.user_code = '' THEN
    IF NEW.gender = 'male' THEN
      NEW.user_code := 'GESS_M_' || LPAD(nextval('public.gess_male_seq')::text, 3, '0');
    ELSIF NEW.gender = 'female' THEN
      NEW.user_code := 'GESS_F_' || LPAD(nextval('public.gess_female_seq')::text, 3, '0');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_user_code ON public.profiles;
CREATE TRIGGER trg_assign_user_code
BEFORE INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.assign_user_code();

-- 6) Lock the code from being changed once set
CREATE OR REPLACE FUNCTION public.prevent_user_code_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  IF OLD.user_code IS NOT NULL AND NEW.user_code IS DISTINCT FROM OLD.user_code THEN
    RAISE EXCEPTION 'user_code is immutable';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_user_code_change ON public.profiles;
CREATE TRIGGER trg_prevent_user_code_change
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.prevent_user_code_change();
