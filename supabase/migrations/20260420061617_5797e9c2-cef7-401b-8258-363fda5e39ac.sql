
-- Backfill: give every existing woman all_role
INSERT INTO public.user_service_roles (user_id, role)
SELECT user_id, 'all_role'::public.service_role
FROM public.female_profiles
ON CONFLICT (user_id, role) DO NOTHING;

-- Update auto-assign trigger function for new female profiles
CREATE OR REPLACE FUNCTION public.assign_default_female_service_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_service_roles (user_id, role)
  VALUES (NEW.user_id, 'all_role'::public.service_role)
  ON CONFLICT (user_id, role) DO NOTHING;
  RETURN NEW;
END;
$$;
