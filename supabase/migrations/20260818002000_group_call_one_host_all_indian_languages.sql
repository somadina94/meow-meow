-- Group calls: all scheduled Indian languages, one live host per language.
-- 1:1 audio/video stays limited to Hindi/Bengali/Marathi/Telugu/Tamil with a 15-person cap.

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
    WHEN lower(trim(p_lang)) IN ('ur', 'urdu', 'اردو') THEN 'urdu'
    WHEN lower(trim(p_lang)) IN ('gu', 'gujarati', 'ગુજરાતી') THEN 'gujarati'
    WHEN lower(trim(p_lang)) IN ('kn', 'kannada', 'ಕನ್ನಡ') THEN 'kannada'
    WHEN lower(trim(p_lang)) IN ('ml', 'malayalam', 'മലയാളം') THEN 'malayalam'
    WHEN lower(trim(p_lang)) IN ('or', 'odia', 'oriya', 'ଓଡ଼ିଆ') THEN 'odia'
    WHEN lower(trim(p_lang)) IN ('pa', 'punjabi', 'panjabi', 'ਪੰਜਾਬੀ') THEN 'punjabi'
    WHEN lower(trim(p_lang)) IN ('as', 'assamese', 'অসমীয়া') THEN 'assamese'
    WHEN lower(trim(p_lang)) IN ('mai', 'maithili', 'मैथिली') THEN 'maithili'
    WHEN lower(trim(p_lang)) IN ('sat', 'santali', 'ᱥᱟᱱᱛᱟᱲᱤ') THEN 'santali'
    WHEN lower(trim(p_lang)) IN ('ks', 'kashmiri', 'कॉशुर') THEN 'kashmiri'
    WHEN lower(trim(p_lang)) IN ('kok', 'konkani', 'कोंकणी') THEN 'konkani'
    WHEN lower(trim(p_lang)) IN ('doi', 'dogri', 'डोगरी') THEN 'dogri'
    WHEN lower(trim(p_lang)) IN ('mni', 'manipuri', 'meitei', 'meetei', 'মৈতৈলোন্') THEN 'manipuri'
    WHEN lower(trim(p_lang)) IN ('brx', 'bodo', 'बड़ो') THEN 'bodo'
    WHEN lower(trim(p_lang)) IN ('sa', 'sanskrit', 'संस्कृतम्') THEN 'sanskrit'
    WHEN lower(trim(p_lang)) IN ('ne', 'nepali', 'नेपाली') THEN 'nepali'
    WHEN lower(trim(p_lang)) IN ('sd', 'sindhi', 'سنڌي') THEN 'sindhi'
    ELSE lower(trim(p_lang))
  END;
$$;

CREATE OR REPLACE FUNCTION public.is_indian_call_language(p_lang text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT public.normalize_call_language(p_lang) IN ('hindi', 'bengali', 'marathi', 'telugu', 'tamil');
$$;

CREATE OR REPLACE FUNCTION public.is_indian_group_call_language(p_lang text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT public.normalize_call_language(p_lang) IN (
    'hindi', 'bengali', 'telugu', 'marathi', 'tamil', 'urdu', 'gujarati',
    'kannada', 'malayalam', 'odia', 'punjabi', 'assamese', 'maithili',
    'santali', 'kashmiri', 'konkani', 'dogri', 'manipuri', 'bodo',
    'sanskrit', 'nepali', 'sindhi'
  );
$$;

-- 15-person cap is 1:1 only. Group calls use one-host-per-language instead.
CREATE OR REPLACE FUNCTION public.count_active_call_users_for_language(p_language text)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_lang text := public.normalize_call_language(p_language);
  v_count integer := 0;
BEGIN
  IF v_lang = '' THEN
    RETURN 0;
  END IF;

  SELECT COUNT(*)::integer INTO v_count
  FROM (
    SELECT v.man_user_id AS uid
    FROM public.video_call_sessions v
    WHERE v.status IN ('pending', 'ringing', 'connecting', 'active')
      AND public.normalize_call_language(public.profile_call_language(v.man_user_id)) = v_lang
    UNION
    SELECT v.woman_user_id
    FROM public.video_call_sessions v
    WHERE v.status IN ('pending', 'ringing', 'connecting', 'active')
      AND public.normalize_call_language(public.profile_call_language(v.woman_user_id)) = v_lang
  ) t;

  RETURN COALESCE(v_count, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_group_host_language_slot(p_language text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_lang text := public.normalize_call_language(p_language);
  v_other uuid;
BEGIN
  IF NOT public.is_indian_group_call_language(v_lang) THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'Group calls are available when your profile language is an Indian language.'
    );
  END IF;

  SELECT h.host_id INTO v_other
  FROM public.group_active_hosts h
  WHERE h.is_active = true
    AND h.last_heartbeat_at > now() - interval '90 seconds'
    AND public.normalize_call_language(COALESCE(h.host_language, '')) = v_lang
    AND h.host_id IS DISTINCT FROM auth.uid()
  LIMIT 1;

  IF v_other IS NOT NULL THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'error', 'This language already has a live group-call host. Try again when they stop.'
    );
  END IF;

  RETURN jsonb_build_object('allowed', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.start_host_session(
  p_group_id uuid,
  p_host_name text,
  p_host_photo text DEFAULT NULL::text,
  p_host_language text DEFAULT NULL::text,
  p_stream_id text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_other_active_group uuid;
  v_same_group_active boolean;
  v_host_lang text;
  v_slot jsonb;
  v_lang_host uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_host_lang := COALESCE(NULLIF(trim(p_host_language), ''), public.profile_call_language(v_user_id));

  IF NOT public.is_indian_group_call_language(v_host_lang) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Group calls are available when your profile language is an Indian language.'
    );
  END IF;

  UPDATE public.group_active_hosts
  SET is_active = false
  WHERE is_active = true
    AND last_heartbeat_at < now() - interval '90 seconds';

  v_slot := public.assert_group_host_language_slot(v_host_lang);
  IF COALESCE((v_slot->>'allowed')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', COALESCE(v_slot->>'error', 'This language already has a live host'));
  END IF;

  PERFORM 1 FROM public.private_groups WHERE id = p_group_id FOR UPDATE;

  SELECT EXISTS (
    SELECT 1
    FROM public.group_active_hosts
    WHERE host_id = v_user_id
      AND group_id = p_group_id
      AND is_active = true
  ) INTO v_same_group_active;

  SELECT group_id INTO v_other_active_group
  FROM public.group_active_hosts
  WHERE host_id = v_user_id
    AND group_id <> p_group_id
    AND is_active = true
  ORDER BY started_at DESC
  LIMIT 1;

  IF v_other_active_group IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'You are already hosting another group. Stop that first.', 'group_id', v_other_active_group);
  END IF;

  SELECT host_id INTO v_lang_host
  FROM public.group_active_hosts
  WHERE is_active = true
    AND host_id <> v_user_id
    AND public.normalize_call_language(COALESCE(host_language, '')) = public.normalize_call_language(v_host_lang)
  LIMIT 1;

  IF v_lang_host IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'This language already has a live group-call host. Try again when they stop.');
  END IF;

  BEGIN
    INSERT INTO public.group_active_hosts (
      group_id, host_id, host_name, host_photo, host_language, stream_id, is_active, started_at, last_heartbeat_at
    ) VALUES (
      p_group_id, v_user_id, p_host_name, p_host_photo, v_host_lang, p_stream_id, true, now(), now()
    )
    ON CONFLICT (group_id, host_id) DO UPDATE SET
      host_name = EXCLUDED.host_name,
      host_photo = COALESCE(EXCLUDED.host_photo, public.group_active_hosts.host_photo),
      host_language = COALESCE(EXCLUDED.host_language, public.group_active_hosts.host_language),
      stream_id = COALESCE(EXCLUDED.stream_id, public.group_active_hosts.stream_id),
      is_active = true,
      started_at = CASE WHEN public.group_active_hosts.is_active THEN public.group_active_hosts.started_at ELSE now() END,
      last_heartbeat_at = now();
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'This language already has a live group-call host. Try again when they stop.');
  END;

  UPDATE public.private_groups
  SET is_live = true,
      updated_at = now(),
      current_host_id = COALESCE(current_host_id, v_user_id),
      current_host_name = COALESCE(current_host_name, p_host_name)
  WHERE id = p_group_id;

  RETURN jsonb_build_object(
    'success', true,
    'reused', v_same_group_active
  );
END;
$function$;

DROP FUNCTION IF EXISTS public.join_group_atomic(uuid, uuid, integer);

CREATE OR REPLACE FUNCTION public.join_group_atomic(
  p_group_id uuid,
  p_user_id uuid,
  p_max_participants integer DEFAULT 15,
  p_host_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_new_count INT;
  v_host_id UUID;
  v_stream_id TEXT;
  v_host_language TEXT;
  v_joiner_lang TEXT;
  v_joiner_gender TEXT;
  v_host_gender TEXT;
  v_bill_result JSONB;
  v_max INT := LEAST(COALESCE(p_max_participants, 15), 15);
BEGIN
  IF p_host_id IS NOT NULL THEN
    SELECT host_id, stream_id, host_language INTO v_host_id, v_stream_id, v_host_language
    FROM public.group_active_hosts
    WHERE group_id = p_group_id
      AND host_id = p_host_id
      AND is_active = true
      AND last_heartbeat_at > now() - interval '2 minutes';
  ELSE
    SELECT host_id, stream_id, host_language INTO v_host_id, v_stream_id, v_host_language
    FROM public.group_active_hosts
    WHERE group_id = p_group_id
      AND is_active = true
      AND last_heartbeat_at > now() - interval '2 minutes'
      AND public.normalize_call_language(COALESCE(host_language, '')) = public.normalize_call_language(public.profile_call_language(p_user_id))
    ORDER BY started_at ASC
    LIMIT 1;
  END IF;

  IF v_host_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No live host in this group right now');
  END IF;

  v_joiner_lang := public.profile_call_language(p_user_id);

  IF NOT public.is_indian_group_call_language(v_host_language)
     OR NOT public.is_indian_group_call_language(v_joiner_lang)
     OR public.normalize_call_language(v_host_language) <> public.normalize_call_language(v_joiner_lang) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Join the host that matches your Indian profile language.'
    );
  END IF;

  SELECT gender INTO v_joiner_gender FROM public.profiles WHERE user_id = p_user_id;
  SELECT gender INTO v_host_gender   FROM public.profiles WHERE user_id = v_host_id;

  IF v_joiner_gender = 'male' AND v_host_gender = 'female' AND v_stream_id IS NOT NULL THEN
    IF NOT public.has_role(p_user_id, 'admin') THEN
      DECLARE
        v_required numeric;
        v_balance  numeric;
        v_resolved uuid := public.resolve_wallet_user_id(p_user_id);
      BEGIN
        v_required := (public.get_unified_pricing()->>'group_man_rate')::numeric;
        SELECT GREATEST(COALESCE(SUM(CASE
                 WHEN u.type='credit' THEN u.amount
                 WHEN u.type='debit'  THEN -u.amount
                 ELSE 0 END), 0), 0)
          INTO v_balance
        FROM (
          SELECT type, amount, status FROM public.wallet_transactions WHERE user_id = v_resolved
          UNION ALL
          SELECT type, amount, status FROM public.wallet_transactions_archive WHERE user_id = v_resolved
        ) u
        WHERE u.status='completed';

        IF COALESCE(v_balance, 0) < v_required THEN
          RETURN jsonb_build_object(
            'success', false, 'error', 'Insufficient balance',
            'balance', COALESCE(v_balance, 0), 'required', v_required
          );
        END IF;
      END;
    END IF;
  END IF;

  UPDATE public.private_groups
  SET participant_count = participant_count + 1,
      is_live = true,
      current_host_id = COALESCE(current_host_id, v_host_id),
      updated_at = now()
  WHERE id = p_group_id AND is_active = true AND participant_count < v_max
  RETURNING participant_count INTO v_new_count;

  IF v_new_count IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group is full or inactive');
  END IF;

  UPDATE public.group_active_hosts
  SET participant_count = participant_count + 1
  WHERE group_id = p_group_id AND host_id = v_host_id AND is_active = true;

  INSERT INTO public.group_memberships (group_id, user_id, has_access, gift_amount_paid, joined_host_id, joined_at)
  VALUES (p_group_id, p_user_id, true, 0, v_host_id, now())
  ON CONFLICT (group_id, user_id) DO UPDATE SET
    has_access = true, joined_at = now(), joined_host_id = EXCLUDED.joined_host_id;

  IF v_joiner_gender = 'male' AND v_host_gender = 'female' AND v_stream_id IS NOT NULL THEN
    BEGIN
      v_bill_result := public.bill_session_minute(
        p_session_id   => v_stream_id::uuid,
        p_session_type => 'private_group_call',
        p_minutes      => 1.0,
        p_man_id       => p_user_id,
        p_woman_id     => v_host_id,
        p_man_count    => 1,
        p_minute_index => 0
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'join_group_atomic billing failed: %', SQLERRM;
      v_bill_result := jsonb_build_object('success', false, 'error', SQLERRM);
    END;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'participant_count', v_new_count,
    'host_id', v_host_id,
    'billing', v_bill_result
  );
END;
$$;

-- Keep one live host per language; deactivate extras before the unique index.
WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY public.normalize_call_language(COALESCE(host_language, ''))
           ORDER BY started_at ASC
         ) AS rn
  FROM public.group_active_hosts
  WHERE is_active = true
    AND COALESCE(trim(host_language), '') <> ''
)
UPDATE public.group_active_hosts h
SET is_active = false
FROM ranked r
WHERE h.id = r.id AND r.rn > 1;

DROP INDEX IF EXISTS public.uniq_one_active_host_per_language;
CREATE UNIQUE INDEX uniq_one_active_host_per_language
  ON public.group_active_hosts (public.normalize_call_language(host_language))
  WHERE is_active = true AND COALESCE(trim(host_language), '') <> '';

GRANT EXECUTE ON FUNCTION public.normalize_call_language(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_indian_call_language(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_indian_group_call_language(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assert_group_host_language_slot(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.count_active_call_users_for_language(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.start_host_session(uuid, text, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_group_atomic(uuid, uuid, integer, uuid) TO authenticated, service_role;
