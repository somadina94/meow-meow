-- ============================================================
-- Multi-host private groups (up to 3 simultaneous hosts per group)
-- ============================================================

-- 1. Track every active host session in a group
CREATE TABLE IF NOT EXISTS public.group_active_hosts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES public.private_groups(id) ON DELETE CASCADE,
  host_id uuid NOT NULL,
  host_name text NOT NULL,
  host_photo text,
  host_language text,
  stream_id text,
  participant_count integer NOT NULL DEFAULT 0,
  started_at timestamptz NOT NULL DEFAULT now(),
  last_heartbeat_at timestamptz NOT NULL DEFAULT now(),
  is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT group_active_hosts_unique_active UNIQUE (group_id, host_id)
);

CREATE INDEX IF NOT EXISTS idx_group_active_hosts_group_active
  ON public.group_active_hosts(group_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_group_active_hosts_host
  ON public.group_active_hosts(host_id) WHERE is_active = true;

ALTER TABLE public.group_active_hosts ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can see active hosts (so members can pick which to join)
CREATE POLICY "Authenticated users can view active hosts"
ON public.group_active_hosts FOR SELECT
TO authenticated
USING (true);

-- A host can only insert/update/delete their own host session
CREATE POLICY "Hosts manage their own session"
ON public.group_active_hosts FOR ALL
TO authenticated
USING (auth.uid() = host_id)
WITH CHECK (auth.uid() = host_id);

-- 2. Track which host a member chose to join (drives billing)
ALTER TABLE public.group_memberships
  ADD COLUMN IF NOT EXISTS joined_host_id uuid;

CREATE INDEX IF NOT EXISTS idx_group_memberships_joined_host
  ON public.group_memberships(joined_host_id) WHERE joined_host_id IS NOT NULL;

-- 3. RPC: start a host session (max 3 per group, 1 per woman across all groups)
CREATE OR REPLACE FUNCTION public.start_host_session(
  p_group_id uuid,
  p_host_name text,
  p_host_photo text DEFAULT NULL,
  p_host_language text DEFAULT NULL,
  p_stream_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_active_hosts integer;
  v_already_hosting integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Lock group row
  PERFORM 1 FROM public.private_groups WHERE id = p_group_id FOR UPDATE;

  -- Check if user is already hosting any group
  SELECT COUNT(*) INTO v_already_hosting
  FROM public.group_active_hosts
  WHERE host_id = v_user_id AND is_active = true;

  IF v_already_hosting > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'You are already hosting another group. Stop that first.');
  END IF;

  -- Check 3-host cap
  SELECT COUNT(*) INTO v_active_hosts
  FROM public.group_active_hosts
  WHERE group_id = p_group_id AND is_active = true;

  IF v_active_hosts >= 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'This group already has 3 active hosts. Try another.');
  END IF;

  -- Insert host session
  INSERT INTO public.group_active_hosts (
    group_id, host_id, host_name, host_photo, host_language, stream_id, is_active
  ) VALUES (
    p_group_id, v_user_id, p_host_name, p_host_photo, p_host_language, p_stream_id, true
  )
  ON CONFLICT (group_id, host_id) DO UPDATE SET
    host_name = EXCLUDED.host_name,
    host_photo = EXCLUDED.host_photo,
    host_language = EXCLUDED.host_language,
    stream_id = EXCLUDED.stream_id,
    is_active = true,
    started_at = now(),
    last_heartbeat_at = now();

  -- Mark group as live, set first/oldest host as the legacy current_host_*
  UPDATE public.private_groups
  SET is_live = true,
      updated_at = now(),
      current_host_id = COALESCE(current_host_id, v_user_id),
      current_host_name = COALESCE(current_host_name, p_host_name)
  WHERE id = p_group_id;

  RETURN jsonb_build_object('success', true, 'active_hosts', v_active_hosts + 1);
END;
$$;

-- 4. RPC: stop a host session
CREATE OR REPLACE FUNCTION public.stop_host_session(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_remaining integer;
  v_next_host record;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  UPDATE public.group_active_hosts
  SET is_active = false
  WHERE group_id = p_group_id AND host_id = v_user_id;

  -- Detach members who joined this host
  UPDATE public.group_memberships
  SET joined_host_id = NULL
  WHERE group_id = p_group_id AND joined_host_id = v_user_id;

  SELECT COUNT(*) INTO v_remaining
  FROM public.group_active_hosts
  WHERE group_id = p_group_id AND is_active = true;

  IF v_remaining = 0 THEN
    UPDATE public.private_groups
    SET is_live = false,
        stream_id = NULL,
        current_host_id = NULL,
        current_host_name = NULL,
        participant_count = 0,
        updated_at = now()
    WHERE id = p_group_id;
  ELSE
    -- Promote the oldest remaining host to legacy current_host_*
    SELECT host_id, host_name INTO v_next_host
    FROM public.group_active_hosts
    WHERE group_id = p_group_id AND is_active = true
    ORDER BY started_at ASC
    LIMIT 1;

    UPDATE public.private_groups
    SET current_host_id = v_next_host.host_id,
        current_host_name = v_next_host.host_name,
        updated_at = now()
    WHERE id = p_group_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'remaining_hosts', v_remaining);
END;
$$;

-- 5. Trigger to auto-bump host updated_at on heartbeat etc.
CREATE OR REPLACE FUNCTION public.touch_group_active_host()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.last_heartbeat_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_touch_group_active_host ON public.group_active_hosts;
CREATE TRIGGER trg_touch_group_active_host
BEFORE UPDATE ON public.group_active_hosts
FOR EACH ROW
WHEN (OLD.last_heartbeat_at IS NOT DISTINCT FROM NEW.last_heartbeat_at)
EXECUTE FUNCTION public.touch_group_active_host();