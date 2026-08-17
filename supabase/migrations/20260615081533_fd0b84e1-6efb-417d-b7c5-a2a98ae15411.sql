
-- =====================================================================
-- GROUP CHAT ROOMS — live women-hosted text chat rooms with billing
-- =====================================================================

-- 1) ROOMS ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.group_chat_rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  tree_type text NOT NULL,
  variant_number int NOT NULL,
  max_users int NOT NULL DEFAULT 20,
  status text NOT NULL DEFAULT 'offline', -- 'offline' | 'live'
  current_host_id uuid,
  current_session_id uuid,
  current_participant_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.group_chat_rooms TO anon, authenticated;
GRANT ALL ON public.group_chat_rooms TO service_role;
ALTER TABLE public.group_chat_rooms ENABLE ROW LEVEL SECURITY;
CREATE POLICY gcr_select_all ON public.group_chat_rooms FOR SELECT USING (true);
CREATE POLICY gcr_admin_all ON public.group_chat_rooms FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- 2) SESSIONS ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.group_chat_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.group_chat_rooms(id) ON DELETE CASCADE,
  host_id uuid NOT NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  total_men_minutes int NOT NULL DEFAULT 0,
  total_host_earning numeric(12,2) NOT NULL DEFAULT 0,
  total_platform_revenue numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS gcs_room_active_idx ON public.group_chat_sessions(room_id) WHERE ended_at IS NULL;
CREATE INDEX IF NOT EXISTS gcs_host_idx ON public.group_chat_sessions(host_id);
GRANT SELECT ON public.group_chat_sessions TO authenticated;
GRANT ALL ON public.group_chat_sessions TO service_role;
ALTER TABLE public.group_chat_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY gcs_select_all ON public.group_chat_sessions FOR SELECT TO authenticated USING (true);
CREATE POLICY gcs_admin_all ON public.group_chat_sessions FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- 3) PARTICIPANTS -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.group_chat_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.group_chat_sessions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  joined_at timestamptz NOT NULL DEFAULT now(),
  left_at timestamptz,
  total_seconds int NOT NULL DEFAULT 0,
  total_billed numeric(12,2) NOT NULL DEFAULT 0,
  last_billed_minute int NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS gcp_session_active_idx ON public.group_chat_participants(session_id) WHERE left_at IS NULL;
CREATE INDEX IF NOT EXISTS gcp_user_idx ON public.group_chat_participants(user_id);
GRANT SELECT ON public.group_chat_participants TO authenticated;
GRANT ALL ON public.group_chat_participants TO service_role;
ALTER TABLE public.group_chat_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY gcp_select_all ON public.group_chat_participants FOR SELECT TO authenticated USING (true);
CREATE POLICY gcp_admin_all ON public.group_chat_participants FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- 4) MESSAGES ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.group_chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.group_chat_sessions(id) ON DELETE CASCADE,
  room_id uuid NOT NULL REFERENCES public.group_chat_rooms(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL,
  sender_name text,
  sender_gender text,
  body text,
  media_url text,
  media_type text,
  reply_to uuid REFERENCES public.group_chat_messages(id) ON DELETE SET NULL,
  pinned boolean NOT NULL DEFAULT false,
  edited_at timestamptz,
  deleted_at timestamptz,
  translated_cache jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS gcm_session_created_idx ON public.group_chat_messages(session_id, created_at DESC);
GRANT SELECT, INSERT, UPDATE ON public.group_chat_messages TO authenticated;
GRANT ALL ON public.group_chat_messages TO service_role;
ALTER TABLE public.group_chat_messages ENABLE ROW LEVEL SECURITY;
-- Read: any participant of the session, or host, or admin
CREATE POLICY gcm_select ON public.group_chat_messages FOR SELECT TO authenticated USING (
  public.has_role(auth.uid(), 'admin')
  OR EXISTS (SELECT 1 FROM public.group_chat_sessions s WHERE s.id = session_id AND s.host_id = auth.uid())
  OR EXISTS (SELECT 1 FROM public.group_chat_participants p WHERE p.session_id = group_chat_messages.session_id AND p.user_id = auth.uid())
);
CREATE POLICY gcm_insert ON public.group_chat_messages FOR INSERT TO authenticated WITH CHECK (
  sender_id = auth.uid() AND (
    EXISTS (SELECT 1 FROM public.group_chat_sessions s WHERE s.id = session_id AND s.host_id = auth.uid() AND s.ended_at IS NULL)
    OR EXISTS (SELECT 1 FROM public.group_chat_participants p WHERE p.session_id = group_chat_messages.session_id AND p.user_id = auth.uid() AND p.left_at IS NULL)
  )
);
CREATE POLICY gcm_update_own ON public.group_chat_messages FOR UPDATE TO authenticated
  USING (sender_id = auth.uid() OR public.has_role(auth.uid(),'admin')
    OR EXISTS (SELECT 1 FROM public.group_chat_sessions s WHERE s.id = session_id AND s.host_id = auth.uid()))
  WITH CHECK (true);

-- 5) MODERATION -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.group_chat_moderation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.group_chat_sessions(id) ON DELETE CASCADE,
  target_user_id uuid NOT NULL,
  action text NOT NULL, -- 'mute' | 'unmute' | 'remove' | 'ban'
  by_host_id uuid NOT NULL,
  reason text,
  until timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS gcmod_session_idx ON public.group_chat_moderation(session_id, target_user_id);
GRANT SELECT, INSERT ON public.group_chat_moderation TO authenticated;
GRANT ALL ON public.group_chat_moderation TO service_role;
ALTER TABLE public.group_chat_moderation ENABLE ROW LEVEL SECURITY;
CREATE POLICY gcmod_select ON public.group_chat_moderation FOR SELECT TO authenticated USING (
  public.has_role(auth.uid(),'admin')
  OR by_host_id = auth.uid()
  OR target_user_id = auth.uid()
);
CREATE POLICY gcmod_insert_host ON public.group_chat_moderation FOR INSERT TO authenticated WITH CHECK (
  by_host_id = auth.uid()
  AND EXISTS (SELECT 1 FROM public.group_chat_sessions s WHERE s.id = session_id AND s.host_id = auth.uid())
);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.group_chat_rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE public.group_chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.group_chat_participants;

-- =====================================================================
-- SEED 1000 ROOMS = 50 trees × 20 variants
-- =====================================================================
DO $$
DECLARE
  trees text[] := ARRAY[
    'Banyan','Mango','Neem','Coconut','Ashoka','Gulmohar','Peepal','Tamarind','Jamun','Sandalwood',
    'Teak','Bamboo','Cedar','Pine','Oak','Maple','Birch','Rosewood','Eucalyptus','Cypress',
    'Walnut','Almond','Cashew','Guava','Lemon','Orange','Apple','Pear','Cherry','Plum',
    'Fig','Date','Olive','Palm','Willow','Sycamore','Magnolia','Jacaranda','Frangipani','Hibiscus',
    'Bottlebrush','Bauhinia','Champa','Kadamba','Silk','Karanja','Mahua','Sal','Shisham','Arjuna'
  ];
  t text;
  v int;
BEGIN
  FOREACH t IN ARRAY trees LOOP
    FOR v IN 1..20 LOOP
      INSERT INTO public.group_chat_rooms (name, tree_type, variant_number)
      VALUES (t || ' Tree ' || v, t, v)
      ON CONFLICT (name) DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- =====================================================================
-- RPCs
-- =====================================================================

-- HOST goes live
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
  -- end any other live session this host has
  UPDATE public.group_chat_sessions SET ended_at = now() WHERE host_id = v_user AND ended_at IS NULL;
  UPDATE public.group_chat_rooms SET status='offline', current_host_id=NULL, current_session_id=NULL, current_participant_count=0
    WHERE current_host_id = v_user;

  INSERT INTO public.group_chat_sessions (room_id, host_id) VALUES (p_room_id, v_user) RETURNING id INTO v_session_id;
  UPDATE public.group_chat_rooms
    SET status='live', current_host_id=v_user, current_session_id=v_session_id, current_participant_count=0, updated_at=now()
    WHERE id = p_room_id;
  RETURN jsonb_build_object('success',true,'session_id',v_session_id);
END $$;
GRANT EXECUTE ON FUNCTION public.group_chat_go_live(uuid) TO authenticated;

-- HOST ends live
CREATE OR REPLACE FUNCTION public.group_chat_end_live(p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_session RECORD;
BEGIN
  SELECT * INTO v_session FROM public.group_chat_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','not found'); END IF;
  IF v_session.host_id <> v_user AND NOT public.has_role(v_user,'admin') THEN
    RETURN jsonb_build_object('success',false,'error','not host');
  END IF;
  UPDATE public.group_chat_sessions SET ended_at = COALESCE(ended_at, now()) WHERE id = p_session_id;
  UPDATE public.group_chat_participants SET left_at = now() WHERE session_id = p_session_id AND left_at IS NULL;
  UPDATE public.group_chat_rooms
    SET status='offline', current_host_id=NULL, current_session_id=NULL, current_participant_count=0, updated_at=now()
    WHERE id = v_session.room_id;
  RETURN jsonb_build_object('success',true);
END $$;
GRANT EXECUTE ON FUNCTION public.group_chat_end_live(uuid) TO authenticated;

-- MAN joins a live room
CREATE OR REPLACE FUNCTION public.group_chat_join(p_room_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_gender text;
  v_room RECORD;
  v_balance numeric;
  v_existing uuid;
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('success',false,'error','unauthenticated'); END IF;
  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = v_user LIMIT 1;
  IF v_gender IS DISTINCT FROM 'male' THEN
    RETURN jsonb_build_object('success',false,'error','only men can join');
  END IF;
  v_balance := public.canonical_wallet_balance(v_user);
  IF v_balance < 2 THEN
    RETURN jsonb_build_object('success',false,'error','insufficient balance');
  END IF;
  SELECT * INTO v_room FROM public.group_chat_rooms WHERE id = p_room_id FOR UPDATE;
  IF NOT FOUND OR v_room.status <> 'live' OR v_room.current_session_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','room not live');
  END IF;
  IF v_room.current_participant_count >= v_room.max_users THEN
    RETURN jsonb_build_object('success',false,'error','room full');
  END IF;
  -- existing active participant?
  SELECT id INTO v_existing FROM public.group_chat_participants
    WHERE session_id = v_room.current_session_id AND user_id = v_user AND left_at IS NULL LIMIT 1;
  IF v_existing IS NOT NULL THEN
    RETURN jsonb_build_object('success',true,'session_id',v_room.current_session_id,'already',true);
  END IF;
  INSERT INTO public.group_chat_participants (session_id, user_id) VALUES (v_room.current_session_id, v_user);
  UPDATE public.group_chat_rooms SET current_participant_count = current_participant_count + 1, updated_at=now()
    WHERE id = p_room_id;
  RETURN jsonb_build_object('success',true,'session_id',v_room.current_session_id);
END $$;
GRANT EXECUTE ON FUNCTION public.group_chat_join(uuid) TO authenticated;

-- MAN leaves
CREATE OR REPLACE FUNCTION public.group_chat_leave(p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_room_id uuid;
  v_rows int;
BEGIN
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
GRANT EXECUTE ON FUNCTION public.group_chat_leave(uuid) TO authenticated;

-- PER-MINUTE BILLING — ₹2 man / ₹1 host / ₹1 platform
CREATE OR REPLACE FUNCTION public.bill_group_chat_minute(p_session_id uuid, p_man_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_session RECORD;
  v_part RECORD;
  v_balance numeric;
  v_minute int;
  v_man_idem text;
  v_host_idem text;
  v_plat_idem text;
  v_man_charge numeric := 2.00;
  v_host_earn  numeric := 1.00;
  v_plat_rev   numeric := 1.00;
  v_platform_user uuid;
BEGIN
  SELECT * INTO v_session FROM public.group_chat_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_session.ended_at IS NOT NULL THEN
    RETURN jsonb_build_object('success',false,'error','session not live');
  END IF;
  SELECT * INTO v_part FROM public.group_chat_participants
    WHERE session_id = p_session_id AND user_id = p_man_id AND left_at IS NULL LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','not active participant');
  END IF;

  v_minute := v_part.last_billed_minute + 1;
  v_man_idem  := 'groupchat:'||p_session_id::text||':'||p_man_id::text||':min:'||v_minute::text||':charge';
  v_host_idem := 'groupchat:'||p_session_id::text||':'||p_man_id::text||':min:'||v_minute::text||':host';
  v_plat_idem := 'groupchat:'||p_session_id::text||':'||p_man_id::text||':min:'||v_minute::text||':plat';

  -- already billed?
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_man_idem) THEN
    RETURN jsonb_build_object('success',true,'duplicate',true);
  END IF;

  v_balance := public.canonical_wallet_balance(p_man_id);
  IF v_balance < v_man_charge THEN
    RETURN jsonb_build_object('success',false,'insufficient',true,'balance',v_balance);
  END IF;

  -- Debit man
  INSERT INTO public.wallet_transactions
    (user_id, type, transaction_type, amount, description, session_id, session_type, idempotency_key, status, rate_per_minute, billing_metadata)
  VALUES
    (p_man_id, 'debit', 'debit', v_man_charge,
     'Group chat: min '||v_minute||' @ ₹'||v_man_charge||'/min',
     p_session_id, 'group_chat', v_man_idem, 'completed', v_man_charge,
     jsonb_build_object('minute',v_minute,'session',p_session_id,'kind','group_chat_minute_charge'));

  -- Credit host
  INSERT INTO public.wallet_transactions
    (user_id, type, transaction_type, amount, description, session_id, session_type, idempotency_key, status, rate_per_minute, billing_metadata)
  VALUES
    (v_session.host_id, 'credit', 'credit', v_host_earn,
     'Group chat earning: min '||v_minute||' from male user',
     p_session_id, 'group_chat', v_host_idem, 'completed', v_host_earn,
     jsonb_build_object('minute',v_minute,'session',p_session_id,'kind','group_chat_host_earning','man_id',p_man_id));

  -- Credit platform (skip if no platform user configured)
  SELECT user_id INTO v_platform_user FROM public.user_roles WHERE role = 'admin' ORDER BY user_id LIMIT 1;
  IF v_platform_user IS NOT NULL THEN
    INSERT INTO public.wallet_transactions
      (user_id, type, transaction_type, amount, description, session_id, session_type, idempotency_key, status, rate_per_minute, billing_metadata)
    VALUES
      (v_platform_user, 'credit', 'credit', v_plat_rev,
       'Group chat platform revenue: min '||v_minute,
       p_session_id, 'group_chat', v_plat_idem, 'completed', v_plat_rev,
       jsonb_build_object('minute',v_minute,'session',p_session_id,'kind','group_chat_platform_revenue','man_id',p_man_id));
  END IF;

  -- Bookkeeping
  UPDATE public.group_chat_participants
    SET last_billed_minute = v_minute,
        total_billed = total_billed + v_man_charge,
        total_seconds = total_seconds + 60
    WHERE id = v_part.id;
  UPDATE public.group_chat_sessions
    SET total_men_minutes = total_men_minutes + 1,
        total_host_earning = total_host_earning + v_host_earn,
        total_platform_revenue = total_platform_revenue + v_plat_rev
    WHERE id = p_session_id;

  RETURN jsonb_build_object('success',true,'minute',v_minute,'balance',v_balance - v_man_charge);
END $$;
GRANT EXECUTE ON FUNCTION public.bill_group_chat_minute(uuid, uuid) TO authenticated;
