ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS host_number BIGINT UNIQUE;

CREATE SEQUENCE IF NOT EXISTS public.host_number_seq START WITH 1 INCREMENT BY 1;

WITH ordered AS (
  SELECT id FROM public.profiles
  WHERE gender = 'female' AND host_number IS NULL
  ORDER BY created_at ASC, id ASC
)
UPDATE public.profiles p
SET host_number = nextval('public.host_number_seq')
FROM ordered o
WHERE p.id = o.id;

CREATE OR REPLACE FUNCTION public.assign_host_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.gender = 'female' AND NEW.host_number IS NULL THEN
    NEW.host_number := nextval('public.host_number_seq');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_host_number ON public.profiles;
CREATE TRIGGER trg_assign_host_number
  BEFORE INSERT OR UPDATE OF gender ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_host_number();

ALTER TABLE public.private_groups
  ADD COLUMN IF NOT EXISTS current_host_number BIGINT;

CREATE OR REPLACE FUNCTION public.sync_group_host_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.current_host_id IS DISTINCT FROM OLD.current_host_id THEN
    IF NEW.current_host_id IS NULL THEN
      NEW.current_host_number := NULL;
    ELSE
      SELECT host_number INTO NEW.current_host_number
      FROM profiles WHERE id = NEW.current_host_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_group_host_number ON public.private_groups;
CREATE TRIGGER trg_sync_group_host_number
  BEFORE UPDATE OF current_host_id ON public.private_groups
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_group_host_number();

UPDATE public.private_groups pg
SET current_host_number = p.host_number
FROM public.profiles p
WHERE pg.current_host_id = p.id
  AND pg.current_host_number IS DISTINCT FROM p.host_number;