
CREATE TABLE public.free_chat_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  woman_user_id uuid NOT NULL,
  man_user_id uuid NOT NULL,
  total_seconds_used integer NOT NULL DEFAULT 0,
  is_blocked boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(woman_user_id, man_user_id)
);

ALTER TABLE public.free_chat_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own free chat usage"
ON public.free_chat_usage FOR SELECT TO authenticated
USING (auth.uid() = woman_user_id OR auth.uid() = man_user_id);

CREATE POLICY "Women can insert their own free chat usage"
ON public.free_chat_usage FOR INSERT TO authenticated
WITH CHECK (auth.uid() = woman_user_id);

CREATE POLICY "Service role can update free chat usage"
ON public.free_chat_usage FOR UPDATE TO authenticated
USING (auth.uid() = woman_user_id);

-- Function to check and update free chat time
CREATE OR REPLACE FUNCTION public.update_free_chat_usage(
  p_woman_id uuid,
  p_man_id uuid,
  p_seconds integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_record free_chat_usage%ROWTYPE;
  v_max_seconds integer := 300; -- 5 minutes
  v_new_total integer;
BEGIN
  -- Upsert the record
  INSERT INTO free_chat_usage (woman_user_id, man_user_id, total_seconds_used)
  VALUES (p_woman_id, p_man_id, p_seconds)
  ON CONFLICT (woman_user_id, man_user_id)
  DO UPDATE SET 
    total_seconds_used = free_chat_usage.total_seconds_used + p_seconds,
    updated_at = now()
  RETURNING * INTO v_record;

  v_new_total := v_record.total_seconds_used;

  -- Auto-block if 5 minutes reached
  IF v_new_total >= v_max_seconds AND NOT v_record.is_blocked THEN
    UPDATE free_chat_usage 
    SET is_blocked = true, updated_at = now()
    WHERE id = v_record.id;
    
    RETURN jsonb_build_object(
      'blocked', true,
      'seconds_used', v_new_total,
      'remaining_seconds', 0
    );
  END IF;

  RETURN jsonb_build_object(
    'blocked', v_record.is_blocked,
    'seconds_used', v_new_total,
    'remaining_seconds', GREATEST(v_max_seconds - v_new_total, 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_free_chat_usage(uuid, uuid, integer) TO authenticated;

-- Function to check free chat status
CREATE OR REPLACE FUNCTION public.check_free_chat_status(
  p_woman_id uuid,
  p_man_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_record free_chat_usage%ROWTYPE;
  v_max_seconds integer := 300;
BEGIN
  SELECT * INTO v_record
  FROM free_chat_usage
  WHERE woman_user_id = p_woman_id AND man_user_id = p_man_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'blocked', false,
      'seconds_used', 0,
      'remaining_seconds', v_max_seconds,
      'is_free_chat', true
    );
  END IF;

  RETURN jsonb_build_object(
    'blocked', v_record.is_blocked,
    'seconds_used', v_record.total_seconds_used,
    'remaining_seconds', GREATEST(v_max_seconds - v_record.total_seconds_used, 0),
    'is_free_chat', NOT v_record.is_blocked
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_free_chat_status(uuid, uuid) TO authenticated;
