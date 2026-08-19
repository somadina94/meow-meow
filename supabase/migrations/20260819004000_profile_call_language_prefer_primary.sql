-- 1:1 call language must match the saved profile language, not a leftover
-- user_languages row (e.g. old Telugu after switching to Hindi).

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
    CASE WHEN public.is_indian_call_language(fp.primary_language) THEN fp.primary_language END,
    CASE WHEN public.is_indian_call_language(mp.primary_language) THEN mp.primary_language END,
    (
      SELECT ul.language_name
      FROM public.user_languages ul
      WHERE (ul.user_id = p_user_id OR ul.user_id = p.user_id)
        AND public.is_indian_call_language(ul.language_name)
      ORDER BY ul.created_at DESC
      LIMIT 1
    ),
    CASE WHEN public.is_indian_call_language(p.preferred_language) THEN p.preferred_language END,
    CASE WHEN public.is_indian_call_language(fp.preferred_language) THEN fp.preferred_language END,
    CASE WHEN public.is_indian_call_language(mp.preferred_language) THEN mp.preferred_language END,
    COALESCE(
      NULLIF(trim(p.primary_language), ''),
      NULLIF(trim(p.language), ''),
      NULLIF(trim(p.preferred_language), '')
    )
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

GRANT EXECUTE ON FUNCTION public.profile_call_language(uuid) TO authenticated, service_role;
