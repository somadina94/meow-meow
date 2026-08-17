-- Group chat: End must always take the room offline (billing failure must not roll it back).
-- Host is a participant so People/header can show who is hosting.
-- Realtime on sessions so clients see ended_at.

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.group_chat_sessions;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.group_chat_go_live(p_room_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_gender text;
  v_room RECORD;
  v_session_id uuid;
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('success',false,'error','unauthenticated'); END IF;
  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = v_user LIMIT 1;
  IF v_gender IS DISTINCT FROM 'female' THEN
    RETURN jsonb_build_object('success',false,'error','only women can host');
  END IF;
  SELECT * INTO v_room FROM public.group_chat_rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','room not found'); END IF;
  IF v_room.status = 'live' THEN
    RETURN jsonb_build_object('success',false,'error','room already live');
  END IF;

  UPDATE public.group_chat_sessions SET ended_at = now() WHERE host_id = v_user AND ended_at IS NULL;
  UPDATE public.group_chat_rooms SET status='offline', current_host_id=NULL, current_session_id=NULL, current_participant_count=0
    WHERE current_host_id = v_user;

  INSERT INTO public.group_chat_sessions (room_id, host_id) VALUES (p_room_id, v_user) RETURNING id INTO v_session_id;
  INSERT INTO public.group_chat_participants (session_id, user_id)
    VALUES (v_session_id, v_user);

  UPDATE public.group_chat_rooms
    SET status='live', current_host_id=v_user, current_session_id=v_session_id, current_participant_count=0, updated_at=now()
    WHERE id = p_room_id;
  RETURN jsonb_build_object('success',true,'session_id',v_session_id);
END $$;

-- Existing live rooms: add missing host rows so People can show them.
INSERT INTO public.group_chat_participants (session_id, user_id)
SELECT s.id, s.host_id
FROM public.group_chat_sessions s
WHERE s.ended_at IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.group_chat_participants p
    WHERE p.session_id = s.id AND p.user_id = s.host_id AND p.left_at IS NULL
  );

CREATE OR REPLACE FUNCTION public.group_chat_end_live(p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_session RECORD;
  v_man uuid;
BEGIN
  SELECT * INTO v_session FROM public.group_chat_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','not found'); END IF;
  IF v_user IS NULL THEN RETURN jsonb_build_object('success',false,'error','unauthenticated'); END IF;
  IF v_session.host_id IS DISTINCT FROM v_user AND NOT public.has_role(v_user,'admin') THEN
    RETURN jsonb_build_object('success',false,'error','not host');
  END IF;

  -- Best-effort leftover billing; never block taking the room offline.
  BEGIN
    FOR v_man IN
      SELECT p.user_id
        FROM public.group_chat_participants gcp
        JOIN public.profiles p ON p.user_id = gcp.user_id
       WHERE gcp.session_id = p_session_id
         AND gcp.left_at IS NULL
         AND p.gender = 'male'
    LOOP
      BEGIN
        PERFORM public.bill_group_chat_leftover(p_session_id, v_man);
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  UPDATE public.group_chat_sessions SET ended_at = COALESCE(ended_at, now()) WHERE id = p_session_id;
  UPDATE public.group_chat_participants SET left_at = now() WHERE session_id = p_session_id AND left_at IS NULL;
  UPDATE public.group_chat_rooms
    SET status='offline', current_host_id=NULL, current_session_id=NULL, current_participant_count=0, updated_at=now()
    WHERE id = v_session.room_id;
  RETURN jsonb_build_object('success',true);
END $$;

CREATE OR REPLACE FUNCTION public.group_chat_leave(p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_session RECORD;
  v_rows int;
  v_gender text;
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('success',false,'error','unauthenticated'); END IF;

  SELECT * INTO v_session FROM public.group_chat_sessions WHERE id = p_session_id;
  -- Host Leave is End Live — a host walking away must close the room for everyone.
  IF FOUND AND v_session.host_id = v_user AND v_session.ended_at IS NULL THEN
    RETURN public.group_chat_end_live(p_session_id);
  END IF;

  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = v_user LIMIT 1;
  IF v_gender = 'male' THEN
    BEGIN
      PERFORM public.bill_group_chat_leftover(p_session_id, v_user);
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  UPDATE public.group_chat_participants SET left_at = now()
    WHERE session_id = p_session_id AND user_id = v_user AND left_at IS NULL;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 AND v_session.room_id IS NOT NULL THEN
    UPDATE public.group_chat_rooms
      SET current_participant_count = GREATEST(current_participant_count - 1, 0), updated_at=now()
      WHERE id = v_session.room_id;
  END IF;
  RETURN jsonb_build_object('success',true);
END $$;
