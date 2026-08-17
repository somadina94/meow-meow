
-- =====================================================
-- FRIEND REQUEST & BLOCK SYSTEM - Database Functions
-- All validation logic lives in the database for safety
-- =====================================================

-- 1. SEND FRIEND REQUEST
-- Validates: no duplicates, no existing friendship, no blocks
CREATE OR REPLACE FUNCTION public.send_friend_request(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  -- Cannot friend yourself
  IF v_user_id = p_target_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send friend request to yourself');
  END IF;

  -- Check if either user has blocked the other
  IF EXISTS (
    SELECT 1 FROM user_blocks
    WHERE (blocked_by = v_user_id AND blocked_user_id = p_target_user_id)
       OR (blocked_by = p_target_user_id AND blocked_user_id = v_user_id)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send friend request - user is blocked');
  END IF;

  -- Check if already friends
  IF EXISTS (
    SELECT 1 FROM user_friends
    WHERE status = 'accepted'
      AND ((user_id = v_user_id AND friend_id = p_target_user_id)
        OR (user_id = p_target_user_id AND friend_id = v_user_id))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Already friends with this user');
  END IF;

  -- Check if a pending request already exists (either direction)
  IF EXISTS (
    SELECT 1 FROM user_friends
    WHERE status = 'pending'
      AND ((user_id = v_user_id AND friend_id = p_target_user_id)
        OR (user_id = p_target_user_id AND friend_id = v_user_id))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'A friend request already exists between you two');
  END IF;

  -- Insert the friend request as pending
  INSERT INTO user_friends (user_id, friend_id, status, created_by)
  VALUES (v_user_id, p_target_user_id, 'pending', v_user_id);

  RETURN jsonb_build_object('success', true, 'message', 'Friend request sent');
END;
$$;

-- 2. ACCEPT FRIEND REQUEST
-- Only the recipient can accept
CREATE OR REPLACE FUNCTION public.accept_friend_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_request RECORD;
BEGIN
  -- Get the request - only the recipient (friend_id) can accept
  SELECT * INTO v_request
  FROM user_friends
  WHERE id = p_request_id
    AND friend_id = v_user_id
    AND status = 'pending';

  IF v_request IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Friend request not found or already processed');
  END IF;

  -- Check blocks haven't been created since the request
  IF EXISTS (
    SELECT 1 FROM user_blocks
    WHERE (blocked_by = v_user_id AND blocked_user_id = v_request.user_id)
       OR (blocked_by = v_request.user_id AND blocked_user_id = v_user_id)
  ) THEN
    -- Delete the request since there's a block
    DELETE FROM user_friends WHERE id = p_request_id;
    RETURN jsonb_build_object('success', false, 'error', 'Cannot accept - user is blocked');
  END IF;

  -- Accept the request
  UPDATE user_friends
  SET status = 'accepted', updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'message', 'Friend request accepted');
END;
$$;

-- 3. REJECT FRIEND REQUEST
-- Only the recipient can reject
CREATE OR REPLACE FUNCTION public.reject_friend_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  -- Delete the pending request (only recipient can reject)
  DELETE FROM user_friends
  WHERE id = p_request_id
    AND friend_id = v_user_id
    AND status = 'pending';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Friend request not found');
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Friend request rejected');
END;
$$;

-- 4. CANCEL FRIEND REQUEST
-- Only the sender can cancel
CREATE OR REPLACE FUNCTION public.cancel_friend_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  DELETE FROM user_friends
  WHERE id = p_request_id
    AND user_id = v_user_id
    AND status = 'pending';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Friend request not found');
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'Friend request canceled');
END;
$$;

-- 5. UNFRIEND USER
-- Either user in the friendship can unfriend
CREATE OR REPLACE FUNCTION public.unfriend_user(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  DELETE FROM user_friends
  WHERE status = 'accepted'
    AND ((user_id = v_user_id AND friend_id = p_target_user_id)
      OR (user_id = p_target_user_id AND friend_id = v_user_id));

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Friendship not found');
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'User unfriended');
END;
$$;

-- 6. BLOCK USER
-- Automatically removes friendship and cancels pending requests
CREATE OR REPLACE FUNCTION public.block_user(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  -- Cannot block yourself
  IF v_user_id = p_target_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot block yourself');
  END IF;

  -- Check if already blocked
  IF EXISTS (
    SELECT 1 FROM user_blocks
    WHERE blocked_by = v_user_id AND blocked_user_id = p_target_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'User is already blocked');
  END IF;

  -- Remove any friendship (accepted or pending) between the two users
  DELETE FROM user_friends
  WHERE (user_id = v_user_id AND friend_id = p_target_user_id)
     OR (user_id = p_target_user_id AND friend_id = v_user_id);

  -- End any active chat sessions between them
  UPDATE active_chat_sessions
  SET status = 'ended', ended_at = now(), end_reason = 'user_blocked'
  WHERE status = 'active'
    AND ((man_user_id = v_user_id AND woman_user_id = p_target_user_id)
      OR (man_user_id = p_target_user_id AND woman_user_id = v_user_id));

  -- Insert the block
  INSERT INTO user_blocks (blocked_by, blocked_user_id, block_type)
  VALUES (v_user_id, p_target_user_id, 'manual');

  RETURN jsonb_build_object('success', true, 'message', 'User blocked');
END;
$$;

-- 7. UNBLOCK USER
CREATE OR REPLACE FUNCTION public.unblock_user(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  DELETE FROM user_blocks
  WHERE blocked_by = v_user_id AND blocked_user_id = p_target_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User is not blocked');
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'User unblocked');
END;
$$;

-- 8. CHECK RELATIONSHIP STATUS
-- Returns the relationship between two users
CREATE OR REPLACE FUNCTION public.get_relationship_status(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_is_blocked_by_me boolean := false;
  v_is_blocked_by_them boolean := false;
  v_is_friend boolean := false;
  v_pending_sent boolean := false;
  v_pending_received boolean := false;
  v_request_id uuid := null;
BEGIN
  -- Check blocks
  SELECT EXISTS (
    SELECT 1 FROM user_blocks WHERE blocked_by = v_user_id AND blocked_user_id = p_target_user_id
  ) INTO v_is_blocked_by_me;

  SELECT EXISTS (
    SELECT 1 FROM user_blocks WHERE blocked_by = p_target_user_id AND blocked_user_id = v_user_id
  ) INTO v_is_blocked_by_them;

  -- Check friendship
  SELECT EXISTS (
    SELECT 1 FROM user_friends
    WHERE status = 'accepted'
      AND ((user_id = v_user_id AND friend_id = p_target_user_id)
        OR (user_id = p_target_user_id AND friend_id = v_user_id))
  ) INTO v_is_friend;

  -- Check pending requests
  SELECT id INTO v_request_id FROM user_friends
  WHERE status = 'pending'
    AND user_id = v_user_id AND friend_id = p_target_user_id;
  v_pending_sent := v_request_id IS NOT NULL;

  IF NOT v_pending_sent THEN
    SELECT id INTO v_request_id FROM user_friends
    WHERE status = 'pending'
      AND user_id = p_target_user_id AND friend_id = v_user_id;
    v_pending_received := v_request_id IS NOT NULL;
  END IF;

  RETURN jsonb_build_object(
    'is_blocked_by_me', v_is_blocked_by_me,
    'is_blocked_by_them', v_is_blocked_by_them,
    'is_friend', v_is_friend,
    'pending_sent', v_pending_sent,
    'pending_received', v_pending_received,
    'request_id', v_request_id
  );
END;
$$;
