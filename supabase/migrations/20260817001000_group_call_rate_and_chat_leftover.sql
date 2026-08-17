-- Restore group-call host earning to ₹2/min per active man (client spec).
-- Bill leftover seconds as a full minute when a man leaves group chat or the host ends the room.
-- Keep KYC insert/update policies usable for upsert.

UPDATE public.chat_pricing
   SET group_call_women_earning_rate = 2.00,
       group_call_rate_per_minute    = 4.00,
       updated_at = now()
 WHERE is_active = true;

ALTER TABLE public.chat_pricing
  ALTER COLUMN group_call_women_earning_rate SET DEFAULT 2.00;

-- Extra full minute when elapsed remainder is 1–59 seconds (or no minute billed yet).
CREATE OR REPLACE FUNCTION public.bill_group_chat_leftover(p_session_id uuid, p_man_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_part RECORD;
  v_elapsed numeric;
  v_remainder numeric;
BEGIN
  SELECT * INTO v_part
    FROM public.group_chat_participants
   WHERE session_id = p_session_id AND user_id = p_man_id AND left_at IS NULL
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'not active participant');
  END IF;

  v_elapsed := EXTRACT(EPOCH FROM (now() - v_part.joined_at));
  IF v_elapsed < 1 THEN
    RETURN jsonb_build_object('success', true, 'skipped', true);
  END IF;

  v_remainder := v_elapsed - COALESCE(v_part.last_billed_minute, 0) * 60;
  IF v_remainder < 1 THEN
    RETURN jsonb_build_object('success', true, 'skipped', true);
  END IF;

  RETURN public.bill_group_chat_minute(p_session_id, p_man_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.bill_group_chat_leftover(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.group_chat_leave(p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_room_id uuid;
  v_rows int;
  v_gender text;
BEGIN
  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = v_user LIMIT 1;
  IF v_gender = 'male' THEN
    PERFORM public.bill_group_chat_leftover(p_session_id, v_user);
  END IF;

  UPDATE public.group_chat_participants SET left_at = now()
    WHERE session_id = p_session_id AND user_id = v_user AND left_at IS NULL;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    SELECT room_id INTO v_room_id FROM public.group_chat_sessions WHERE id = p_session_id;
    UPDATE public.group_chat_rooms
      SET current_participant_count = GREATEST(current_participant_count - 1, 0), updated_at=now()
      WHERE id = v_room_id;
  END IF;
  RETURN jsonb_build_object('success',true);
END $$;

CREATE OR REPLACE FUNCTION public.group_chat_end_live(p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_session RECORD;
  v_man uuid;
BEGIN
  SELECT * INTO v_session FROM public.group_chat_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','not found'); END IF;
  IF v_session.host_id <> v_user AND NOT public.has_role(v_user,'admin') THEN
    RETURN jsonb_build_object('success',false,'error','not host');
  END IF;

  FOR v_man IN
    SELECT p.user_id
      FROM public.group_chat_participants gcp
      JOIN public.profiles p ON p.user_id = gcp.user_id
     WHERE gcp.session_id = p_session_id
       AND gcp.left_at IS NULL
       AND p.gender = 'male'
  LOOP
    PERFORM public.bill_group_chat_leftover(p_session_id, v_man);
  END LOOP;

  UPDATE public.group_chat_sessions SET ended_at = COALESCE(ended_at, now()) WHERE id = p_session_id;
  UPDATE public.group_chat_participants SET left_at = now() WHERE session_id = p_session_id AND left_at IS NULL;
  UPDATE public.group_chat_rooms
    SET status='offline', current_host_id=NULL, current_session_id=NULL, current_participant_count=0, updated_at=now()
    WHERE id = v_session.room_id;
  RETURN jsonb_build_object('success',true);
END $$;

DROP POLICY IF EXISTS "Users can create own KYC" ON public.women_kyc;
CREATE POLICY "Users can create own KYC"
ON public.women_kyc FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own KYC" ON public.women_kyc;
DROP POLICY IF EXISTS "Users can update own pending KYC" ON public.women_kyc;
CREATE POLICY "Users can update own KYC"
ON public.women_kyc FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
