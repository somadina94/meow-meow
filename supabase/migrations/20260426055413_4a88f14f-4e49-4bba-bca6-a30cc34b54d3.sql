CREATE OR REPLACE FUNCTION public.ist_now()
RETURNS timestamptz
LANGUAGE sql STABLE
SET search_path = public
AS $$ SELECT (NOW() AT TIME ZONE 'Asia/Kolkata')::timestamptz $$;