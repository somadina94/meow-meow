-- Extend assign_user_code to also fire on UPDATE when gender is finally set.
-- The existing immutability trigger already permits NULL -> value transitions.

CREATE OR REPLACE FUNCTION public.assign_user_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Only assign if not already set
  IF NEW.user_code IS NOT NULL AND NEW.user_code <> '' THEN
    RETURN NEW;
  END IF;

  IF NEW.gender = 'male' THEN
    NEW.user_code := 'GESS_M_' || LPAD(nextval('public.gess_male_seq')::text, 3, '0');
  ELSIF NEW.gender = 'female' THEN
    NEW.user_code := 'GESS_F_' || LPAD(nextval('public.gess_female_seq')::text, 3, '0');
  END IF;

  RETURN NEW;
END;
$$;

-- Add a BEFORE UPDATE trigger that fires when gender changes from NULL/other
-- to male/female, so users who set gender after signup also get a code.
DROP TRIGGER IF EXISTS trg_assign_user_code_on_update ON public.profiles;
CREATE TRIGGER trg_assign_user_code_on_update
BEFORE UPDATE OF gender ON public.profiles
FOR EACH ROW
WHEN (NEW.user_code IS NULL AND NEW.gender IN ('male','female'))
EXECUTE FUNCTION public.assign_user_code();

-- Backfill any existing rows that already have gender but no user_code
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