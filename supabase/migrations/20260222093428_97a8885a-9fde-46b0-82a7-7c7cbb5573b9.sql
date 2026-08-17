
-- Table to track men's free chat minutes
CREATE TABLE public.men_free_chat_allowance (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE,
  first_login_date date NOT NULL DEFAULT CURRENT_DATE,
  free_minutes_total integer NOT NULL DEFAULT 10,
  free_minutes_used integer NOT NULL DEFAULT 0,
  last_reset_date date NOT NULL DEFAULT CURRENT_DATE,
  next_reset_date date NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '15 days')::date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.men_free_chat_allowance ENABLE ROW LEVEL SECURITY;

-- Users can read their own allowance
CREATE POLICY "Users can view own free allowance"
ON public.men_free_chat_allowance FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert their own allowance
CREATE POLICY "Users can create own free allowance"
ON public.men_free_chat_allowance FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own allowance
CREATE POLICY "Users can update own free allowance"
ON public.men_free_chat_allowance FOR UPDATE
USING (auth.uid() = user_id);

-- Admins can manage all
CREATE POLICY "Admins can manage all free allowances"
ON public.men_free_chat_allowance FOR ALL
USING (public.has_role(auth.uid(), 'admin'));

-- Function to check and use men's free minutes
CREATE OR REPLACE FUNCTION public.check_men_free_minutes(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_record RECORD;
  v_remaining integer;
BEGIN
  -- Get or create allowance record
  SELECT * INTO v_record
  FROM men_free_chat_allowance
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_record IS NULL THEN
    INSERT INTO men_free_chat_allowance (user_id)
    VALUES (p_user_id)
    RETURNING * INTO v_record;
  END IF;

  -- Check if reset is due (every 15 days from first login)
  IF CURRENT_DATE >= v_record.next_reset_date THEN
    UPDATE men_free_chat_allowance
    SET free_minutes_used = 0,
        last_reset_date = CURRENT_DATE,
        next_reset_date = (CURRENT_DATE + INTERVAL '15 days')::date,
        updated_at = now()
    WHERE user_id = p_user_id
    RETURNING * INTO v_record;
  END IF;

  v_remaining := GREATEST(0, v_record.free_minutes_total - v_record.free_minutes_used);

  RETURN jsonb_build_object(
    'has_free_minutes', v_remaining > 0,
    'free_minutes_remaining', v_remaining,
    'free_minutes_total', v_record.free_minutes_total,
    'free_minutes_used', v_record.free_minutes_used,
    'next_reset_date', v_record.next_reset_date
  );
END;
$$;

-- Function to consume a free minute
CREATE OR REPLACE FUNCTION public.use_men_free_minute(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_record RECORD;
  v_remaining integer;
BEGIN
  SELECT * INTO v_record
  FROM men_free_chat_allowance
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_record IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No free allowance record');
  END IF;

  -- Reset if due
  IF CURRENT_DATE >= v_record.next_reset_date THEN
    UPDATE men_free_chat_allowance
    SET free_minutes_used = 0,
        last_reset_date = CURRENT_DATE,
        next_reset_date = (CURRENT_DATE + INTERVAL '15 days')::date,
        updated_at = now()
    WHERE user_id = p_user_id
    RETURNING * INTO v_record;
  END IF;

  v_remaining := v_record.free_minutes_total - v_record.free_minutes_used;

  IF v_remaining <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'No free minutes remaining', 'remaining', 0);
  END IF;

  -- Use one minute
  UPDATE men_free_chat_allowance
  SET free_minutes_used = free_minutes_used + 1,
      updated_at = now()
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'remaining', v_remaining - 1,
    'next_reset_date', v_record.next_reset_date
  );
END;
$$;

-- Trigger for updated_at
CREATE TRIGGER update_men_free_chat_allowance_updated_at
BEFORE UPDATE ON public.men_free_chat_allowance
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();
