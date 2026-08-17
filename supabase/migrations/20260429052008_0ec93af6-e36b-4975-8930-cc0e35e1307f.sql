
DROP FUNCTION IF EXISTS public.ledger_recharge(uuid, numeric, text, text, text, text);

-- ═══════════════════════════════════════════════════════════════════
-- 1. RECHARGE — write only to wallet_transactions
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.ledger_recharge(
  p_user_id uuid,
  p_amount numeric,
  p_gateway text,
  p_gateway_txn_id text DEFAULT NULL,
  p_reference_id text DEFAULT NULL,
  p_description text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet RECORD;
  v_balance_after numeric(12,2);
  v_idem text;
  v_existing_id uuid;
  v_txn_ref text;
  v_desc text;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'amount must be > 0');
  END IF;

  v_txn_ref := COALESCE(NULLIF(p_gateway_txn_id, ''), NULLIF(p_reference_id, ''));
  IF v_txn_ref IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'gateway_txn_id or reference_id is required');
  END IF;

  v_idem := 'recharge|' || p_user_id::text || '|' || v_txn_ref;

  SELECT id INTO v_existing_id FROM public.wallet_transactions
   WHERE idempotency_key = v_idem LIMIT 1;
  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'existing_id', v_existing_id);
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO public.wallets (user_id, gender, balance, currency)
    VALUES (p_user_id, (SELECT gender FROM public.profiles WHERE id = p_user_id), 0, 'INR')
    RETURNING * INTO v_wallet;
  END IF;

  v_balance_after := v_wallet.balance + p_amount;
  UPDATE public.wallets SET balance = v_balance_after, updated_at = now() WHERE id = v_wallet.id;

  v_desc := COALESCE(p_description, 'Wallet recharge — ₹' || p_amount || ' via ' || p_gateway);

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, session_type,
    amount, balance_after, description, reference_id, idempotency_key, status
  ) VALUES (
    v_wallet.id, p_user_id, 'credit', 'recharge', 'wallet',
    p_amount, v_balance_after, v_desc, v_txn_ref, v_idem, 'completed'
  ) ON CONFLICT (idempotency_key) DO NOTHING;

  RETURN jsonb_build_object('success', true, 'balance', v_balance_after, 'amount', p_amount, 'idempotency_key', v_idem);
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 2. BALANCE LOOKUPS
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.men_ledger_balance(p_man_id uuid)
RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT GREATEST(COALESCE(SUM(CASE WHEN type='credit' THEN amount WHEN type='debit' THEN -amount ELSE 0 END), 0), 0)::numeric(12,2)
  FROM public.wallet_transactions WHERE user_id = p_man_id AND status='completed';
$$;

CREATE OR REPLACE FUNCTION public.women_ledger_balance(p_woman_id uuid)
RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT GREATEST(COALESCE(SUM(CASE WHEN type='credit' THEN amount WHEN type='debit' THEN -amount ELSE 0 END), 0), 0)::numeric(12,2)
  FROM public.wallet_transactions WHERE user_id = p_woman_id AND status='completed';
$$;

CREATE OR REPLACE FUNCTION public.get_woman_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_total_earned numeric(12,2); v_paid_out numeric(12,2); v_today numeric(12,2); v_available numeric(12,2);
BEGIN
  SELECT
    COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN type='debit'  AND transaction_type IN ('withdrawal','payout') THEN amount ELSE 0 END), 0)
  INTO v_total_earned, v_paid_out
  FROM public.wallet_transactions WHERE user_id=p_user_id AND status='completed';

  SELECT COALESCE(SUM(CASE WHEN type='credit' THEN amount WHEN type='debit' THEN -amount ELSE 0 END), 0)
  INTO v_available
  FROM public.wallet_transactions WHERE user_id=p_user_id AND status='completed';

  SELECT COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END), 0)
  INTO v_today
  FROM public.wallet_transactions
  WHERE user_id=p_user_id AND status='completed'
    AND created_at >= date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata';

  RETURN jsonb_build_object('available_balance', GREATEST(v_available, 0), 'total_earned', v_total_earned,
    'paid_out', v_paid_out, 'today_earnings', v_today, 'currency', 'INR');
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 3. WOMEN TRANSACTION HISTORY
-- ═══════════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.get_women_transaction_history(uuid);
DROP FUNCTION IF EXISTS public.get_women_transaction_history(uuid, integer);

CREATE OR REPLACE FUNCTION public.get_women_transaction_history(p_user_id uuid, p_limit int DEFAULT 200)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_pricing RECORD;
  v_chat jsonb; v_audio jsonb; v_video jsonb; v_group jsonb; v_gifts jsonb; v_tips jsonb; v_withdrawals jsonb;
  v_summary jsonb;
BEGIN
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active=true ORDER BY updated_at DESC LIMIT 1;

  SELECT jsonb_agg(row_to_json(r) ORDER BY r.created_at DESC) INTO v_chat FROM (
    SELECT id, ROUND(amount,2) amount, description, created_at, ROUND(rate_per_minute,2) rate_per_minute
    FROM public.wallet_transactions
    WHERE user_id=p_user_id AND status='completed' AND type='credit' AND session_type='chat'
    ORDER BY created_at DESC LIMIT p_limit
  ) r;

  SELECT jsonb_agg(row_to_json(r) ORDER BY r.created_at DESC) INTO v_audio FROM (
    SELECT id, ROUND(amount,2) amount, description, created_at, ROUND(rate_per_minute,2) rate_per_minute
    FROM public.wallet_transactions
    WHERE user_id=p_user_id AND status='completed' AND type='credit' AND session_type='audio_call'
    ORDER BY created_at DESC LIMIT p_limit
  ) r;

  SELECT jsonb_agg(row_to_json(r) ORDER BY r.created_at DESC) INTO v_video FROM (
    SELECT id, ROUND(amount,2) amount, description, created_at, ROUND(rate_per_minute,2) rate_per_minute
    FROM public.wallet_transactions
    WHERE user_id=p_user_id AND status='completed' AND type='credit' AND session_type='video_call'
    ORDER BY created_at DESC LIMIT p_limit
  ) r;

  SELECT jsonb_agg(row_to_json(r) ORDER BY r.created_at DESC) INTO v_group FROM (
    SELECT id, ROUND(amount,2) amount, description, created_at
    FROM public.wallet_transactions
    WHERE user_id=p_user_id AND status='completed' AND type='credit' AND session_type='private_group_call'
    ORDER BY created_at DESC LIMIT p_limit
  ) r;

  SELECT jsonb_agg(row_to_json(r) ORDER BY r.created_at DESC) INTO v_gifts FROM (
    SELECT id, ROUND(amount,2) amount, description, created_at
    FROM public.wallet_transactions
    WHERE user_id=p_user_id AND status='completed' AND type='credit' AND session_type='gift'
    ORDER BY created_at DESC LIMIT p_limit
  ) r;

  SELECT jsonb_agg(row_to_json(r) ORDER BY r.created_at DESC) INTO v_tips FROM (
    SELECT id, ROUND(amount,2) amount, description, created_at
    FROM public.wallet_transactions
    WHERE user_id=p_user_id AND status='completed' AND type='credit' AND session_type='tip'
    ORDER BY created_at DESC LIMIT p_limit
  ) r;

  SELECT jsonb_agg(row_to_json(r) ORDER BY r.created_at DESC) INTO v_withdrawals FROM (
    SELECT id, ROUND(amount,2) amount, status, payment_method, created_at, processed_at, rejection_reason
    FROM public.withdrawal_requests WHERE user_id=p_user_id ORDER BY created_at DESC LIMIT p_limit
  ) r;

  SELECT jsonb_build_object(
    'current_balance', COALESCE(w.balance, 0),
    'total_earned',    COALESCE(SUM(CASE WHEN wt.type='credit' THEN wt.amount ELSE 0 END), 0),
    'total_chat_earned',  COALESCE(SUM(CASE WHEN wt.type='credit' AND wt.session_type='chat' THEN wt.amount ELSE 0 END), 0),
    'total_audio_earned', COALESCE(SUM(CASE WHEN wt.type='credit' AND wt.session_type='audio_call' THEN wt.amount ELSE 0 END), 0),
    'total_video_earned', COALESCE(SUM(CASE WHEN wt.type='credit' AND wt.session_type='video_call' THEN wt.amount ELSE 0 END), 0),
    'total_group_earned', COALESCE(SUM(CASE WHEN wt.type='credit' AND wt.session_type='private_group_call' THEN wt.amount ELSE 0 END), 0),
    'total_gift_earned',  COALESCE(SUM(CASE WHEN wt.type='credit' AND wt.session_type='gift' THEN wt.amount ELSE 0 END), 0),
    'total_tip_earned',   COALESCE(SUM(CASE WHEN wt.type='credit' AND wt.session_type='tip' THEN wt.amount ELSE 0 END), 0),
    'total_withdrawn',    COALESCE(SUM(CASE WHEN wt.type='debit' AND wt.transaction_type IN ('withdrawal','payout') THEN wt.amount ELSE 0 END), 0)
  ) INTO v_summary
  FROM public.wallets w
  LEFT JOIN public.wallet_transactions wt ON wt.user_id=w.user_id AND wt.status='completed'
  WHERE w.user_id=p_user_id GROUP BY w.balance;

  RETURN jsonb_build_object(
    'pricing', row_to_json(v_pricing),
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'chat',    COALESCE(v_chat,        '[]'::jsonb),
    'audio',   COALESCE(v_audio,       '[]'::jsonb),
    'video',   COALESCE(v_video,       '[]'::jsonb),
    'group',   COALESCE(v_group,       '[]'::jsonb),
    'gifts',   COALESCE(v_gifts,       '[]'::jsonb),
    'tips',    COALESCE(v_tips,        '[]'::jsonb),
    'withdrawals', COALESCE(v_withdrawals, '[]'::jsonb)
  );
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 4. ADMIN DEDUCT WALLET
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.admin_deduct_wallet(
  p_user_id uuid, p_amount numeric, p_reason text, p_admin_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_wallet RECORD; v_new_balance numeric(12,2); v_idem text;
BEGIN
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Deduction amount must be positive'; END IF;
  SELECT * INTO v_wallet FROM public.wallets WHERE user_id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Wallet not found for user %', p_user_id; END IF;
  IF p_amount > v_wallet.balance THEN
    RAISE EXCEPTION 'Insufficient balance. Current: %, Requested: %', v_wallet.balance, p_amount;
  END IF;

  v_new_balance := v_wallet.balance - p_amount;
  v_idem := 'admin_penalty|' || p_user_id::text || '|' || extract(epoch from now())::bigint;

  UPDATE public.wallets SET balance=v_new_balance, updated_at=now() WHERE id=v_wallet.id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, session_type, amount, balance_after,
    description, reference_id, idempotency_key, status
  ) VALUES (
    v_wallet.id, p_user_id, 'debit', 'admin_penalty', 'admin', p_amount, v_new_balance,
    'Admin penalty: ' || p_reason, 'PENALTY-' || extract(epoch from now())::bigint, v_idem, 'completed'
  );

  INSERT INTO public.notifications (user_id, title, message, type)
  VALUES (p_user_id, 'Wallet Deduction', '₹' || p_amount::text || ' has been deducted from your wallet. Reason: ' || p_reason, 'system');

  INSERT INTO public.audit_logs (admin_id, action, action_type, resource_type, resource_id, details)
  VALUES (p_admin_id, 'Wallet Deduction: ₹' || p_amount::text, 'update', 'wallet', p_user_id::text,
    'Deducted ₹' || p_amount::text || ' from user. Reason: ' || p_reason || '. Previous: ₹' || v_wallet.balance::text || '. New: ₹' || v_new_balance::text);

  RETURN jsonb_build_object('success', true, 'old_balance', v_wallet.balance, 'new_balance', v_new_balance, 'amount', p_amount);
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 5. SAFE LEDGER INSERT — legacy shim now writes to wallet_transactions
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.safe_ledger_insert(
  p_user_id uuid, p_session_id uuid, p_entry_type text, p_debit numeric, p_credit numeric,
  p_rate numeric, p_duration_seconds integer, p_counterparty_id uuid, p_ref_key text,
  p_description text, p_timestamp timestamptz
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_wallet RECORD; v_amount numeric(12,2); v_type text; v_session_type text; v_balance_after numeric(12,2);
BEGIN
  IF p_ref_key IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = p_ref_key
  ) THEN RETURN; END IF;

  v_amount := COALESCE(NULLIF(p_debit,0), p_credit, 0);
  IF v_amount = 0 THEN RETURN; END IF;
  v_type := CASE WHEN COALESCE(p_debit,0) > 0 THEN 'debit' ELSE 'credit' END;

  v_session_type := CASE
    WHEN p_entry_type ILIKE 'chat%'  THEN 'chat'
    WHEN p_entry_type ILIKE 'audio%' THEN 'audio_call'
    WHEN p_entry_type ILIKE 'video%' THEN 'video_call'
    WHEN p_entry_type ILIKE 'group%' THEN 'private_group_call'
    WHEN p_entry_type ILIKE 'gift%'  THEN 'gift'
    WHEN p_entry_type ILIKE 'tip%'   THEN 'tip'
    ELSE 'other' END;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO public.wallets(user_id, gender, balance, currency)
    VALUES (p_user_id, (SELECT gender FROM public.profiles WHERE id=p_user_id), 0, 'INR')
    RETURNING * INTO v_wallet;
  END IF;

  v_balance_after := v_wallet.balance + (CASE WHEN v_type='credit' THEN v_amount ELSE -v_amount END);
  UPDATE public.wallets SET balance=GREATEST(v_balance_after,0), updated_at=now() WHERE id=v_wallet.id;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, session_type, session_id,
    amount, balance_after, duration_seconds, rate_per_minute,
    description, reference_id, idempotency_key, status, created_at
  ) VALUES (
    v_wallet.id, p_user_id, v_type, p_entry_type, v_session_type, p_session_id,
    v_amount, v_balance_after, p_duration_seconds, p_rate,
    p_description, p_ref_key, COALESCE(p_ref_key, gen_random_uuid()::text), 'completed', p_timestamp
  ) ON CONFLICT (idempotency_key) DO NOTHING;
EXCEPTION WHEN unique_violation THEN NULL;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 6. MONTHLY CLOSING
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.run_monthly_closing(p_year int DEFAULT NULL, p_month int DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_year int; v_month int; v_period_start timestamptz; v_period_end timestamptz;
  v_prev_year int; v_prev_month int; v_user RECORD;
  v_opening numeric(12,2); v_credits numeric(12,2); v_debits numeric(12,2);
  v_closing numeric(12,2); v_payout numeric(12,2);
  v_men_done int := 0; v_women_done int := 0;
  v_chat numeric(12,2); v_audio numeric(12,2); v_video numeric(12,2);
  v_group numeric(12,2); v_gift numeric(12,2); v_tip numeric(12,2); v_recharge numeric(12,2);
BEGIN
  v_year  := COALESCE(p_year,  EXTRACT(year  FROM (now() AT TIME ZONE 'Asia/Kolkata' - interval '1 day'))::int);
  v_month := COALESCE(p_month, EXTRACT(month FROM (now() AT TIME ZONE 'Asia/Kolkata' - interval '1 day'))::int);
  v_period_start := make_timestamptz(v_year, v_month, 1, 0, 0, 0, 'Asia/Kolkata');
  v_period_end   := v_period_start + interval '1 month';
  IF v_month=1 THEN v_prev_year:=v_year-1; v_prev_month:=12;
  ELSE v_prev_year:=v_year; v_prev_month:=v_month-1; END IF;

  FOR v_user IN SELECT id FROM public.profiles WHERE gender='male' LOOP
    SELECT closing_balance INTO v_opening FROM public.monthly_statements
     WHERE user_id=v_user.id AND year=v_prev_year AND month=v_prev_month;
    v_opening := COALESCE(v_opening, 0);

    SELECT
      COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit'  THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='chat' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='audio_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='video_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='private_group_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='gift' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='tip' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND transaction_type='recharge' THEN amount ELSE 0 END),0)
    INTO v_credits, v_debits, v_chat, v_audio, v_video, v_group, v_gift, v_tip, v_recharge
    FROM public.wallet_transactions
    WHERE user_id=v_user.id AND status='completed'
      AND created_at>=v_period_start AND created_at<v_period_end;

    v_closing := GREATEST(v_opening + v_credits - v_debits, 0);

    INSERT INTO public.monthly_statements (
      user_id, gender, year, month, opening_balance, total_credit, total_debit,
      closing_balance, chat_amount, audio_call_amount, video_call_amount,
      group_call_amount, gift_amount, tip_amount, recharge_amount, payout_amount, payout_status
    ) VALUES (
      v_user.id, 'male', v_year, v_month, v_opening, v_credits, v_debits,
      v_closing, v_chat, v_audio, v_video, v_group, v_gift, v_tip, v_recharge, 0, 'na'
    ) ON CONFLICT (user_id, year, month) DO UPDATE SET
      opening_balance=EXCLUDED.opening_balance, total_credit=EXCLUDED.total_credit,
      total_debit=EXCLUDED.total_debit, closing_balance=EXCLUDED.closing_balance,
      chat_amount=EXCLUDED.chat_amount, audio_call_amount=EXCLUDED.audio_call_amount,
      video_call_amount=EXCLUDED.video_call_amount, group_call_amount=EXCLUDED.group_call_amount,
      gift_amount=EXCLUDED.gift_amount, tip_amount=EXCLUDED.tip_amount,
      recharge_amount=EXCLUDED.recharge_amount, generated_at=NOW();
    v_men_done := v_men_done + 1;
  END LOOP;

  FOR v_user IN SELECT id FROM public.profiles WHERE gender='female' LOOP
    SELECT
      COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='chat' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='audio_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='video_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='private_group_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='gift' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='tip' THEN amount ELSE 0 END),0)
    INTO v_credits, v_chat, v_audio, v_video, v_group, v_gift, v_tip
    FROM public.wallet_transactions
    WHERE user_id=v_user.id AND status='completed'
      AND created_at>=v_period_start AND created_at<v_period_end;

    v_closing := v_credits;
    v_payout := v_closing;

    INSERT INTO public.monthly_statements (
      user_id, gender, year, month, opening_balance, total_credit, total_debit,
      closing_balance, chat_amount, audio_call_amount, video_call_amount,
      group_call_amount, gift_amount, tip_amount, payout_amount, payout_status
    ) VALUES (
      v_user.id, 'female', v_year, v_month, 0, v_credits, 0, v_closing,
      v_chat, v_audio, v_video, v_group, v_gift, v_tip, v_payout,
      CASE WHEN v_payout>0 THEN 'pending' ELSE 'na' END
    ) ON CONFLICT (user_id, year, month) DO UPDATE SET
      total_credit=EXCLUDED.total_credit, closing_balance=EXCLUDED.closing_balance,
      chat_amount=EXCLUDED.chat_amount, audio_call_amount=EXCLUDED.audio_call_amount,
      video_call_amount=EXCLUDED.video_call_amount, group_call_amount=EXCLUDED.group_call_amount,
      gift_amount=EXCLUDED.gift_amount, tip_amount=EXCLUDED.tip_amount,
      payout_amount=EXCLUDED.payout_amount,
      payout_status = CASE WHEN public.monthly_statements.payout_status IN ('approved','paid')
                           THEN public.monthly_statements.payout_status ELSE EXCLUDED.payout_status END,
      generated_at=NOW();
    v_women_done := v_women_done + 1;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'year', v_year, 'month', v_month,
    'men_processed', v_men_done, 'women_processed', v_women_done);
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 7. PAYOUT SNAPSHOT (admin "Generate Now")
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.generate_payout_snapshot_unified()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_now timestamptz := now() AT TIME ZONE 'Asia/Kolkata';
  v_year int := EXTRACT(year FROM v_now)::int;
  v_month int := EXTRACT(month FROM v_now)::int;
  v_user RECORD;
  v_total_earned numeric(12,2); v_paid_out numeric(12,2); v_available numeric(12,2);
  v_chat numeric(12,2); v_audio numeric(12,2); v_video numeric(12,2);
  v_group numeric(12,2); v_gift numeric(12,2); v_tip numeric(12,2);
  v_count int := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id=auth.uid() AND role='admin') THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  FOR v_user IN SELECT id FROM public.profiles WHERE gender='female' LOOP
    SELECT
      COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='chat' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='audio_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='video_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='private_group_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='gift' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='tip' THEN amount ELSE 0 END),0)
    INTO v_total_earned, v_chat, v_audio, v_video, v_group, v_gift, v_tip
    FROM public.wallet_transactions
    WHERE user_id=v_user.id AND status='completed';

    SELECT COALESCE(SUM(payout_amount),0) INTO v_paid_out
    FROM public.monthly_statements
    WHERE user_id=v_user.id AND gender='female' AND payout_status IN ('approved','paid');

    v_available := GREATEST(v_total_earned - v_paid_out, 0);
    IF v_available <= 0 THEN CONTINUE; END IF;

    INSERT INTO public.monthly_statements (
      user_id, gender, year, month, opening_balance, total_credit, total_debit, closing_balance,
      chat_amount, audio_call_amount, video_call_amount, group_call_amount,
      gift_amount, tip_amount, payout_amount, payout_status, generated_at
    ) VALUES (
      v_user.id, 'female', v_year, v_month, 0, v_available, 0, v_available,
      v_chat, v_audio, v_video, v_group, v_gift, v_tip, v_available, 'pending', now()
    ) ON CONFLICT (user_id, year, month) DO UPDATE SET
      total_credit=EXCLUDED.total_credit, closing_balance=EXCLUDED.closing_balance,
      chat_amount=EXCLUDED.chat_amount, audio_call_amount=EXCLUDED.audio_call_amount,
      video_call_amount=EXCLUDED.video_call_amount, group_call_amount=EXCLUDED.group_call_amount,
      gift_amount=EXCLUDED.gift_amount, tip_amount=EXCLUDED.tip_amount,
      payout_amount=EXCLUDED.payout_amount,
      payout_status=CASE WHEN public.monthly_statements.payout_status IN ('approved','paid')
                         THEN public.monthly_statements.payout_status ELSE 'pending' END,
      generated_at=now();
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'count', v_count, 'year', v_year, 'month', v_month);
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 8. PROCESS MONTHLY PAYOUT (sweep women earnings → snapshots)
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.process_monthly_payout()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_ist_now timestamptz := NOW() AT TIME ZONE 'Asia/Kolkata';
  v_ist_date date := (NOW() AT TIME ZONE 'Asia/Kolkata')::date;
  v_prev_date timestamptz := (NOW() AT TIME ZONE 'Asia/Kolkata') - interval '1 day';
  v_prev_month_t text := TO_CHAR(v_prev_date, 'YYYY-MM');
  v_prev_year int := EXTRACT(YEAR FROM v_prev_date)::int;
  v_prev_month_n int := EXTRACT(MONTH FROM v_prev_date)::int;
  v_period_start timestamptz; v_period_end timestamptz;
  v_rec record; v_user record;
  v_balance numeric(12,2); v_credits numeric(12,2); v_debits numeric(12,2);
  v_opening numeric(12,2); v_closing numeric(12,2);
  v_chat numeric(12,2); v_audio numeric(12,2); v_video numeric(12,2);
  v_group numeric(12,2); v_gift numeric(12,2); v_tip numeric(12,2); v_recharge numeric(12,2);
  v_wallet RECORD; v_idem text;
  v_women_processed int := 0; v_women_skipped int := 0; v_men_processed int := 0;
BEGIN
  v_period_start := make_timestamptz(v_prev_year, v_prev_month_n, 1, 0, 0, 0, 'Asia/Kolkata');
  v_period_end := v_period_start + interval '1 month';

  FOR v_rec IN
    SELECT p.id AS user_id, p.app_sno, k.id AS kyc_id, k.verification_status AS kyc_status,
      k.account_holder_name, k.full_name_as_per_bank, k.bank_name, k.account_number, k.ifsc_code,
      k.mobile_number, k.email_address, k.current_address, k.upi_id, k.upi_vpa, k.beneficiary_purpose
    FROM public.profiles p
    LEFT JOIN public.women_kyc k ON k.user_id = p.id
    WHERE p.gender='female'
  LOOP
    v_balance := public.women_ledger_balance(v_rec.user_id);
    IF v_balance <= 0 THEN CONTINUE; END IF;

    IF v_rec.kyc_id IS NULL OR v_rec.kyc_status <> 'approved' THEN
      INSERT INTO public.women_payout_snapshots (
        snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
        user_id, full_name, gross_earned, withdrawal_fee_amount, net_payable,
        wallet_balance_at_snapshot, payment_status, app_sno, skipped_reason
      ) VALUES (
        'monthly', v_ist_now, v_ist_date, v_prev_month_t, v_prev_year,
        v_rec.user_id, COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name, 'Unknown'),
        v_balance, 0, 0, v_balance, 'failed', v_rec.app_sno, 'KYC not approved'
      ) ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;
      v_women_skipped := v_women_skipped + 1;
      CONTINUE;
    END IF;

    INSERT INTO public.women_payout_snapshots (
      snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
      user_id, app_sno, beneficiary_purpose,
      full_name, account_holder_name, mobile_number, email_address, address,
      bank_name, bank_account_number, ifsc_code, upi_vpa,
      gross_earned, withdrawal_fee_amount, net_payable, already_paid, incremental_payable,
      wallet_balance_at_snapshot, payment_status
    ) VALUES (
      'monthly', v_ist_now, v_ist_date, v_prev_month_t, v_prev_year,
      v_rec.user_id, v_rec.app_sno, COALESCE(v_rec.beneficiary_purpose, 'others'),
      COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name),
      v_rec.account_holder_name, v_rec.mobile_number, v_rec.email_address,
      v_rec.current_address, v_rec.bank_name, v_rec.account_number,
      v_rec.ifsc_code, COALESCE(v_rec.upi_vpa, v_rec.upi_id),
      v_balance, 0, v_balance, 0, v_balance,
      v_balance, 'pending'
    ) ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;

    IF FOUND THEN
      SELECT * INTO v_wallet FROM public.wallets WHERE user_id=v_rec.user_id FOR UPDATE;
      IF NOT FOUND THEN
        INSERT INTO public.wallets(user_id, gender, balance, currency)
        VALUES (v_rec.user_id, 'female', 0, 'INR') RETURNING * INTO v_wallet;
      END IF;

      v_idem := 'payout|' || v_rec.user_id::text || '|' || v_prev_month_t;

      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, session_type,
        amount, balance_after, description, reference_id, idempotency_key, status
      ) VALUES (
        v_wallet.id, v_rec.user_id, 'debit', 'payout', 'payout',
        v_balance, 0, 'Monthly payout sweep ' || v_prev_month_t,
        'PAYOUT-' || v_prev_month_t, v_idem, 'completed'
      ) ON CONFLICT (idempotency_key) DO NOTHING;

      UPDATE public.wallets SET balance=0, updated_at=now() WHERE id=v_wallet.id;
      v_women_processed := v_women_processed + 1;
    END IF;

    SELECT
      COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit'  THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='chat' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='audio_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='video_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='private_group_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='gift' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='tip' THEN amount ELSE 0 END),0)
    INTO v_credits, v_debits, v_chat, v_audio, v_video, v_group, v_gift, v_tip
    FROM public.wallet_transactions
    WHERE user_id=v_rec.user_id AND status='completed'
      AND created_at>=v_period_start AND created_at<v_period_end;

    v_closing := GREATEST(v_credits - v_debits, 0);

    INSERT INTO public.monthly_statements (
      user_id, gender, year, month, opening_balance, total_credit, total_debit,
      closing_balance, chat_amount, audio_call_amount, video_call_amount,
      group_call_amount, gift_amount, tip_amount, payout_amount, payout_status, generated_at
    ) VALUES (
      v_rec.user_id, 'female', v_prev_year, v_prev_month_n,
      0, v_credits, v_debits, v_closing,
      v_chat, v_audio, v_video, v_group, v_gift, v_tip,
      v_balance, CASE WHEN v_balance>0 THEN 'pending' ELSE 'na' END, NOW()
    ) ON CONFLICT (user_id, year, month) DO UPDATE SET
      total_credit=EXCLUDED.total_credit, total_debit=EXCLUDED.total_debit,
      closing_balance=EXCLUDED.closing_balance,
      chat_amount=EXCLUDED.chat_amount, audio_call_amount=EXCLUDED.audio_call_amount,
      video_call_amount=EXCLUDED.video_call_amount, group_call_amount=EXCLUDED.group_call_amount,
      gift_amount=EXCLUDED.gift_amount, tip_amount=EXCLUDED.tip_amount,
      payout_amount=EXCLUDED.payout_amount,
      payout_status=CASE WHEN public.monthly_statements.payout_status IN ('approved','paid')
                         THEN public.monthly_statements.payout_status ELSE EXCLUDED.payout_status END,
      generated_at=NOW();
  END LOOP;

  FOR v_user IN SELECT id FROM public.profiles WHERE gender='male' LOOP
    SELECT COALESCE(closing_balance,0) INTO v_opening FROM public.monthly_statements
    WHERE user_id=v_user.id AND ((year*12+month)=(v_prev_year*12+v_prev_month_n)-1);
    v_opening := COALESCE(v_opening,0);

    SELECT
      COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit'  THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='chat' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='audio_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='video_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='private_group_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='gift' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='tip' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND transaction_type='recharge' THEN amount ELSE 0 END),0)
    INTO v_credits, v_debits, v_chat, v_audio, v_video, v_group, v_gift, v_tip, v_recharge
    FROM public.wallet_transactions
    WHERE user_id=v_user.id AND status='completed'
      AND created_at>=v_period_start AND created_at<v_period_end;

    v_closing := GREATEST(v_opening + v_credits - v_debits, 0);

    INSERT INTO public.monthly_statements (
      user_id, gender, year, month, opening_balance, total_credit, total_debit,
      closing_balance, chat_amount, audio_call_amount, video_call_amount,
      group_call_amount, gift_amount, tip_amount, recharge_amount,
      payout_amount, payout_status, generated_at
    ) VALUES (
      v_user.id, 'male', v_prev_year, v_prev_month_n,
      v_opening, v_credits, v_debits, v_closing,
      v_chat, v_audio, v_video, v_group, v_gift, v_tip, v_recharge,
      0, 'na', NOW()
    ) ON CONFLICT (user_id, year, month) DO UPDATE SET
      opening_balance=EXCLUDED.opening_balance, total_credit=EXCLUDED.total_credit,
      total_debit=EXCLUDED.total_debit, closing_balance=EXCLUDED.closing_balance,
      chat_amount=EXCLUDED.chat_amount, audio_call_amount=EXCLUDED.audio_call_amount,
      video_call_amount=EXCLUDED.video_call_amount, group_call_amount=EXCLUDED.group_call_amount,
      gift_amount=EXCLUDED.gift_amount, tip_amount=EXCLUDED.tip_amount,
      recharge_amount=EXCLUDED.recharge_amount, generated_at=NOW();

    v_men_processed := v_men_processed + 1;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'ist_datetime', v_ist_now, 'ist_date', v_ist_date,
    'period', v_prev_month_t, 'women_processed', v_women_processed,
    'women_skipped_no_kyc', v_women_skipped, 'men_processed', v_men_processed);
END;
$$;

-- ═══════════════════════════════════════════════════════════════════
-- 9. DROP LEGACY TABLES
-- ═══════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS public.platform_ledger CASCADE;
DROP TABLE IF EXISTS public.ledger_transactions CASCADE;
DROP TABLE IF EXISTS public.women_earnings CASCADE;
DROP TABLE IF EXISTS public.earnings_ledger CASCADE;
DROP TABLE IF EXISTS public.billing_ledger CASCADE;
