-- 1) Update the assignment function to use new male format
CREATE OR REPLACE FUNCTION public.assign_app_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.app_id IS NOT NULL AND NEW.app_sno IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.gender = 'male' THEN
    IF NEW.app_sno IS NULL THEN
      NEW.app_sno := nextval('public.app_sno_male_seq');
    END IF;
    NEW.app_id  := 'GESS_M_' || NEW.app_sno::text;
  ELSIF NEW.gender = 'female' THEN
    IF NEW.app_sno IS NULL THEN
      NEW.app_sno := nextval('public.app_sno_female_seq');
    END IF;
    NEW.app_id  := 'GESS-F-' || NEW.app_sno::text;
  END IF;

  RETURN NEW;
END;
$function$;

-- 2) Ensure unique constraint on app_id (skip if already present)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_app_id_unique'
  ) THEN
    BEGIN
      ALTER TABLE public.profiles ADD CONSTRAINT profiles_app_id_unique UNIQUE (app_id);
    EXCEPTION WHEN duplicate_table THEN NULL;
    END;
  END IF;
END $$;

-- 3) Backfill: migrate existing male IDs from hyphen to underscore format
UPDATE public.profiles
SET app_id = 'GESS_M_' || app_sno::text
WHERE gender = 'male'
  AND app_sno IS NOT NULL
  AND (app_id IS NULL OR app_id LIKE 'GESS-M-%');

-- 4) Backfill: assign app_sno + app_id to any male profile missing them
UPDATE public.profiles p
SET app_sno = nextval('public.app_sno_male_seq'),
    app_id  = 'GESS_M_' || currval('public.app_sno_male_seq')::text
WHERE gender = 'male' AND app_sno IS NULL;

-- 5) Backfill: assign app_sno + app_id to any female profile missing them
UPDATE public.profiles p
SET app_sno = nextval('public.app_sno_female_seq'),
    app_id  = 'GESS-F-' || currval('public.app_sno_female_seq')::text
WHERE gender = 'female' AND app_sno IS NULL;