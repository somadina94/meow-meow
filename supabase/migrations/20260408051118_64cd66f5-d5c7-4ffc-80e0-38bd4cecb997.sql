
-- Direct test without exception catch
DO $$
DECLARE
  v_session record;
  v_pricing record;
  v_minutes numeric;
  v_seconds integer;
  v_man_charge numeric;
  v_woman_earn numeric;
  v_rate numeric;
  v_man_wallet_id uuid;
  v_man_balance numeric;
BEGIN
  SELECT * INTO v_session FROM public.video_call_sessions
  WHERE call_id = 'call_0b933372-7f04-4397-9aae-0e8be4730702_04cad57a-2647-457e-beb4-9a5c60fbbe44_1775624407648'
  AND status IN ('completed', 'ended');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Session not found!';
  END IF;

  RAISE NOTICE 'Found session: status=%, started=%, ended=%', v_session.status, v_session.started_at, v_session.ended_at;

  v_seconds := EXTRACT(EPOCH FROM (v_session.ended_at - v_session.started_at))::integer;
  v_minutes := v_seconds / 60.0;
  RAISE NOTICE 'Duration: % seconds, % minutes', v_seconds, v_minutes;

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_rate := v_pricing.video_rate_per_minute;
  v_man_charge := ROUND(v_minutes * v_rate, 2);
  v_woman_earn := ROUND(v_man_charge / 2.0, 2);
  RAISE NOTICE 'Rate: %, Charge: %, Earn: %', v_rate, v_man_charge, v_woman_earn;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance
  FROM public.wallets WHERE user_id = v_session.man_user_id FOR UPDATE;
  RAISE NOTICE 'Man wallet: %, balance: %', v_man_wallet_id, v_man_balance;

  -- Actually debit
  UPDATE public.wallets SET balance = GREATEST(balance - v_man_charge, 0), updated_at = now()
  WHERE id = v_man_wallet_id;
  RAISE NOTICE 'Man debited!';

  -- Insert wallet transaction
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, amount, description,
    balance_after, idempotency_key, status, duration_seconds, rate_per_minute
  ) VALUES (
    v_man_wallet_id, v_session.man_user_id, 'debit', 'video_call_charge', v_man_charge,
    'Video Call: ' || ROUND(v_minutes, 1) || ' min @ ₹' || v_rate || '/min',
    (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id),
    'video_call:test_manual', 'completed', v_seconds, v_rate
  );
  RAISE NOTICE 'Wallet transaction inserted!';

  -- Update session totals
  UPDATE public.video_call_sessions SET
    total_minutes = v_minutes,
    total_earned = v_woman_earn,
    rate_per_minute = v_rate
  WHERE call_id = 'call_0b933372-7f04-4397-9aae-0e8be4730702_04cad57a-2647-457e-beb4-9a5c60fbbe44_1775624407648';
  RAISE NOTICE 'Session updated!';

  -- Credit woman
  DECLARE
    v_woman_wallet_id uuid;
  BEGIN
    SELECT id INTO v_woman_wallet_id FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_woman_earn, updated_at = now()
      WHERE id = v_woman_wallet_id;
      
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description,
        balance_after, idempotency_key, status, duration_seconds, rate_per_minute
      ) VALUES (
        v_woman_wallet_id, v_session.woman_user_id, 'credit', 'video_call_earning', v_woman_earn,
        'Video Call Earning: ' || ROUND(v_minutes, 1) || ' min @ ₹' || ROUND(v_rate/2.0, 2) || '/min',
        (SELECT balance FROM public.wallets WHERE id = v_woman_wallet_id),
        'video_call_earn:test_manual', 'completed', v_seconds, ROUND(v_rate/2.0, 2)
      );
      RAISE NOTICE 'Woman credited!';
    END IF;
  END;

  -- Women earnings
  INSERT INTO public.women_earnings (user_id, amount, earning_type, description, rate_per_minute, minutes_billed)
  VALUES (v_session.woman_user_id, v_woman_earn, 'video_call',
    'Video call earning: ' || ROUND(v_minutes, 1) || ' min', ROUND(v_rate/2.0, 2), v_minutes);
  RAISE NOTICE 'All done!';
END;
$$;
