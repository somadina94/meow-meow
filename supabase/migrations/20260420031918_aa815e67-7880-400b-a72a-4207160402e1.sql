
-- 1. Sequence for employee IDs
CREATE SEQUENCE IF NOT EXISTS public.female_employee_id_seq START 1 INCREMENT 1 MINVALUE 1 NO MAXVALUE;

-- 2. Add column
ALTER TABLE public.female_profiles
  ADD COLUMN IF NOT EXISTS employee_id text UNIQUE;

-- 3. Generator function
CREATE OR REPLACE FUNCTION public.generate_female_employee_id()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  next_num bigint;
BEGIN
  next_num := nextval('public.female_employee_id_seq');
  RETURN 'GESS' || next_num::text;
END;
$$;

-- 4. Backfill existing rows (ordered by created_at so earliest gets GESS1)
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT id FROM public.female_profiles
    WHERE employee_id IS NULL
    ORDER BY created_at ASC NULLS LAST, id ASC
  LOOP
    UPDATE public.female_profiles
      SET employee_id = public.generate_female_employee_id()
      WHERE id = r.id;
  END LOOP;
END $$;

-- 5. Make NOT NULL after backfill
ALTER TABLE public.female_profiles
  ALTER COLUMN employee_id SET NOT NULL;

-- 6. Set default for new rows
ALTER TABLE public.female_profiles
  ALTER COLUMN employee_id SET DEFAULT public.generate_female_employee_id();

-- 7. Trigger to enforce assignment on insert (in case insert provides NULL explicitly)
CREATE OR REPLACE FUNCTION public.assign_female_employee_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.employee_id IS NULL OR NEW.employee_id = '' THEN
    NEW.employee_id := public.generate_female_employee_id();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_female_employee_id ON public.female_profiles;
CREATE TRIGGER trg_assign_female_employee_id
  BEFORE INSERT ON public.female_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_female_employee_id();

-- 8. Reset sequence to max(existing numeric part) so next insert continues correctly
SELECT setval(
  'public.female_employee_id_seq',
  COALESCE((
    SELECT MAX(SUBSTRING(employee_id FROM 5)::bigint)
    FROM public.female_profiles
    WHERE employee_id ~ '^GESS[0-9]+$'
  ), 0) + 0,
  true
);

-- 9. Index for lookups
CREATE INDEX IF NOT EXISTS idx_female_profiles_employee_id ON public.female_profiles(employee_id);
