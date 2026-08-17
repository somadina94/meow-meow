
CREATE OR REPLACE FUNCTION public.now_ist()
RETURNS timestamptz LANGUAGE sql STABLE
SET search_path = public
AS $$ SELECT NOW() AT TIME ZONE 'Asia/Kolkata'; $$;

CREATE OR REPLACE FUNCTION public.today_ist()
RETURNS date LANGUAGE sql STABLE
SET search_path = public
AS $$ SELECT (NOW() AT TIME ZONE 'Asia/Kolkata')::date; $$;

CREATE OR REPLACE FUNCTION public.set_ledger_ist_fields()
RETURNS trigger LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.ist_date  := (NEW.created_at_ist AT TIME ZONE 'Asia/Kolkata')::date;
  NEW.ist_month := TO_CHAR(NEW.created_at_ist AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM');
  NEW.ist_year  := EXTRACT(YEAR FROM NEW.created_at_ist AT TIME ZONE 'Asia/Kolkata')::int;
  RETURN NEW;
END;
$$;
