
-- CHT-C-03: Enforce RLS on chat_messages SELECT so only participants can read
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'chat_messages' AND policyname = 'Users can only read their own messages'
  ) THEN
    CREATE POLICY "Users can only read their own messages"
      ON public.chat_messages
      FOR SELECT
      TO authenticated
      USING (sender_id = auth.uid() OR receiver_id = auth.uid());
  END IF;
END $$;

-- GRP-C-01: Atomic participant count increment (prevents race condition > 100)
CREATE OR REPLACE FUNCTION public.join_group_atomic(
  p_group_id UUID,
  p_user_id UUID,
  p_max_participants INT DEFAULT 100
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_count INT;
BEGIN
  -- Atomic increment with guard
  UPDATE private_groups
  SET participant_count = participant_count + 1,
      updated_at = now()
  WHERE id = p_group_id
    AND participant_count < p_max_participants
    AND is_active = true
    AND is_live = true
  RETURNING participant_count INTO v_new_count;

  IF v_new_count IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Group is full or not live');
  END IF;

  -- Upsert membership
  INSERT INTO group_memberships (group_id, user_id, has_access, gift_amount_paid)
  VALUES (p_group_id, p_user_id, true, 0)
  ON CONFLICT (group_id, user_id)
  DO UPDATE SET has_access = true, joined_at = now();

  RETURN jsonb_build_object('success', true, 'participant_count', v_new_count);
END;
$$;

-- GRP-C-02: Safe stop-live that deactivates memberships instead of deleting
CREATE OR REPLACE FUNCTION public.stop_live_safe(p_group_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Deactivate memberships instead of deleting (prevents FK errors during billing)
  UPDATE group_memberships
  SET has_access = false
  WHERE group_id = p_group_id;

  -- Reset group state
  UPDATE private_groups
  SET is_live = false,
      stream_id = NULL,
      participant_count = 0,
      current_host_id = NULL,
      current_host_name = NULL,
      updated_at = now()
  WHERE id = p_group_id;

  RETURN jsonb_build_object('success', true);
END;
$$;
