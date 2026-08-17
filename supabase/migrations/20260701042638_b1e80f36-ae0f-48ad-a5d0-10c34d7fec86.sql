CREATE POLICY "mma_auth_read" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'meowmeow-app-attachment');

CREATE POLICY "mma_auth_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'meowmeow-app-attachment'
    AND (storage.foldername(name))[1] = 'meowmeow'
    AND (storage.foldername(name))[2] = 'app'
    AND (storage.foldername(name))[3] = 'attachment'
  );

CREATE POLICY "mma_owner_delete" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'meowmeow-app-attachment' AND owner = auth.uid());

CREATE POLICY "mma_service_all" ON storage.objects FOR ALL TO service_role
  USING (bucket_id = 'meowmeow-app-attachment')
  WITH CHECK (bucket_id = 'meowmeow-app-attachment');

UPDATE public.group_chat_rooms SET max_users = 11 WHERE max_users IS DISTINCT FROM 11;
ALTER TABLE public.group_chat_rooms ALTER COLUMN max_users SET DEFAULT 11;

CREATE OR REPLACE FUNCTION public.group_chat_join(p_room_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_gender text;
  v_room RECORD;
  v_balance numeric;
  v_existing uuid;
  v_men_count int;
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('success',false,'error','unauthenticated'); END IF;
  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = v_user LIMIT 1;
  IF v_gender IS DISTINCT FROM 'male' THEN
    RETURN jsonb_build_object('success',false,'error','only men can join');
  END IF;
  v_balance := public.canonical_wallet_balance(v_user);
  IF v_balance < 2 THEN
    RETURN jsonb_build_object('success',false,'error','insufficient balance','balance',v_balance);
  END IF;
  SELECT * INTO v_room FROM public.group_chat_rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.status <> 'live' OR v_room.current_session_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','room not live');
  END IF;
  SELECT count(*) INTO v_men_count
    FROM public.group_chat_participants p
    JOIN public.profiles pr ON pr.user_id = p.user_id
   WHERE p.session_id = v_room.current_session_id
     AND p.left_at IS NULL
     AND pr.gender = 'male';
  IF v_men_count >= 10 THEN
    RETURN jsonb_build_object('success',false,'error','room full (max 10 men)');
  END IF;
  SELECT id INTO v_existing FROM public.group_chat_participants
    WHERE session_id = v_room.current_session_id AND user_id = v_user AND left_at IS NULL LIMIT 1;
  IF v_existing IS NOT NULL THEN
    RETURN jsonb_build_object('success',true,'session_id',v_room.current_session_id,'already',true);
  END IF;
  INSERT INTO public.group_chat_participants (session_id, user_id) VALUES (v_room.current_session_id, v_user);
  UPDATE public.group_chat_rooms
     SET current_participant_count = current_participant_count + 1, updated_at = now()
   WHERE id = p_room_id;
  RETURN jsonb_build_object('success',true,'session_id',v_room.current_session_id);
END $$;