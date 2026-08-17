
-- Fix search_path warning
CREATE OR REPLACE FUNCTION public.prevent_direct_wallet_balance_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.balance = OLD.balance THEN RETURN NEW; END IF;
  IF current_setting('role', true) = 'service_role' THEN RETURN NEW; END IF;
  IF current_user IN ('postgres', 'supabase_admin') THEN RETURN NEW; END IF;
  IF session_user IN ('postgres', 'supabase_admin', 'authenticator') THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'Direct wallet balance modification is not allowed. Use the provided payment functions.';
END;
$$;

-- Bill remaining unbilled sessions manually
DO $$
DECLARE
  v_session record;
  v_pricing record;
  v_seconds integer;
  v_minutes numeric;
  v_rate numeric;
  v_man_charge numeric;
  v_woman_earn numeric;
  v_man_wallet_id uuid;
  v_woman_wallet_id uuid;
  v_idem text;
BEGIN
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;

  FOR v_session IN
    SELECT * FROM public.video_call_sessions
    WHERE status IN ('completed', 'ended')
      AND started_at IS NOT NULL AND ended_at IS NOT NULL
      AND (total_minutes = 0 OR total_minutes IS NULL)
  LOOP
    v_seconds := EXTRACT(EPOCH FROM (v_session.ended_at - v_session.started_at))::integer;
    v_minutes := v_seconds / 60.0;
    IF v_minutes <= 0 THEN CONTINUE; END IF;

    v_rate := CASE WHEN COALESCE(v_session.call_type, 'video') = 'audio' 
              THEN v_pricing.audio_rate_per_minute ELSE v_pricing.video_rate_per_minute END;
    v_man_charge := ROUND(v_minutes * v_rate, 2);
    v_woman_earn := ROUND(v_man_charge / 2.0, 2);
    v_idem := COALESCE(v_session.call_type, 'video') || '_call:' || v_session.call_id;

    IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem) THEN CONTINUE; END IF;

    -- Debit man
    SELECT id INTO v_man_wallet_id FROM public.wallets WHERE user_id = v_session.man_user_id FOR UPDATE;
    IF v_man_wallet_id IS NOT NULL THEN
      UPDATE public.wallets SET balance = GREATEST(balance - v_man_charge, 0), updated_at = now() WHERE id = v_man_wallet_id;
      INSERT INTO public.wallet_transactions (wallet_id, user_id, type, transaction_type, amount, description, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
      VALUES (v_man_wallet_id, v_session.man_user_id, 'debit', COALESCE(v_session.call_type,'video') || '_call_charge', v_man_charge,
        initcap(COALESCE(v_session.call_type,'video')) || ' Call: ' || ROUND(v_minutes,1) || ' min @ ₹' || v_rate || '/min',
        (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id), v_idem, 'completed', v_seconds, v_rate);
    END IF;

    -- Credit woman
    SELECT id INTO v_woman_wallet_id FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL AND v_woman_earn > 0 THEN
      UPDATE public.wallets SET balance = balance + v_woman_earn, updated_at = now() WHERE id = v_woman_wallet_id;
      INSERT INTO public.wallet_transactions (wallet_id, user_id, type, transaction_type, amount, description, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
      VALUES (v_woman_wallet_id, v_session.woman_user_id, 'credit', COALESCE(v_session.call_type,'video') || '_call_earning', v_woman_earn,
        initcap(COALESCE(v_session.call_type,'video')) || ' Call Earning: ' || ROUND(v_minutes,1) || ' min',
        (SELECT balance FROM public.wallets WHERE id = v_woman_wallet_id), COALESCE(v_session.call_type,'video') || '_call_earn:' || v_session.call_id, 'completed', v_seconds, ROUND(v_rate/2.0,2));

      INSERT INTO public.women_earnings (user_id, amount, earning_type, description, rate_per_minute, minutes_billed)
      VALUES (v_session.woman_user_id, v_woman_earn, COALESCE(v_session.call_type,'video') || '_call',
        initcap(COALESCE(v_session.call_type,'video')) || ' call earning: ' || ROUND(v_minutes,1) || ' min', ROUND(v_rate/2.0,2), v_minutes);
    END IF;

    UPDATE public.video_call_sessions SET total_minutes = v_minutes, total_earned = v_woman_earn, rate_per_minute = v_rate
    WHERE id = v_session.id;
  END LOOP;
END;
$$;
