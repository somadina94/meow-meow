-- =====================================================================
-- SINGLE SOURCE OF TRUTH MIGRATION
-- Canonical store: public.wallet_transactions (+ public.wallets for balance)
-- =====================================================================

-- STEP 1: Drop duplicate function overloads causing PGRST203
DROP FUNCTION IF EXISTS public.process_video_billing(p_session_id uuid, p_minutes integer);
DROP FUNCTION IF EXISTS public.process_video_billing(p_session_id uuid, p_minutes numeric);
DROP FUNCTION IF EXISTS public.process_wallet_transaction(p_user_id uuid, p_amount numeric, p_type text, p_description text, p_reference_id text);
DROP FUNCTION IF EXISTS public.process_wallet_transaction(p_user_id uuid, p_amount numeric, p_type text, p_description text, p_reference_id uuid, p_idempotency_key text);

-- STEP 2: Backfill wallet_transactions from legacy stores
-- 2a. Backfill from platform_ledger
INSERT INTO public.wallet_transactions (
  user_id, type, transaction_type, amount, description, session_id,
  balance_after, idempotency_key, status, duration_seconds, rate_per_minute, created_at
)
SELECT
  pl.user_id,
  CASE WHEN pl.debit > 0 THEN 'debit' ELSE 'credit' END,
  pl.entry_type,
  CASE WHEN pl.debit > 0 THEN pl.debit ELSE pl.credit END,
  COALESCE(pl.description, pl.entry_type),
  CASE WHEN pl.session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       THEN pl.session_id::uuid ELSE NULL END,
  pl.balance_after,
  COALESCE(pl.idempotency_key, 'backfill_pl_' || pl.id::text),
  'completed',
  COALESCE((pl.duration_minutes * 60)::integer, 0),
  pl.rate_per_unit,
  COALESCE(pl.created_at_ist, now())
FROM public.platform_ledger pl
WHERE NOT EXISTS (
  SELECT 1 FROM public.wallet_transactions wt
  WHERE wt.idempotency_key = COALESCE(pl.idempotency_key, 'backfill_pl_' || pl.id::text)
);

-- 2b. Backfill from ledger_transactions
INSERT INTO public.wallet_transactions (
  user_id, type, transaction_type, amount, description, session_id,
  idempotency_key, status, duration_seconds, rate_per_minute, created_at
)
SELECT
  lt.user_id,
  CASE WHEN lt.debit > 0 THEN 'debit' ELSE 'credit' END,
  lt.transaction_type,
  CASE WHEN lt.debit > 0 THEN lt.debit ELSE lt.credit END,
  COALESCE(lt.description, lt.transaction_type),
  lt.session_id,
  COALESCE(lt.reference_id, 'backfill_lt_' || lt.id::text),
  'completed',
  COALESCE(lt.duration_seconds, 0),
  lt.rate_per_minute,
  lt.created_at
FROM public.ledger_transactions lt
WHERE NOT EXISTS (
  SELECT 1 FROM public.wallet_transactions wt
  WHERE wt.idempotency_key = COALESCE(lt.reference_id, 'backfill_lt_' || lt.id::text)
);

-- 2c. Backfill from women_earnings
INSERT INTO public.wallet_transactions (
  user_id, type, transaction_type, amount, description, session_id,
  idempotency_key, status, rate_per_minute, created_at
)
SELECT
  we.user_id,
  'credit',
  COALESCE(we.earning_type, 'earning'),
  we.amount,
  COALESCE(we.description, we.earning_type),
  COALESCE(we.chat_session_id, we.video_session_id, we.private_call_id),
  COALESCE(we.idempotency_key, 'backfill_we_' || we.id::text),
  'completed',
  we.rate_per_minute,
  we.created_at
FROM public.women_earnings we
WHERE NOT EXISTS (
  SELECT 1 FROM public.wallet_transactions wt
  WHERE wt.idempotency_key = COALESCE(we.idempotency_key, 'backfill_we_' || we.id::text)
);

-- 2d. Backfill from wallet_recharges
INSERT INTO public.wallet_transactions (
  user_id, type, transaction_type, amount, description,
  idempotency_key, status, created_at
)
SELECT
  wr.user_id, 'credit', 'recharge', wr.amount,
  COALESCE(wr.description, 'Wallet recharge via ' || COALESCE(wr.payment_gateway, 'gateway')),
  'recharge_backfill_' || wr.id::text,
  'completed',
  wr.created_at
FROM public.wallet_recharges wr
WHERE wr.status IN ('success','completed')
  AND NOT EXISTS (
    SELECT 1 FROM public.wallet_transactions wt
    WHERE wt.user_id = wr.user_id
      AND wt.transaction_type = 'recharge'
      AND wt.amount = wr.amount
      AND ABS(EXTRACT(EPOCH FROM (wt.created_at - wr.created_at))) < 60
  );

-- STEP 3: Reconcile every wallet balance to canonical SUM
UPDATE public.wallets w
SET balance = COALESCE(c.computed, 0), updated_at = now()
FROM (
  SELECT user_id,
         SUM(CASE WHEN type='credit' THEN amount ELSE -amount END) AS computed
  FROM public.wallet_transactions
  WHERE status = 'completed'
  GROUP BY user_id
) c
WHERE w.user_id = c.user_id;

-- STEP 4: Rewrite billing RPCs (canonical only)

-- 4a. Chat billing (no is_indian gate)
CREATE OR REPLACE FUNCTION public.process_chat_billing(p_session_id uuid, p_minutes numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_session RECORD; v_pricing RECORD;
  v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_charge numeric; v_earn numeric;
  v_is_super boolean; v_lock_check integer;
  v_idem_key text; v_idem_key_w text; v_minute_bucket bigint;
BEGIN
  SELECT * INTO v_session FROM public.active_chat_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Session not found'); END IF;

  UPDATE public.active_chat_sessions SET last_activity_at = now()
  WHERE id = p_session_id AND last_activity_at = v_session.last_activity_at;
  GET DIAGNOSTICS v_lock_check = ROW_COUNT;
  IF v_lock_check = 0 THEN RETURN jsonb_build_object('success', true, 'duplicate_skipped', true); END IF;

  v_minute_bucket := floor(extract(epoch from now()) / 60)::bigint;
  v_idem_key   := 'chat:' || p_session_id::text || ':' || v_minute_bucket::text;
  v_idem_key_w := 'chat_earn:' || p_session_id::text || ':' || v_minute_bucket::text;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
  END IF;

  v_is_super := public.should_bypass_balance(v_session.man_user_id);
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'No active pricing'); END IF;

  v_charge := ROUND(p_minutes * v_pricing.rate_per_minute, 2);
  v_earn   := ROUND(v_charge / 2.0, 2);

  IF v_is_super THEN
    UPDATE public.active_chat_sessions SET total_minutes = total_minutes + p_minutes WHERE id = p_session_id;
    RETURN jsonb_build_object('success', true, 'super_user', true, 'charged', 0, 'earned', 0);
  END IF;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance
  FROM public.wallets WHERE user_id = v_session.man_user_id FOR UPDATE;
  IF v_man_balance IS NULL OR v_man_balance < v_charge THEN
    UPDATE public.active_chat_sessions SET status='ended', ended_at=now(), end_reason='insufficient_funds' WHERE id=p_session_id;
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'session_ended', true);
  END IF;

  UPDATE public.wallets SET balance = balance - v_charge, updated_at = now() WHERE id = v_man_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, amount, description, session_id,
    balance_after, idempotency_key, status, duration_seconds, rate_per_minute
  ) VALUES (
    v_man_wallet_id, v_session.man_user_id, 'debit', 'chat_charge', v_charge,
    'Chat: ' || ROUND(p_minutes,1) || ' min @ ₹' || v_pricing.rate_per_minute || '/min',
    p_session_id, (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id),
    v_idem_key, 'completed', ROUND(p_minutes * 60)::int, v_pricing.rate_per_minute
  );

  IF v_earn > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_earn, updated_at = now() WHERE id = v_woman_wallet_id;
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, session_id,
        balance_after, idempotency_key, status, duration_seconds, rate_per_minute
      ) VALUES (
        v_woman_wallet_id, v_session.woman_user_id, 'credit', 'chat_earning', v_earn,
        'Chat Earning: ' || ROUND(p_minutes,1) || ' min (½ of ₹' || v_charge || ')',
        p_session_id, (SELECT balance FROM public.wallets WHERE id = v_woman_wallet_id),
        v_idem_key_w, 'completed', ROUND(p_minutes * 60)::int, ROUND(v_pricing.rate_per_minute/2.0,2)
      );
    END IF;
  END IF;

  UPDATE public.active_chat_sessions
  SET total_minutes = total_minutes + p_minutes, total_earned = total_earned + v_earn
  WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true, 'charged', v_charge, 'earned', v_earn, 'idempotency_key', v_idem_key);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $function$;

-- 4b. Audio billing
CREATE OR REPLACE FUNCTION public.process_audio_billing(
  p_session_id text, p_man_id uuid, p_woman_id uuid, p_minutes numeric, p_idempotency text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_pricing record; v_man_charge numeric; v_woman_earn numeric;
  v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_idem text; v_idem_w text; v_session_uuid uuid;
BEGIN
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_man_charge := ROUND(p_minutes * COALESCE(v_pricing.audio_rate_per_minute, 6.00), 2);
  v_woman_earn := ROUND(p_minutes * COALESCE(v_pricing.audio_women_earning_rate, 3.00), 2);
  v_idem   := COALESCE(p_idempotency, 'audio:' || p_session_id || ':' || ROUND(p_minutes,4)::text);
  v_idem_w := v_idem || ':earn';
  v_session_uuid := CASE WHEN p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN p_session_id::uuid ELSE NULL END;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_skipped'); END IF;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
  IF COALESCE(v_man_balance, 0) < v_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance', 'session_ended', true); END IF;

  UPDATE public.wallets SET balance = balance - v_man_charge, updated_at = NOW()
  WHERE id = v_man_wallet_id RETURNING balance INTO v_man_balance;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, amount, description, session_id,
    balance_after, idempotency_key, status, duration_seconds, rate_per_minute
  ) VALUES (
    v_man_wallet_id, p_man_id, 'debit', 'audio_call_charge', v_man_charge,
    'Audio Call: ' || ROUND(p_minutes,1) || ' min @ ₹' || COALESCE(v_pricing.audio_rate_per_minute,6.00) || '/min',
    v_session_uuid, v_man_balance, v_idem, 'completed',
    ROUND(p_minutes*60)::int, COALESCE(v_pricing.audio_rate_per_minute,6.00)
  );

  SELECT id, balance INTO v_woman_wallet_id, v_woman_balance FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
  IF v_woman_wallet_id IS NOT NULL AND v_woman_earn > 0 THEN
    UPDATE public.wallets SET balance = balance + v_woman_earn, updated_at = NOW()
    WHERE id = v_woman_wallet_id RETURNING balance INTO v_woman_balance;
    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, amount, description, session_id,
      balance_after, idempotency_key, status, duration_seconds, rate_per_minute
    ) VALUES (
      v_woman_wallet_id, p_woman_id, 'credit', 'audio_call_earning', v_woman_earn,
      'Audio Call Earning: ' || ROUND(p_minutes,1) || ' min @ ₹' || COALESCE(v_pricing.audio_women_earning_rate,3.00) || '/min',
      v_session_uuid, v_woman_balance, v_idem_w, 'completed',
      ROUND(p_minutes*60)::int, COALESCE(v_pricing.audio_women_earning_rate,3.00)
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'man_charged', v_man_charge, 'woman_earned', v_woman_earn);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $function$;

-- 4c. Group billing v2
CREATE OR REPLACE FUNCTION public.process_group_billing_v2(
  p_group_id text, p_session_id text, p_host_id uuid, p_man_ids uuid[],
  p_minutes numeric, p_idempotency text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_pricing record; v_rate_per_man numeric; v_earn_per_man numeric;
  v_man_id uuid; v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_total_earned numeric := 0; v_active_count int := 0;
  v_removed_men uuid[] := '{}'; v_idem text; v_idem_man text; v_idem_woman text;
  v_session_uuid uuid;
BEGIN
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_rate_per_man := ROUND(p_minutes * COALESCE(v_pricing.group_call_rate_per_minute, 4.00), 2);
  v_earn_per_man := ROUND(p_minutes * COALESCE(v_pricing.group_call_women_earning_rate, 0.50), 2);
  v_idem := COALESCE(p_idempotency, 'group:' || p_session_id || ':' || array_length(p_man_ids,1) || ':' || ROUND(p_minutes,4)::text);
  v_session_uuid := CASE WHEN p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN p_session_id::uuid ELSE NULL END;

  FOREACH v_man_id IN ARRAY p_man_ids LOOP
    v_idem_man := v_idem || ':man:' || v_man_id::text;
    IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_man) THEN CONTINUE; END IF;

    SELECT id, balance INTO v_man_wallet_id, v_man_balance FROM public.wallets WHERE user_id = v_man_id FOR UPDATE;
    IF v_man_wallet_id IS NULL OR COALESCE(v_man_balance,0) < v_rate_per_man THEN
      v_removed_men := array_append(v_removed_men, v_man_id); CONTINUE; END IF;

    UPDATE public.wallets SET balance = balance - v_rate_per_man, updated_at = NOW()
    WHERE id = v_man_wallet_id RETURNING balance INTO v_man_balance;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, amount, description, session_id,
      balance_after, idempotency_key, status, duration_seconds, rate_per_minute
    ) VALUES (
      v_man_wallet_id, v_man_id, 'debit', 'group_call_charge', v_rate_per_man,
      'Group Call: ' || ROUND(p_minutes,1) || ' min @ ₹' || COALESCE(v_pricing.group_call_rate_per_minute,4.00) || '/min',
      v_session_uuid, v_man_balance, v_idem_man, 'completed',
      ROUND(p_minutes*60)::int, COALESCE(v_pricing.group_call_rate_per_minute,4.00)
    );
    v_total_earned := v_total_earned + v_earn_per_man;
    v_active_count := v_active_count + 1;
  END LOOP;

  IF v_total_earned > 0 THEN
    v_idem_woman := v_idem || ':host:' || p_host_id::text;
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance FROM public.wallets WHERE user_id = p_host_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_woman) THEN
      UPDATE public.wallets SET balance = balance + v_total_earned, updated_at = NOW()
      WHERE id = v_woman_wallet_id RETURNING balance INTO v_woman_balance;
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, session_id,
        balance_after, idempotency_key, status, duration_seconds, rate_per_minute
      ) VALUES (
        v_woman_wallet_id, p_host_id, 'credit', 'group_call_earning', v_total_earned,
        'Group Call Earning: ' || ROUND(p_minutes,1) || ' min × ' || v_active_count || ' men',
        v_session_uuid, v_woman_balance, v_idem_woman, 'completed',
        ROUND(p_minutes*60)::int, COALESCE(v_pricing.group_call_women_earning_rate,0.50)
      );
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'active_count', v_active_count,
    'host_earned', v_total_earned, 'removed_men', v_removed_men);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $function$;

-- 4d. Gift transaction
CREATE OR REPLACE FUNCTION public.process_gift_transaction(
  p_sender_id uuid, p_receiver_id uuid, p_gift_id uuid, p_message text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_gift RECORD; v_wallet_id uuid; v_balance numeric; v_new_balance numeric;
  v_transaction_id uuid; v_gift_transaction_id uuid; v_is_super boolean;
  v_women_share numeric; v_woman_wallet_id uuid; v_woman_balance numeric;
  v_idem_man text; v_idem_woman text;
BEGIN
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Gift not found'); END IF;

  v_is_super := public.should_bypass_balance(p_sender_id);
  v_women_share := ROUND(v_gift.price * 0.5, 2);

  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Wallet not found'); END IF;
  IF NOT v_is_super AND v_balance < v_gift.price THEN RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance'); END IF;

  v_new_balance := CASE WHEN v_is_super THEN v_balance ELSE v_balance - v_gift.price END;
  v_idem_man   := 'gift:' || p_sender_id::text || ':' || p_gift_id::text || ':' || extract(epoch from now())::bigint::text;
  v_idem_woman := v_idem_man || ':earn';

  UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, amount, description, balance_after, idempotency_key, status
  ) VALUES (
    v_wallet_id, p_sender_id, 'debit', 'gift_charge', v_gift.price,
    'Gift: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_gift.price,
    v_new_balance, v_idem_man, 'completed'
  ) RETURNING id INTO v_transaction_id;

  IF v_women_share > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance FROM public.wallets WHERE user_id = p_receiver_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL THEN
      v_woman_balance := v_woman_balance + v_women_share;
      UPDATE public.wallets SET balance = v_woman_balance, updated_at = now() WHERE id = v_woman_wallet_id;
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, balance_after, idempotency_key, status
      ) VALUES (
        v_woman_wallet_id, p_receiver_id, 'credit', 'gift_earning', v_women_share,
        'Gift Received: ' || v_gift.emoji || ' ' || v_gift.name || ' — ₹' || v_women_share || ' (50% of ₹' || v_gift.price || ')',
        v_woman_balance, v_idem_woman, 'completed'
      );
    END IF;
  END IF;

  INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
  VALUES (p_sender_id, p_receiver_id, p_gift_id, v_gift.price, v_gift.currency, p_message, 'completed')
  RETURNING id INTO v_gift_transaction_id;

  RETURN jsonb_build_object(
    'success', true, 'gift_transaction_id', v_gift_transaction_id,
    'wallet_transaction_id', v_transaction_id, 'previous_balance', v_balance,
    'new_balance', v_new_balance, 'gift_name', v_gift.name, 'gift_emoji', v_gift.emoji,
    'gift_price', v_gift.price, 'women_share', v_women_share, 'super_user_bypass', v_is_super
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $function$;

-- 4e. Recharge
CREATE OR REPLACE FUNCTION public.ledger_recharge(
  p_user_id uuid, p_amount numeric, p_gateway text DEFAULT 'razorpay',
  p_gateway_txn_id text DEFAULT NULL, p_description text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_wallet_id uuid; v_old_balance numeric; v_new_balance numeric; v_idem text;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive'); END IF;
  v_idem := 'recharge:' || COALESCE(p_gateway_txn_id, p_user_id::text || ':' || extract(epoch from now())::bigint::text);
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_skipped'); END IF;

  SELECT id, balance INTO v_wallet_id, v_old_balance FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO public.wallets (user_id, balance, currency) VALUES (p_user_id, 0, 'INR')
    RETURNING id, balance INTO v_wallet_id, v_old_balance;
  END IF;
  v_new_balance := v_old_balance + p_amount;

  UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, balance_after, status, idempotency_key)
  VALUES (p_user_id, 'credit', 'recharge', p_amount,
          COALESCE(p_description, 'Wallet recharge via ' || p_gateway), v_new_balance, 'completed', v_idem);

  INSERT INTO public.wallet_recharges (user_id, amount, payment_gateway, gateway_transaction_id, status)
  VALUES (p_user_id, p_amount, p_gateway, p_gateway_txn_id, 'success');

  RETURN jsonb_build_object('success', true, 'previous_balance', v_old_balance, 'new_balance', v_new_balance, 'amount_recharged', p_amount);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $function$;

-- 4f. Withdrawal
CREATE OR REPLACE FUNCTION public.ledger_withdrawal(
  p_user_id uuid, p_amount numeric, p_payment_method text DEFAULT 'upi', p_payment_details jsonb DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_wallet_id uuid; v_balance numeric; v_pending numeric := 0; v_available numeric;
  v_min_withdrawal numeric := 100; v_request_id uuid;
  v_fee_rate numeric := 0.05; v_fee_amount numeric; v_net_payout numeric;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive'); END IF;

  SELECT min_withdrawal_balance INTO v_min_withdrawal FROM public.chat_pricing WHERE is_active=true ORDER BY updated_at DESC LIMIT 1;
  v_min_withdrawal := COALESCE(v_min_withdrawal, 100);

  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Wallet not found'); END IF;

  SELECT COALESCE(SUM(amount),0) INTO v_pending FROM public.withdrawal_requests
  WHERE user_id = p_user_id AND status = 'pending';
  v_available := v_balance - v_pending;

  IF p_amount < v_min_withdrawal THEN RETURN jsonb_build_object('success', false, 'error', 'Minimum withdrawal is ₹' || v_min_withdrawal); END IF;
  IF p_amount > v_available THEN RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance. Available: ₹' || v_available); END IF;

  v_fee_amount := ROUND(p_amount * v_fee_rate, 2);
  v_net_payout := p_amount - v_fee_amount;

  UPDATE public.wallets SET balance = balance - p_amount, updated_at = now()
  WHERE id = v_wallet_id AND balance >= p_amount;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance for withdrawal');
  END IF;

  INSERT INTO public.withdrawal_requests (user_id, amount, payment_method, payment_details, status)
  VALUES (p_user_id, v_net_payout, p_payment_method, p_payment_details, 'pending')
  RETURNING id INTO v_request_id;

  INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, balance_after, status, idempotency_key, reference_id)
  VALUES (p_user_id, 'debit', 'withdrawal', v_net_payout,
          'Withdrawal payout (₹' || p_amount || ' − 5% fee ₹' || v_fee_amount || ')',
          v_balance - p_amount, 'completed', 'withdrawal:' || v_request_id::text, v_request_id::text);

  INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, balance_after, status, idempotency_key, reference_id)
  VALUES (p_user_id, 'debit', 'withdrawal_fee', v_fee_amount,
          'Withdrawal platform fee (5% of ₹' || p_amount || ')',
          v_balance - p_amount, 'completed', 'withdrawal_fee:' || v_request_id::text, v_request_id::text);

  INSERT INTO public.admin_revenue_transactions (amount, transaction_type, woman_user_id, description)
  VALUES (v_fee_amount, 'withdrawal_fee', p_user_id, 'Withdrawal fee 5% on ₹' || p_amount);

  RETURN jsonb_build_object('success', true, 'request_id', v_request_id,
    'requested_amount', p_amount, 'fee_percent', 5, 'fee_amount', v_fee_amount,
    'net_payout', v_net_payout, 'available_balance', v_available - p_amount);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $function$;

-- STEP 5: Reconcile balances after rewrites
UPDATE public.wallets w
SET balance = COALESCE(c.computed, 0), updated_at = now()
FROM (
  SELECT user_id,
         SUM(CASE WHEN type='credit' THEN amount ELSE -amount END) AS computed
  FROM public.wallet_transactions
  WHERE status = 'completed'
  GROUP BY user_id
) c
WHERE w.user_id = c.user_id;

-- STEP 6: Reconcile helper now uses canonical only
CREATE OR REPLACE FUNCTION public.reconcile_wallet_balance(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_current numeric; v_computed numeric; v_diff numeric;
BEGIN
  SELECT balance INTO v_current FROM public.wallets WHERE user_id = p_user_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Wallet not found'); END IF;
  SELECT COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE -amount END), 0)
  INTO v_computed FROM public.wallet_transactions
  WHERE user_id = p_user_id AND status = 'completed';
  v_diff := v_current - v_computed;
  RETURN jsonb_build_object('success', true, 'user_id', p_user_id,
    'current_balance', v_current, 'computed_balance', v_computed,
    'difference', v_diff, 'in_sync', (ABS(v_diff) < 0.01));
END; $function$;