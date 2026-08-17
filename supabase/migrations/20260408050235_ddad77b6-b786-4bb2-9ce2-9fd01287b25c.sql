
-- 1) Create the safe_ledger_insert utility function
CREATE OR REPLACE FUNCTION public.safe_ledger_insert(
  p_user_id uuid,
  p_session_id uuid,
  p_entry_type text,
  p_debit numeric,
  p_credit numeric,
  p_rate numeric,
  p_duration_seconds integer,
  p_counterparty_id uuid,
  p_ref_key text,
  p_description text,
  p_timestamp timestamptz DEFAULT now()
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender text;
  v_balance numeric;
  v_ist_time timestamptz;
BEGIN
  -- Idempotency guard
  IF p_ref_key IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.platform_ledger WHERE idempotency_key = p_ref_key
  ) THEN
    RETURN;
  END IF;

  SELECT COALESCE(p.gender, 'male') INTO v_gender FROM public.profiles p WHERE p.user_id = p_user_id;
  SELECT COALESCE(w.balance, 0) INTO v_balance FROM public.wallets w WHERE w.user_id = p_user_id;

  v_ist_time := p_timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata' AT TIME ZONE 'UTC';

  INSERT INTO public.platform_ledger (
    user_id, user_gender, entry_type, debit, credit, balance_after,
    session_id, counterparty_id, session_type, duration_minutes, rate_per_unit,
    idempotency_key, description, created_at_ist,
    ist_date, ist_month, ist_year
  ) VALUES (
    p_user_id, v_gender, p_entry_type, p_debit, p_credit, v_balance,
    p_session_id::text, p_counterparty_id, p_entry_type,
    CASE WHEN p_duration_seconds > 0 THEN p_duration_seconds / 60.0 ELSE NULL END,
    p_rate, p_ref_key, p_description, p_timestamp,
    (p_timestamp AT TIME ZONE 'Asia/Kolkata')::date,
    to_char(p_timestamp AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM'),
    EXTRACT(YEAR FROM p_timestamp AT TIME ZONE 'Asia/Kolkata')::integer
  );
EXCEPTION WHEN unique_violation THEN
  -- Idempotency: ignore duplicate
  NULL;
END;
$$;

-- 2) Fix ledger_bill_session: remove is_indian gate, add platform_ledger entries
CREATE OR REPLACE FUNCTION public.ledger_bill_session(
  p_session_id uuid,
  p_session_type text,
  p_man_id uuid,
  p_woman_id uuid,
  p_man_charge numeric,
  p_woman_earn numeric,
  p_minute_number integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_idem_key text;
  v_idem_key_woman text;
  v_man_wallet_id uuid;
  v_man_balance numeric;
  v_woman_wallet uuid;
BEGIN
  v_idem_key := p_session_type || ':' || p_session_id::text || ':min:' || p_minute_number::text;
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'idempotency_key', v_idem_key);
  END IF;

  -- Half-rule validation: women earn exactly 50% of men's charge
  IF ROUND(p_woman_earn, 2) <> ROUND(p_man_charge / 2.0, 2) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Half-rule violation');
  END IF;

  -- Lock and check man's wallet
  SELECT id, balance INTO v_man_wallet_id, v_man_balance FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
  IF v_man_balance IS NULL OR v_man_balance < p_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'balance', COALESCE(v_man_balance, 0), 'required', p_man_charge);
  END IF;

  -- Debit man
  UPDATE public.wallets SET balance = balance - p_man_charge, updated_at = now() WHERE id = v_man_wallet_id;

  INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
  VALUES (p_man_id, 'debit', p_session_type || '_charge', p_man_charge,
    initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_man_charge || '/min',
    p_session_id, (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id), v_idem_key, 'completed',
    60, p_man_charge);

  -- Platform ledger entry for man debit
  PERFORM public.safe_ledger_insert(
    p_man_id, p_session_id, p_session_type || '_charge',
    p_man_charge, 0, p_man_charge, 60, p_woman_id,
    v_idem_key, initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_man_charge || '/min', now()
  );

  -- Credit woman (all users are Indian)
  IF p_woman_earn > 0 THEN
    SELECT id INTO v_woman_wallet FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF v_woman_wallet IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + p_woman_earn, updated_at = now() WHERE id = v_woman_wallet;
    END IF;

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, rate_per_minute, minutes_billed, created_at)
    VALUES (p_woman_id, p_woman_earn, p_session_type,
      initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min (½ of ₹' || p_man_charge || ')',
      p_woman_earn, 1, now());

    v_idem_key_woman := p_session_type || ':' || p_session_id::text || ':earn:' || p_minute_number::text;
    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
    VALUES (p_woman_id, 'credit', p_session_type || '_earning', p_woman_earn,
      initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min (½ of ₹' || p_man_charge || ')',
      p_session_id, (SELECT balance FROM public.wallets WHERE id = v_woman_wallet), v_idem_key_woman, 'completed',
      60, p_woman_earn);

    -- Platform ledger entry for woman earning
    PERFORM public.safe_ledger_insert(
      p_woman_id, p_session_id, 'earning',
      0, p_woman_earn, p_woman_earn, 60, p_man_id,
      v_idem_key_woman, initcap(replace(p_session_type,'_',' ')) || ' earning: min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min', now()
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', p_man_charge,
    'earned', p_woman_earn,
    'minute_number', p_minute_number, 'idempotency_key', v_idem_key);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 3) Fix process_gift_transaction: remove is_indian gate, add platform_ledger entries
CREATE OR REPLACE FUNCTION public.process_gift_transaction(
  p_sender_id uuid,
  p_receiver_id uuid,
  p_gift_id uuid,
  p_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gift RECORD;
  v_wallet_id uuid;
  v_balance numeric;
  v_new_balance numeric;
  v_transaction_id uuid;
  v_gift_transaction_id uuid;
  v_is_super_user boolean;
  v_women_share numeric;
  v_woman_wallet_id uuid;
  v_woman_balance numeric;
  v_ref_key text;
BEGIN
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gift not found or inactive');
  END IF;

  v_is_super_user := public.should_bypass_balance(p_sender_id);

  -- All users are Indian — always 50% share
  v_women_share := ROUND(v_gift.price * 0.5, 2);

  -- Lock sender wallet
  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  IF v_is_super_user THEN
    v_new_balance := v_balance;
  ELSE
    v_new_balance := v_balance - v_gift.price;
  END IF;

  -- Debit men wallet
  UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;

  -- Men debit wallet_transaction
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, amount, description, balance_after, status
  ) VALUES (
    v_wallet_id, p_sender_id, 'debit', 'gift_charge', v_gift.price,
    'Gift: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_gift.price || ' (100% deducted)',
    v_new_balance, 'completed'
  ) RETURNING id INTO v_transaction_id;

  -- Platform ledger for man's gift debit
  v_ref_key := 'gift:' || v_transaction_id::text;
  PERFORM public.safe_ledger_insert(
    p_sender_id, NULL, 'gift_charge',
    v_gift.price, 0, v_gift.price, 0, p_receiver_id,
    v_ref_key, 'Gift: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_gift.price, now()
  );

  -- Credit women wallet + wallet_transaction
  IF v_women_share > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets WHERE user_id = p_receiver_id FOR UPDATE;

    IF v_woman_wallet_id IS NOT NULL THEN
      v_woman_balance := v_woman_balance + v_women_share;
      UPDATE public.wallets SET balance = v_woman_balance, updated_at = now() WHERE id = v_woman_wallet_id;

      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, balance_after, status
      ) VALUES (
        v_woman_wallet_id, p_receiver_id, 'credit', 'gift_earning', v_women_share,
        'Gift Received: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_women_share || ' (50% of ₹' || v_gift.price || ')',
        v_woman_balance, 'completed'
      );
    END IF;

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, rate_per_minute, minutes_billed)
    VALUES (p_receiver_id, v_women_share, 'gift', 
      'Gift received: ' || v_gift.name || ' (50% of ₹' || v_gift.price || ')',
      NULL, NULL);

    -- Platform ledger for woman's gift earning
    v_ref_key := 'gift_earn:' || v_transaction_id::text;
    PERFORM public.safe_ledger_insert(
      p_receiver_id, NULL, 'gift_earning',
      0, v_women_share, v_women_share, 0, p_sender_id,
      v_ref_key, 'Gift Received: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_women_share || ' (50%)', now()
    );
  END IF;

  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, p_receiver_id, p_gift_id, v_gift.price, v_gift.currency, p_message, 'completed')
  RETURNING id INTO v_gift_transaction_id;

  RETURN jsonb_build_object(
    'success', true, 'gift_transaction_id', v_gift_transaction_id,
    'wallet_transaction_id', v_transaction_id, 'previous_balance', v_balance,
    'new_balance', v_new_balance, 'gift_name', v_gift.name, 'gift_emoji', v_gift.emoji,
    'gift_price', v_gift.price, 'women_share', v_women_share,
    'super_user_bypass', v_is_super_user
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
