-- Add language leader badge for women
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_language_leader boolean NOT NULL DEFAULT false;

-- One leader per language (case-insensitive on primary_language) for women only
CREATE UNIQUE INDEX IF NOT EXISTS profiles_one_leader_per_language_idx
  ON public.profiles (lower(primary_language))
  WHERE is_language_leader = true AND gender = 'female';

CREATE INDEX IF NOT EXISTS profiles_language_leader_idx
  ON public.profiles (primary_language)
  WHERE is_language_leader = true;

-- Admin RPC to toggle the leader badge
CREATE OR REPLACE FUNCTION public.admin_toggle_language_leader(
  p_user_id uuid,
  p_make_leader boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_profile RECORD;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
  END IF;

  IF NOT public.has_role(v_caller, 'admin'::app_role) THEN
    RAISE EXCEPTION 'Admin role required' USING ERRCODE = '42501';
  END IF;

  SELECT user_id, gender, primary_language, approval_status, is_indian
    INTO v_profile
  FROM public.profiles
  WHERE user_id = p_user_id
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;

  IF p_make_leader THEN
    IF lower(coalesce(v_profile.gender,'')) <> 'female' THEN
      RAISE EXCEPTION 'Leader badge can only be assigned to women';
    END IF;
    IF coalesce(v_profile.approval_status,'') <> 'approved' THEN
      RAISE EXCEPTION 'User must be an approved woman';
    END IF;
    IF v_profile.primary_language IS NULL OR v_profile.primary_language = '' THEN
      RAISE EXCEPTION 'User has no primary language set';
    END IF;

    -- Demote any existing leader of the same language
    UPDATE public.profiles
    SET is_language_leader = false, updated_at = now()
    WHERE gender = 'female'
      AND is_language_leader = true
      AND lower(primary_language) = lower(v_profile.primary_language)
      AND user_id <> p_user_id;

    UPDATE public.profiles
    SET is_language_leader = true, updated_at = now()
    WHERE user_id = p_user_id;
  ELSE
    UPDATE public.profiles
    SET is_language_leader = false, updated_at = now()
    WHERE user_id = p_user_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id, 'is_leader', p_make_leader);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_toggle_language_leader(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_toggle_language_leader(uuid, boolean) TO authenticated;