CREATE SEQUENCE IF NOT EXISTS public.user_global_app_id_seq START WITH 1 INCREMENT BY 1 MINVALUE 1 NO MAXVALUE CACHE 1;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS global_app_id BIGINT;

WITH ordered AS (
  SELECT user_id,
         ROW_NUMBER() OVER (ORDER BY created_at ASC, user_id ASC) AS rn
  FROM public.profiles
  WHERE global_app_id IS NULL
)
UPDATE public.profiles p
   SET global_app_id = o.rn
  FROM ordered o
 WHERE p.user_id = o.user_id;

SELECT setval(
  'public.user_global_app_id_seq',
  GREATEST((SELECT COALESCE(MAX(global_app_id), 0)::bigint FROM public.profiles), 1::bigint),
  true
);

ALTER TABLE public.profiles
  ALTER COLUMN global_app_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_global_app_id_unique
  ON public.profiles(global_app_id);

ALTER TABLE public.profiles
  ALTER COLUMN global_app_id SET DEFAULT nextval('public.user_global_app_id_seq');

CREATE OR REPLACE FUNCTION public.assign_global_app_id()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NEW.global_app_id IS NULL THEN
    NEW.global_app_id := nextval('public.user_global_app_id_seq');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_global_app_id ON public.profiles;
CREATE TRIGGER trg_assign_global_app_id
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.assign_global_app_id();

CREATE OR REPLACE FUNCTION public.get_global_app_id(p_user_id uuid DEFAULT auth.uid())
RETURNS BIGINT LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT global_app_id FROM public.profiles WHERE user_id = p_user_id LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_global_app_id(uuid) TO authenticated, anon;