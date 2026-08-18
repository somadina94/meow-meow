-- Prefer mother tongue / user_languages over English preferred_language.
-- Also treat native-script names (বাংলা, हिन्दी, …) as call languages.

CREATE OR REPLACE FUNCTION public.normalize_call_language(p_lang text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_lang IS NULL OR trim(p_lang) = '' THEN ''
    WHEN lower(trim(p_lang)) IN ('bangla', 'bn', 'bengali', 'বাংলা', 'bengali (india)') THEN 'bengali'
    WHEN lower(trim(p_lang)) IN ('hi', 'hindi', 'हिन्दी', 'हिंदी') THEN 'hindi'
    WHEN lower(trim(p_lang)) IN ('mr', 'marathi', 'मराठी') THEN 'marathi'
    WHEN lower(trim(p_lang)) IN ('te', 'telugu', 'తెలుగు') THEN 'telugu'
    WHEN lower(trim(p_lang)) IN ('ta', 'tamil', 'தமிழ்') THEN 'tamil'
    ELSE lower(trim(p_lang))
  END;
$$;

CREATE OR REPLACE FUNCTION public.profile_call_language(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_lang text;
BEGIN
  SELECT COALESCE(
    CASE WHEN public.is_indian_call_language(p.primary_language) THEN p.primary_language END,
    CASE WHEN public.is_indian_call_language(p.language) THEN p.language END,
    CASE WHEN public.is_indian_call_language(fp.primary_language) THEN fp.primary_language END,
    CASE WHEN public.is_indian_call_language(mp.primary_language) THEN mp.primary_language END,
    (
      SELECT ul.language_name
      FROM public.user_languages ul
      WHERE ul.user_id = p_user_id
        AND public.is_indian_call_language(ul.language_name)
      LIMIT 1
    ),
    CASE WHEN public.is_indian_call_language(p.preferred_language) THEN p.preferred_language END,
    CASE WHEN public.is_indian_call_language(fp.preferred_language) THEN fp.preferred_language END,
    CASE WHEN public.is_indian_call_language(mp.preferred_language) THEN mp.preferred_language END,
    COALESCE(NULLIF(trim(p.primary_language), ''), NULLIF(trim(p.language), ''), NULLIF(trim(p.preferred_language), ''))
  )
  INTO v_lang
  FROM public.profiles p
  LEFT JOIN public.female_profiles fp ON fp.user_id = p.user_id
  LEFT JOIN public.male_profiles mp ON mp.user_id = p.user_id
  WHERE p.user_id = p_user_id OR p.id = p_user_id
  LIMIT 1;

  RETURN COALESCE(v_lang, '');
END;
$$;

GRANT EXECUTE ON FUNCTION public.normalize_call_language(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.profile_call_language(uuid) TO authenticated, service_role;
