-- Audio/video calls only for Hindi, Bengali, Marathi, Telugu, Tamil.
-- Max 15 concurrent call users (1:1 + group) per language.

CREATE OR REPLACE FUNCTION public.normalize_call_language(p_lang text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_lang IS NULL OR trim(p_lang) = '' THEN ''
    WHEN lower(trim(p_lang)) IN ('bangla', 'bn', 'bengali') THEN 'bengali'
    WHEN lower(trim(p_lang)) IN ('hi', 'hindi') THEN 'hindi'
    WHEN lower(trim(p_lang)) IN ('mr', 'marathi') THEN 'marathi'
    WHEN lower(trim(p_lang)) IN ('te', 'telugu') THEN 'telugu'
    WHEN lower(trim(p_lang)) IN ('ta', 'tamil') THEN 'tamil'
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

CREATE OR REPLACE FUNCTION public.profile_call_language(p_user_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT COALESCE(
    NULLIF(trim(preferred_language), ''),
    NULLIF(trim(primary_language), ''),
    NULLIF(trim(language), '')
  )
  FROM public.profiles
  WHERE user_id = p_user_id OR id = p_user_id
  LIMIT 1;
$$;

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

  WITH ones AS (
    SELECT v.man_user_id AS uid
    FROM public.video_call_sessions v
    WHERE v.status IN ('pending', 'ringing', 'connecting', 'active')
      AND public.normalize_call_language(public.profile_call_language(v.man_user_id)) = v_lang
    UNION
    SELECT v.woman_user_id
    FROM public.video_call_sessions v
    WHERE v.status IN ('pending', 'ringing', 'connecting', 'active')
      AND public.normalize_call_language(public.profile_call_language(v.woman_user_id)) = v_lang
  ),
  grp AS (
    SELECT gm.user_id AS uid
    FROM public.group_memberships gm
    JOIN public.group_active_hosts h
      ON h.group_id = gm.group_id
     AND h.is_active = true
     AND (gm.joined_host_id IS NOT DISTINCT FROM h.host_id OR gm.user_id = h.host_id)
    WHERE gm.has_access = true
      AND public.normalize_call_language(COALESCE(h.host_language, '')) = v_lang
    UNION
    SELECT h.host_id
    FROM public.group_active_hosts h
    WHERE h.is_active = true
      AND public.normalize_call_language(COALESCE(h.host_language, '')) = v_lang
  )
  SELECT COUNT(*)::integer INTO v_count
  FROM (
    SELECT uid FROM ones
    UNION
    SELECT uid FROM grp
  ) t;

  RETURN COALESCE(v_count, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_language_call_capacity(p_language text, p_slots integer DEFAULT 1)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_count integer;
  v_slots integer := GREATEST(COALESCE(p_slots, 1), 1);
BEGIN
  IF NOT public.is_indian_call_language(p_language) THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'count', 0,
      'max', 15,
      'error', 'Audio and video calls are only available if your profile language is Hindi, Bengali, Marathi, Telugu, or Tamil.'
    );
  END IF;

  v_count := public.count_active_call_users_for_language(p_language);
  IF v_count + v_slots > 15 THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'count', v_count,
      'max', 15,
      'error', 'This language already has 15 people on audio/video calls. Try again later.'
    );
  END IF;

  RETURN jsonb_build_object('allowed', true, 'count', v_count, 'max', 15);
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_indian_call_languages()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_man_lang text;
  v_woman_lang text;
  v_cap jsonb;
BEGIN
  IF NEW.status IS NULL OR NEW.status NOT IN ('pending', 'ringing', 'connecting', 'active') THEN
    RETURN NEW;
  END IF;

  v_man_lang := public.profile_call_language(NEW.man_user_id);
  v_woman_lang := public.profile_call_language(NEW.woman_user_id);

  IF NOT public.is_indian_call_language(v_man_lang)
     OR NOT public.is_indian_call_language(v_woman_lang)
     OR public.normalize_call_language(v_man_lang) <> public.normalize_call_language(v_woman_lang) THEN
    RAISE EXCEPTION 'Audio and video calls are only available for Hindi, Bengali, Marathi, Telugu, and Tamil, and both users must share that language';
  END IF;

  v_cap := public.assert_language_call_capacity(v_man_lang, 2);
  IF COALESCE((v_cap->>'allowed')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION '%', COALESCE(v_cap->>'error', 'Call language is at capacity');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_indian_call_languages ON public.video_call_sessions;
CREATE TRIGGER trg_enforce_indian_call_languages
BEFORE INSERT ON public.video_call_sessions
FOR EACH ROW
EXECUTE FUNCTION public.enforce_indian_call_languages();

-- start_host_session: only the five languages, 15-user cap
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
  v_active_hosts integer;
  v_other_active_group uuid;
  v_same_group_active boolean;
  v_host_lang text;
  v_profile_lang text;
  v_cap jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_host_lang := COALESCE(NULLIF(trim(p_host_language), ''), public.profile_call_language(v_user_id));
  v_profile_lang := public.profile_call_language(v_user_id);

  IF NOT public.is_indian_call_language(v_host_lang)
     OR NOT public.is_indian_call_language(v_profile_lang)
     OR public.normalize_call_language(v_host_lang) <> public.normalize_call_language(v_profile_lang) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Group calls are only available if your profile language is Hindi, Bengali, Marathi, Telugu, or Tamil.'
    );
  END IF;

  v_cap := public.assert_language_call_capacity(v_host_lang, 1);
  IF COALESCE((v_cap->>'allowed')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', COALESCE(v_cap->>'error', 'This language is at capacity'));
  END IF;

  UPDATE public.group_active_hosts
  SET is_active = false
  WHERE host_id = v_user_id
    AND is_active = true
    AND last_heartbeat_at < now() - interval '90 seconds';

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

  SELECT COUNT(*) INTO v_active_hosts
  FROM public.group_active_hosts
  WHERE group_id = p_group_id
    AND is_active = true
    AND host_id <> v_user_id;

  IF v_active_hosts >= 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'This group already has 3 active hosts. Try another.');
  END IF;

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

  UPDATE public.private_groups
  SET is_live = true,
      updated_at = now(),
      current_host_id = COALESCE(current_host_id, v_user_id),
      current_host_name = COALESCE(current_host_name, p_host_name)
  WHERE id = p_group_id;

  RETURN jsonb_build_object(
    'success', true,
    'active_hosts', v_active_hosts + 1,
    'reused', v_same_group_active
  );
END;
$function$;

-- join_group_atomic: language match + 15-user cap
CREATE OR REPLACE FUNCTION public.join_group_atomic(p_group_id uuid, p_user_id uuid, p_max_participants integer DEFAULT 15)
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
  v_cap jsonb;
  v_max INT := LEAST(COALESCE(p_max_participants, 15), 15);
BEGIN
  SELECT host_id, stream_id, host_language INTO v_host_id, v_stream_id, v_host_language
  FROM public.group_active_hosts
  WHERE group_id = p_group_id
    AND is_active = true
    AND last_heartbeat_at > now() - interval '2 minutes'
  ORDER BY started_at ASC LIMIT 1;

  IF v_host_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No live host in this group right now');
  END IF;

  v_joiner_lang := public.profile_call_language(p_user_id);

  IF NOT public.is_indian_call_language(v_host_language)
     OR NOT public.is_indian_call_language(v_joiner_lang)
     OR public.normalize_call_language(v_host_language) <> public.normalize_call_language(v_joiner_lang) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Group calls are only for Hindi, Bengali, Marathi, Telugu, and Tamil, and you must match the host language.'
    );
  END IF;

  v_cap := public.assert_language_call_capacity(v_joiner_lang, 1);
  IF COALESCE((v_cap->>'allowed')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', COALESCE(v_cap->>'error', 'This language is at capacity'));
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

GRANT EXECUTE ON FUNCTION public.normalize_call_language(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_indian_call_language(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.profile_call_language(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.count_active_call_users_for_language(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assert_language_call_capacity(text, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.start_host_session(uuid, text, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_group_atomic(uuid, uuid, integer) TO authenticated, service_role;
