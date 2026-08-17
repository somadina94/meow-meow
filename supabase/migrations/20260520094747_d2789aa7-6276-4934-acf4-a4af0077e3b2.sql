CREATE OR REPLACE FUNCTION public.check_signup_availability(
  p_email text DEFAULT NULL,
  p_phone text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email_exists boolean := false;
  v_phone_exists boolean := false;
  v_email_norm text := NULLIF(lower(btrim(p_email)), '');
  v_phone_norm text := NULLIF(btrim(p_phone), '');
BEGIN
  IF v_email_norm IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles WHERE lower(email) = v_email_norm
    ) INTO v_email_exists;
  END IF;

  IF v_phone_norm IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles WHERE phone = v_phone_norm
      UNION ALL
      SELECT 1 FROM public.male_profiles WHERE phone = v_phone_norm
      UNION ALL
      SELECT 1 FROM public.female_profiles WHERE phone = v_phone_norm
    ) INTO v_phone_exists;
  END IF;

  RETURN jsonb_build_object(
    'email_exists', v_email_exists,
    'phone_exists', v_phone_exists
  );
END;
$$;

REVOKE ALL ON FUNCTION public.check_signup_availability(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_signup_availability(text, text) TO anon, authenticated;