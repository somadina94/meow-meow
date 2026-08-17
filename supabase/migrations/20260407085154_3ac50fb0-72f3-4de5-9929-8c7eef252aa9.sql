-- Add call_type column to video_call_sessions
ALTER TABLE public.video_call_sessions
  ADD COLUMN IF NOT EXISTS call_type text NOT NULL DEFAULT 'video';

-- Add check constraint for call_type
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'video_call_sessions_call_type_check'
  ) THEN
    ALTER TABLE public.video_call_sessions
      ADD CONSTRAINT video_call_sessions_call_type_check
      CHECK (call_type IN ('audio', 'video'));
  END IF;
END $$;

-- Create or replace the idempotent call billing function
CREATE OR REPLACE FUNCTION public.process_call_billing(
  p_call_id   text,
  p_call_type text DEFAULT 'video'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session       record;
  v_pricing       record;
  v_minutes       numeric;
  v_man_charge    numeric;
  v_woman_earn    numeric;
  v_rate          numeric;
  v_w_rate        numeric;
BEGIN
  -- Get the completed session
  SELECT * INTO v_session
  FROM public.video_call_sessions
  WHERE call_id = p_call_id AND status = 'completed';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Session not found or not completed');
  END IF;

  -- Idempotency: if already billed, return existing
  IF v_session.total_earned > 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_billed', true,
      'total_minutes', v_session.total_minutes,
      'man_charged', v_session.total_minutes * v_session.rate_per_minute,
      'woman_earned', v_session.total_earned
    );
  END IF;

  -- Validate timestamps
  IF v_session.started_at IS NULL OR v_session.ended_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Missing start or end timestamp');
  END IF;

  -- Exact duration in minutes
  v_minutes := EXTRACT(EPOCH FROM (v_session.ended_at - v_session.started_at)) / 60.0;

  IF v_minutes <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid call duration');
  END IF;

  -- Get pricing
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active pricing found');
  END IF;

  IF p_call_type = 'audio' THEN
    v_rate   := v_pricing.audio_rate_per_minute;
    v_w_rate := v_pricing.audio_women_earning_rate;
  ELSE
    v_rate   := v_pricing.video_rate_per_minute;
    v_w_rate := v_pricing.video_women_earning_rate;
  END IF;

  v_man_charge  := ROUND(v_minutes * v_rate, 2);
  v_woman_earn  := ROUND(v_minutes * v_w_rate, 2);

  -- Debit man via ledger
  INSERT INTO public.ledger_transactions
    (user_id, transaction_type, debit, description, reference_id, session_id, counterparty_id, duration_seconds, rate_per_minute)
  VALUES
    (v_session.man_user_id, p_call_type || '_call_charge', v_man_charge,
     initcap(p_call_type) || ' call ' || ROUND(v_minutes, 2) || ' min @ ₹' || v_rate || '/min',
     p_call_id, v_session.id, v_session.woman_user_id,
     EXTRACT(EPOCH FROM (v_session.ended_at - v_session.started_at))::integer, v_rate);

  -- Credit woman via ledger
  INSERT INTO public.ledger_transactions
    (user_id, transaction_type, credit, description, reference_id, session_id, counterparty_id, duration_seconds, rate_per_minute)
  VALUES
    (v_session.woman_user_id, p_call_type || '_call_earning', v_woman_earn,
     initcap(p_call_type) || ' call earnings ' || ROUND(v_minutes, 2) || ' min @ ₹' || v_w_rate || '/min',
     p_call_id, v_session.id, v_session.man_user_id,
     EXTRACT(EPOCH FROM (v_session.ended_at - v_session.started_at))::integer, v_w_rate);

  -- Update session totals
  UPDATE public.video_call_sessions SET
    total_minutes = v_minutes,
    total_earned  = v_woman_earn,
    rate_per_minute = v_rate
  WHERE call_id = p_call_id;

  RETURN jsonb_build_object(
    'success', true,
    'already_billed', false,
    'total_minutes', v_minutes,
    'man_charged', v_man_charge,
    'woman_earned', v_woman_earn
  );
END;
$$;
