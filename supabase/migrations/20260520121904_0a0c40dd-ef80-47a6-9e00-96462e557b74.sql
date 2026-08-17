-- Canonical wallet balance helper: live + archive wallet_transactions only
CREATE OR REPLACE FUNCTION public.canonical_wallet_balance(p_user_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT GREATEST(COALESCE(SUM(
    CASE WHEN x.type='credit' THEN x.amount
         WHEN x.type='debit'  THEN -x.amount
         ELSE 0 END
  ), 0), 0)::numeric(12,2)
  FROM (
    SELECT type, amount, status FROM public.wallet_transactions
      WHERE user_id = public.resolve_wallet_user_id(p_user_id)
    UNION ALL
    SELECT type, amount, status FROM public.wallet_transactions_archive
      WHERE user_id = public.resolve_wallet_user_id(p_user_id)
  ) x
  WHERE x.status='completed';
$$;

CREATE OR REPLACE FUNCTION public.ensure_canonical_wallet(p_user_id uuid, p_gender text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_wallet_id uuid;
  v_gender text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT id INTO v_wallet_id
  FROM public.wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    SELECT COALESCE(p_gender, p.gender, 'male') INTO v_gender
    FROM public.profiles p
    WHERE p.user_id = v_user_id OR p.id = p_user_id
    LIMIT 1;

    INSERT INTO public.wallets (user_id, gender, balance, currency)
    VALUES (v_user_id, COALESCE(v_gender, p_gender, 'male'), 0, 'INR')
    RETURNING id INTO v_wallet_id;
  END IF;

  RETURN v_wallet_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_wallet_balance_from_ledger(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_wallet_id uuid;
  v_balance numeric(12,2);
BEGIN
  IF v_user_id IS NULL THEN
    RETURN 0;
  END IF;

  v_wallet_id := public.ensure_canonical_wallet(v_user_id, NULL);
  v_balance := public.canonical_wallet_balance(v_user_id);

  UPDATE public.wallets
  SET balance = v_balance, updated_at = now()
  WHERE id = v_wallet_id;

  RETURN v_balance;
END;
$$;

-- Keep cached wallets.balance synced whenever canonical transactions change.
CREATE OR REPLACE FUNCTION public.trg_sync_wallet_balance_from_transactions()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := COALESCE(NEW.user_id, OLD.user_id);
  IF v_user_id IS NOT NULL THEN
    PERFORM public.sync_wallet_balance_from_ledger(v_user_id);
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_wallet_balance_from_transactions ON public.wallet_transactions;
CREATE TRIGGER trg_sync_wallet_balance_from_transactions
AFTER INSERT OR UPDATE OR DELETE ON public.wallet_transactions
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_wallet_balance_from_transactions();

DROP TRIGGER IF EXISTS trg_sync_wallet_balance_from_archive ON public.wallet_transactions_archive;
CREATE TRIGGER trg_sync_wallet_balance_from_archive
AFTER INSERT OR UPDATE OR DELETE ON public.wallet_transactions_archive
FOR EACH ROW EXECUTE FUNCTION public.trg_sync_wallet_balance_from_transactions();

-- Balance reads: always live + archive, never stale wallets.balance.
CREATE OR REPLACE FUNCTION public.men_ledger_balance(p_man_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT public.canonical_wallet_balance(p_man_id);
$$;

CREATE OR REPLACE FUNCTION public.women_ledger_balance(p_woman_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT public.canonical_wallet_balance(p_woman_id);
$$;

CREATE OR REPLACE FUNCTION public.get_man_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_balance numeric(12,2);
BEGIN
  v_balance := public.canonical_wallet_balance(v_user_id);
  RETURN jsonb_build_object('balance',COALESCE(v_balance,0),'currency','INR');
END;
$$;

CREATE OR REPLACE FUNCTION public.get_men_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_balance numeric := 0;
  v_currency text := 'INR';
  v_recharges numeric := 0;
  v_spending numeric := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('balance', 0, 'currency', 'INR', 'total_recharges', 0, 'total_spending', 0);
  END IF;

  IF auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_user_id
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Not allowed to view this wallet';
  END IF;

  SELECT COALESCE(w.currency, 'INR') INTO v_currency
  FROM public.wallets w
  WHERE w.user_id = v_user_id;

  SELECT
    COALESCE(SUM(CASE WHEN u.type = 'credit' THEN u.amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN u.type = 'debit' THEN u.amount ELSE 0 END), 0),
    GREATEST(COALESCE(SUM(CASE WHEN u.type = 'credit' THEN u.amount WHEN u.type = 'debit' THEN -u.amount ELSE 0 END), 0), 0)
  INTO v_recharges, v_spending, v_balance
  FROM (
    SELECT type, amount, status FROM public.wallet_transactions WHERE user_id = v_user_id
    UNION ALL
    SELECT type, amount, status FROM public.wallet_transactions_archive WHERE user_id = v_user_id
  ) u
  WHERE u.status = 'completed';

  RETURN jsonb_build_object('balance', COALESCE(v_balance,0), 'currency', COALESCE(v_currency, 'INR'), 'total_recharges', v_recharges, 'total_spending', v_spending);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_men_wallet_balances_bulk(p_user_ids uuid[])
RETURNS TABLE(user_id uuid, balance numeric)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT u AS user_id, public.canonical_wallet_balance(u)::numeric AS balance
  FROM unnest(p_user_ids) AS u;
$$;

CREATE OR REPLACE FUNCTION public.get_woman_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_total_earned numeric(12,2) := 0;
  v_paid_out numeric(12,2) := 0;
  v_today numeric(12,2) := 0;
  v_available numeric(12,2) := 0;
  v_today_start timestamptz;
BEGIN
  v_today_start := date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata';

  SELECT
    COALESCE(SUM(CASE WHEN u.type='credit' THEN u.amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN u.type='debit' AND u.transaction_type IN ('withdrawal','withdrawal_fee','payout') THEN u.amount ELSE 0 END), 0),
    GREATEST(COALESCE(SUM(CASE WHEN u.type='credit' THEN u.amount WHEN u.type='debit' THEN -u.amount ELSE 0 END), 0), 0),
    COALESCE(SUM(CASE WHEN u.type='credit' AND u.created_at >= v_today_start THEN u.amount ELSE 0 END), 0)
  INTO v_total_earned, v_paid_out, v_available, v_today
  FROM (
    SELECT type, amount, status, transaction_type, created_at FROM public.wallet_transactions WHERE user_id=v_user_id
    UNION ALL
    SELECT type, amount, status, transaction_type, created_at FROM public.wallet_transactions_archive WHERE user_id=v_user_id
  ) u
  WHERE u.status='completed';

  RETURN jsonb_build_object('available_balance', COALESCE(v_available,0), 'total_earned', COALESCE(v_total_earned,0),
    'paid_out', COALESCE(v_paid_out,0), 'today_earnings', COALESCE(v_today,0), 'currency', 'INR');
END;
$$;

CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_balance numeric := 0;
  v_earnings numeric := 0;
  v_debits numeric := 0;
  v_pending numeric := 0;
  v_today numeric := 0;
  v_today_start timestamptz;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('total_earnings', 0, 'total_debits', 0, 'pending_withdrawals', 0, 'today_earnings', 0, 'available_balance', 0);
  END IF;

  IF auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_user_id
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Not allowed to view this wallet';
  END IF;

  v_today_start := date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata';

  SELECT
    COALESCE(SUM(CASE WHEN u.type = 'credit' THEN u.amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN u.type = 'debit' THEN u.amount ELSE 0 END), 0),
    GREATEST(COALESCE(SUM(CASE WHEN u.type = 'credit' THEN u.amount WHEN u.type = 'debit' THEN -u.amount ELSE 0 END), 0), 0),
    COALESCE(SUM(CASE WHEN u.type = 'credit' AND u.created_at >= v_today_start THEN u.amount ELSE 0 END), 0)
  INTO v_earnings, v_debits, v_balance, v_today
  FROM (
    SELECT type, amount, status, created_at FROM public.wallet_transactions WHERE user_id = v_user_id
    UNION ALL
    SELECT type, amount, status, created_at FROM public.wallet_transactions_archive WHERE user_id = v_user_id
  ) u
  WHERE u.status = 'completed';

  SELECT COALESCE(SUM(wr.amount), 0)
  INTO v_pending
  FROM public.withdrawal_requests wr
  WHERE public.resolve_wallet_user_id(wr.user_id) = v_user_id
    AND wr.status = 'pending';

  RETURN jsonb_build_object('total_earnings', v_earnings, 'total_debits', v_debits, 'pending_withdrawals', v_pending, 'today_earnings', v_today, 'available_balance', v_balance);
END;
$$;

CREATE OR REPLACE FUNCTION public.check_session_balance(p_user_id uuid, p_session_id uuid DEFAULT NULL::uuid, p_session_type text DEFAULT 'chat'::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_balance numeric := 0;
  v_pricing jsonb;
  v_min_needed numeric;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('sufficient', false, 'balance', 0, 'required', 0, 'shortfall', 0, 'has_balance', false, 'error', 'Wallet not found');
  END IF;

  v_balance := public.canonical_wallet_balance(v_user_id);
  v_pricing := public.get_unified_pricing();
  v_min_needed := CASE p_session_type
    WHEN 'video_call' THEN COALESCE((v_pricing->>'video_man_rate')::numeric, 8)
    WHEN 'audio_call' THEN COALESCE((v_pricing->>'audio_man_rate')::numeric, 6)
    WHEN 'private_group_call' THEN COALESCE((v_pricing->>'group_man_rate')::numeric, 4)
    ELSE COALESCE((v_pricing->>'chat_man_rate')::numeric, 4)
  END * 2;

  RETURN jsonb_build_object(
    'sufficient', v_balance >= v_min_needed, 'has_balance', v_balance >= v_min_needed,
    'balance', v_balance, 'required', v_min_needed,
    'shortfall', GREATEST(v_min_needed - v_balance, 0), 'min_required', v_min_needed
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('sufficient', false, 'has_balance', false, 'balance', 0, 'required', 4, 'shortfall', 4, 'error', SQLERRM);
END;
$$;

-- Canonical billing for chat/audio/video/private group call: charge men, credit women, idempotent across live+archive.
CREATE OR REPLACE FUNCTION public.bill_session_minute(p_session_id uuid, p_session_type text, p_minutes numeric, p_man_id uuid, p_woman_id uuid, p_man_count integer DEFAULT 1, p_minute_index integer DEFAULT NULL::integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_pricing jsonb;
  v_man_wallet_id uuid;
  v_woman_wallet_id uuid;
  v_man_id uuid := public.resolve_wallet_user_id(p_man_id);
  v_woman_id uuid := public.resolve_wallet_user_id(p_woman_id);
  v_man_rate numeric(10,2);
  v_woman_rate numeric(10,2);
  v_charge numeric(10,2);
  v_earn numeric(10,2);
  v_man_balance numeric(12,2);
  v_woman_balance numeric(12,2);
  v_man_balance_after numeric(12,2);
  v_woman_balance_after numeric(12,2);
  v_idem_key text;
  v_idem_earn text;
  v_is_super boolean := false;
  v_minute_idx integer;
  v_label text;
  v_caller uuid := auth.uid();
  v_is_live_group_host boolean := false;
BEGIN
  IF p_session_type NOT IN ('chat','audio_call','video_call','private_group_call') THEN
    RETURN jsonb_build_object('success',false,'error','Invalid session_type');
  END IF;
  IF p_minutes <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','minutes must be > 0');
  END IF;
  IF v_man_id IS NULL OR v_woman_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','Missing billing user');
  END IF;

  IF p_session_type = 'private_group_call' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.group_active_hosts gah
      WHERE gah.host_id = v_woman_id
        AND gah.stream_id = p_session_id::text
        AND gah.is_active = true
        AND gah.last_heartbeat_at > now() - interval '2 minutes'
    ) INTO v_is_live_group_host;
  END IF;

  IF auth.role() <> 'service_role'
     AND v_caller IS DISTINCT FROM v_man_id
     AND NOT (p_session_type = 'private_group_call' AND v_caller IS NOT DISTINCT FROM v_woman_id AND v_is_live_group_host)
     AND NOT public.has_role(v_caller, 'admin') THEN
    RETURN jsonb_build_object('success',false,'error','Not allowed to bill for this user');
  END IF;

  v_minute_idx := COALESCE(p_minute_index, FLOOR(EXTRACT(EPOCH FROM date_trunc('minute', now())) / 60)::integer);
  v_idem_key  := 'session|' || p_session_id::text || '|' || p_session_type || '|' || v_man_id::text || '|' || v_minute_idx::text;
  v_idem_earn := 'session_earn|' || p_session_id::text || '|' || p_session_type || '|' || v_woman_id::text || '|' || v_man_id::text || '|' || v_minute_idx::text;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key)
     OR EXISTS (SELECT 1 FROM public.wallet_transactions_archive WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
  END IF;

  v_pricing := public.get_unified_pricing();
  v_man_rate := CASE p_session_type
    WHEN 'chat' THEN (v_pricing->>'chat_man_rate')::numeric
    WHEN 'audio_call' THEN (v_pricing->>'audio_man_rate')::numeric
    WHEN 'video_call' THEN (v_pricing->>'video_man_rate')::numeric
    WHEN 'private_group_call' THEN (v_pricing->>'group_man_rate')::numeric
  END;
  v_woman_rate := CASE p_session_type
    WHEN 'chat' THEN (v_pricing->>'chat_woman_rate')::numeric
    WHEN 'audio_call' THEN (v_pricing->>'audio_woman_rate')::numeric
    WHEN 'video_call' THEN (v_pricing->>'video_woman_rate')::numeric
    WHEN 'private_group_call' THEN (v_pricing->>'group_woman_rate')::numeric
  END;

  v_charge := ROUND(v_man_rate * p_minutes, 2);
  v_earn   := ROUND(v_woman_rate * p_minutes * GREATEST(p_man_count,1), 2);
  v_label  := CASE p_session_type
    WHEN 'chat' THEN 'Chat'
    WHEN 'audio_call' THEN 'Audio Call'
    WHEN 'video_call' THEN 'Video Call'
    WHEN 'private_group_call' THEN 'Group Call'
  END;

  SELECT public.has_role(v_man_id, 'admin') INTO v_is_super;

  IF NOT v_is_super THEN
    v_man_wallet_id := public.ensure_canonical_wallet(v_man_id, 'male');
    v_man_balance := public.canonical_wallet_balance(v_man_id);

    IF v_man_balance < v_charge THEN
      RETURN jsonb_build_object('success',false,'error','Insufficient balance','balance',v_man_balance,'required',v_charge);
    END IF;

    v_man_balance_after := (v_man_balance - v_charge)::numeric(12,2);

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type, session_id,
      amount, balance_after, duration_seconds, rate_per_minute,
      description, idempotency_key, status
    ) VALUES (
      v_man_wallet_id, v_man_id, 'debit', 'session_charge', p_session_type, p_session_id,
      v_charge, v_man_balance_after, ROUND(p_minutes * 60)::int, v_man_rate,
      v_label || ' — ' || p_minutes || ' min @ ₹' || v_man_rate || '/min',
      v_idem_key, 'completed'
    );
  END IF;

  IF v_earn > 0 THEN
    v_woman_wallet_id := public.ensure_canonical_wallet(v_woman_id, 'female');
    v_woman_balance := public.canonical_wallet_balance(v_woman_id);
    v_woman_balance_after := (v_woman_balance + v_earn)::numeric(12,2);

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type, session_id,
      amount, balance_after, duration_seconds, rate_per_minute,
      description, idempotency_key, status
    ) VALUES (
      v_woman_wallet_id, v_woman_id, 'credit', 'session_earning', p_session_type, p_session_id,
      v_earn, v_woman_balance_after, ROUND(p_minutes * 60)::int, v_woman_rate,
      v_label || ' earnings — ' || p_minutes || ' min @ ₹' || v_woman_rate || '/min',
      v_idem_earn, 'completed'
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'session_type', p_session_type,
    'charged', CASE WHEN v_is_super THEN 0 ELSE v_charge END,
    'earned', v_earn,
    'man_rate', v_man_rate,
    'woman_rate', v_woman_rate,
    'minutes', p_minutes,
    'super_user_skip', v_is_super,
    'minute_index', v_minute_idx
  );
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
END;
$$;

-- Gifts and tips: men debit 100%, women credit configured percent (50% by default), all in wallet_transactions.
CREATE OR REPLACE FUNCTION public.bill_gift_or_tip(p_man_id uuid, p_woman_id uuid, p_amount numeric, p_type text, p_description text DEFAULT NULL::text, p_reference_id text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_pricing jsonb;
  v_man_wallet_id uuid;
  v_woman_wallet_id uuid;
  v_man_id uuid := public.resolve_wallet_user_id(p_man_id);
  v_woman_id uuid := public.resolve_wallet_user_id(p_woman_id);
  v_pct numeric(5,2);
  v_woman_credit numeric(10,2);
  v_man_balance numeric(12,2);
  v_woman_balance numeric(12,2);
  v_man_balance_after numeric(12,2);
  v_woman_balance_after numeric(12,2);
  v_is_admin boolean := false;
  v_idem_man text;
  v_idem_woman text;
  v_ref text;
  v_charge_type text;
  v_earning_type text;
BEGIN
  IF p_type NOT IN ('gift','tip') THEN
    RETURN jsonb_build_object('success',false,'error','type must be gift or tip');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','amount must be > 0');
  END IF;
  IF v_man_id IS NULL OR v_woman_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','Missing billing user');
  END IF;

  IF auth.uid() IS NOT NULL
     AND auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_man_id
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RETURN jsonb_build_object('success',false,'error','Not allowed to bill for this user');
  END IF;

  v_ref := COALESCE(NULLIF(p_reference_id, ''), gen_random_uuid()::text);
  v_idem_man   := p_type || '|' || v_man_id::text || '|' || v_woman_id::text || '|' || v_ref;
  v_idem_woman := p_type || '_earn|' || v_woman_id::text || '|' || v_man_id::text || '|' || v_ref;
  v_charge_type  := p_type || '_charge';
  v_earning_type := p_type || '_earning';

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_man)
     OR EXISTS (SELECT 1 FROM public.wallet_transactions_archive WHERE idempotency_key = v_idem_man) THEN
    RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
  END IF;

  v_pricing := public.get_unified_pricing();
  v_pct := CASE p_type WHEN 'gift' THEN (v_pricing->>'gift_woman_pct')::numeric ELSE (v_pricing->>'tip_woman_pct')::numeric END;
  v_woman_credit := ROUND(p_amount * v_pct / 100.0, 2);

  SELECT public.has_role(v_man_id, 'admin') INTO v_is_admin;

  IF NOT v_is_admin THEN
    v_man_wallet_id := public.ensure_canonical_wallet(v_man_id, 'male');
    v_man_balance := public.canonical_wallet_balance(v_man_id);

    IF v_man_balance < p_amount THEN
      RETURN jsonb_build_object('success',false,'error','Insufficient balance','balance',v_man_balance,'required',p_amount);
    END IF;

    v_man_balance_after := (v_man_balance - p_amount)::numeric(12,2);

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type,
      amount, balance_after, description, reference_id, idempotency_key, status
    ) VALUES (
      v_man_wallet_id, v_man_id, 'debit', v_charge_type, p_type,
      p_amount, v_man_balance_after,
      COALESCE(p_description, initcap(p_type) || ' sent — ₹' || p_amount),
      v_ref, v_idem_man, 'completed'
    );
  END IF;

  IF v_woman_credit > 0 THEN
    v_woman_wallet_id := public.ensure_canonical_wallet(v_woman_id, 'female');
    v_woman_balance := public.canonical_wallet_balance(v_woman_id);
    v_woman_balance_after := (v_woman_balance + v_woman_credit)::numeric(12,2);

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type,
      amount, balance_after, description, reference_id, idempotency_key, status
    ) VALUES (
      v_woman_wallet_id, v_woman_id, 'credit', v_earning_type, p_type,
      v_woman_credit, v_woman_balance_after,
      COALESCE(p_description, initcap(p_type) || ' received — ' || v_pct || '% of ₹' || p_amount),
      v_ref, v_idem_woman, 'completed'
    ) ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  RETURN jsonb_build_object('success',true,'type',p_type,'charged',CASE WHEN v_is_admin THEN 0 ELSE p_amount END,'woman_credit',v_woman_credit,'woman_pct',v_pct,'idempotency_key',v_idem_man);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
END;
$$;

CREATE OR REPLACE FUNCTION public.bill_group_gift_or_tip(p_group_id uuid, p_man_id uuid, p_amount numeric, p_type text, p_description text DEFAULT NULL::text, p_reference_id text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_group   RECORD;
  v_host_id uuid;
  v_man_id  uuid := public.resolve_wallet_user_id(p_man_id);
  v_ref     text;
  v_result  jsonb;
BEGIN
  IF p_type NOT IN ('gift','tip') THEN
    RETURN jsonb_build_object('success',false,'error','type must be gift or tip');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','amount must be > 0');
  END IF;
  IF v_man_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','Missing man id');
  END IF;

  IF auth.uid() IS NOT NULL
     AND auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_man_id
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RETURN jsonb_build_object('success',false,'error','Not allowed to bill for this user');
  END IF;

  SELECT id, name, is_live, is_active, current_host_id
    INTO v_group
  FROM public.private_groups
  WHERE id = p_group_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','Group not found');
  END IF;
  IF NOT COALESCE(v_group.is_live,false) OR NOT COALESCE(v_group.is_active,false) THEN
    RETURN jsonb_build_object('success',false,'error','Group not live');
  END IF;

  v_host_id := v_group.current_host_id;
  IF v_host_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','No active host');
  END IF;

  IF NOT public.has_role(v_man_id, 'admin') THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.group_memberships
      WHERE group_id = p_group_id
        AND user_id  = v_man_id
        AND has_access = true
    ) THEN
      RETURN jsonb_build_object('success',false,'error','Not an active group member');
    END IF;
  END IF;

  v_ref := COALESCE(NULLIF(p_reference_id, ''), 'grp:' || p_group_id::text || ':' || gen_random_uuid()::text);

  v_result := public.bill_gift_or_tip(
    p_man_id       => v_man_id,
    p_woman_id     => v_host_id,
    p_amount       => p_amount,
    p_type         => p_type,
    p_description  => COALESCE(p_description, initcap(p_type) || ' in group: ' || v_group.name),
    p_reference_id => v_ref
  );

  IF (v_result->>'success')::boolean = true
     AND COALESCE((v_result->>'duplicate_skipped')::boolean, false) = false THEN
    UPDATE public.wallet_transactions
       SET session_id = p_group_id
     WHERE reference_id = v_ref
       AND session_id IS NULL;
  END IF;

  RETURN v_result || jsonb_build_object('group_id', p_group_id, 'host_id', v_host_id);
END;
$$;

-- Recharge / withdrawal / admin / generic transfer write rows first, then cache follows ledger.
CREATE OR REPLACE FUNCTION public.ledger_recharge(p_user_id uuid, p_amount numeric, p_gateway text, p_gateway_txn_id text DEFAULT NULL::text, p_reference_id text DEFAULT NULL::text, p_description text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_wallet_id uuid;
  v_balance_after numeric(12,2);
  v_idem text;
  v_existing_id uuid;
  v_existing_balance numeric;
  v_txn_ref text;
  v_desc text;
  v_tx_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'user_id is required');
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'amount must be > 0');
  END IF;

  v_txn_ref := COALESCE(NULLIF(p_gateway_txn_id, ''), NULLIF(p_reference_id, ''));
  IF v_txn_ref IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'gateway_txn_id or reference_id is required');
  END IF;

  v_idem := 'recharge|' || v_user_id::text || '|' || v_txn_ref;

  SELECT id, balance_after INTO v_existing_id, v_existing_balance
  FROM public.wallet_transactions WHERE idempotency_key = v_idem LIMIT 1;
  IF v_existing_id IS NULL THEN
    SELECT id, balance_after INTO v_existing_id, v_existing_balance
    FROM public.wallet_transactions_archive WHERE idempotency_key = v_idem LIMIT 1;
  END IF;
  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'existing_id', v_existing_id,
      'balance', COALESCE(v_existing_balance, public.canonical_wallet_balance(v_user_id)), 'amount', p_amount, 'idempotency_key', v_idem);
  END IF;

  v_wallet_id := public.ensure_canonical_wallet(v_user_id, 'male');
  v_balance_after := (public.canonical_wallet_balance(v_user_id) + p_amount)::numeric(12,2);
  v_desc := COALESCE(p_description, 'Wallet recharge ₹' || p_amount || ' via ' || COALESCE(p_gateway, 'gateway'));

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, session_type,
    amount, balance_after, description, reference_id, idempotency_key, status
  ) VALUES (
    v_wallet_id, v_user_id, 'credit', 'recharge', 'wallet',
    p_amount, v_balance_after, v_desc, v_txn_ref, v_idem, 'completed'
  ) RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object('success', true, 'balance', v_balance_after, 'amount', p_amount, 'transaction_id', v_tx_id, 'idempotency_key', v_idem);
EXCEPTION WHEN unique_violation THEN
  SELECT id, balance_after INTO v_existing_id, v_existing_balance
  FROM public.wallet_transactions WHERE idempotency_key = v_idem LIMIT 1;
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'existing_id', v_existing_id,
    'balance', COALESCE(v_existing_balance, public.canonical_wallet_balance(v_user_id)), 'amount', p_amount, 'idempotency_key', v_idem);
END;
$$;

CREATE OR REPLACE FUNCTION public.ledger_withdrawal(p_user_id uuid, p_amount numeric, p_payment_method text DEFAULT 'upi'::text, p_payment_details jsonb DEFAULT NULL::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_wallet_id uuid;
  v_pending numeric := 0;
  v_available numeric;
  v_min_withdrawal numeric := 100;
  v_request_id uuid;
  v_fee_pct numeric := 5.00;
  v_fee_amount numeric;
  v_net_payout numeric;
  v_balance_before numeric;
  v_balance_after_payout numeric;
  v_balance_after_fee numeric;
  v_idem text;
  v_idem_fee text;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
  END IF;
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'user_id is required');
  END IF;
  IF auth.role() <> 'service_role' AND auth.uid() IS DISTINCT FROM v_user_id AND NOT public.has_role(auth.uid(), 'admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not allowed to withdraw for this user');
  END IF;

  SELECT min_withdrawal_balance, COALESCE(withdrawal_fee_percent, 5.00)
    INTO v_min_withdrawal, v_fee_pct
  FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
  v_min_withdrawal := COALESCE(v_min_withdrawal, 100);
  v_fee_pct := COALESCE(v_fee_pct, 5.00);

  v_wallet_id := public.ensure_canonical_wallet(v_user_id, 'female');
  v_balance_before := public.canonical_wallet_balance(v_user_id);

  SELECT COALESCE(SUM(amount),0) INTO v_pending
    FROM public.withdrawal_requests
    WHERE public.resolve_wallet_user_id(user_id) = v_user_id AND status = 'pending';
  v_available := v_balance_before - v_pending;

  IF p_amount < v_min_withdrawal THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum withdrawal is ₹' || v_min_withdrawal);
  END IF;
  IF p_amount > v_available THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance. Available: ₹' || v_available);
  END IF;

  v_fee_amount := ROUND(p_amount * v_fee_pct / 100.0, 2);
  v_net_payout := p_amount - v_fee_amount;
  v_balance_after_payout := (v_balance_before - v_net_payout)::numeric(12,2);
  v_balance_after_fee := (v_balance_before - p_amount)::numeric(12,2);

  INSERT INTO public.withdrawal_requests (user_id, amount, payment_method, payment_details, status)
  VALUES (v_user_id, v_net_payout, p_payment_method, p_payment_details, 'pending')
  RETURNING id INTO v_request_id;

  v_idem     := 'withdrawal|' || v_request_id::text;
  v_idem_fee := 'withdrawal_fee|' || v_request_id::text;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, session_type,
    amount, balance_after, description, reference_id, idempotency_key, status
  ) VALUES (
    v_wallet_id, v_user_id, 'debit', 'withdrawal', 'wallet',
    v_net_payout, v_balance_after_payout,
    'Withdrawal payout (₹' || p_amount || ' − ' || v_fee_pct || '% fee ₹' || v_fee_amount || ')',
    v_request_id::text, v_idem, 'completed'
  );

  IF v_fee_amount > 0 THEN
    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type,
      amount, balance_after, description, reference_id, idempotency_key, status
    ) VALUES (
      v_wallet_id, v_user_id, 'debit', 'withdrawal_fee', 'wallet',
      v_fee_amount, v_balance_after_fee,
      'Withdrawal platform fee (' || v_fee_pct || '% of ₹' || p_amount || ')',
      v_request_id::text, v_idem_fee, 'completed'
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'request_id', v_request_id, 'requested_amount', p_amount, 'fee_percent', v_fee_pct, 'fee_amount', v_fee_amount, 'net_payout', v_net_payout, 'available_balance', v_available - p_amount, 'new_balance', v_balance_after_fee);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_deduct_wallet(p_user_id uuid, p_amount numeric, p_reason text, p_admin_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_wallet_id uuid;
  v_old_balance numeric(12,2);
  v_new_balance numeric(12,2);
  v_idem text;
BEGIN
  IF p_amount <= 0 THEN RAISE EXCEPTION 'Deduction amount must be positive'; END IF;

  v_wallet_id := public.ensure_canonical_wallet(v_user_id, NULL);
  v_old_balance := public.canonical_wallet_balance(v_user_id);
  IF p_amount > v_old_balance THEN
    RAISE EXCEPTION 'Insufficient balance. Current: %, Requested: %', v_old_balance, p_amount;
  END IF;

  v_new_balance := (v_old_balance - p_amount)::numeric(12,2);
  v_idem := 'admin_penalty|' || v_user_id::text || '|' || extract(epoch from now())::bigint;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, session_type, amount, balance_after,
    description, reference_id, idempotency_key, status
  ) VALUES (
    v_wallet_id, v_user_id, 'debit', 'admin_penalty', 'admin', p_amount, v_new_balance,
    'Admin penalty: ' || p_reason, 'PENALTY-' || extract(epoch from now())::bigint, v_idem, 'completed'
  );

  INSERT INTO public.notifications (user_id, title, message, type)
  VALUES (v_user_id, 'Wallet Deduction', '₹' || p_amount::text || ' has been deducted from your wallet. Reason: ' || p_reason, 'system');

  INSERT INTO public.audit_logs (admin_id, action, action_type, resource_type, resource_id, details)
  VALUES (p_admin_id, 'Wallet Deduction: ₹' || p_amount::text, 'update', 'wallet', v_user_id::text,
    'Deducted ₹' || p_amount::text || ' from user. Reason: ' || p_reason || '. Previous: ₹' || v_old_balance::text || '. New: ₹' || v_new_balance::text);

  RETURN jsonb_build_object('success', true, 'old_balance', v_old_balance, 'new_balance', v_new_balance, 'amount', p_amount);
END;
$$;

CREATE OR REPLACE FUNCTION public.process_atomic_transfer(p_from_user_id uuid, p_to_user_id uuid, p_amount numeric, p_description text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_from_user_id uuid := public.resolve_wallet_user_id(p_from_user_id);
  v_to_user_id uuid := public.resolve_wallet_user_id(p_to_user_id);
  v_from_wallet_id uuid;
  v_to_wallet_id uuid;
  v_from_balance numeric(12,2);
  v_to_balance numeric(12,2);
  v_from_new_balance numeric(12,2);
  v_to_new_balance numeric(12,2);
  v_from_transaction_id uuid;
  v_to_transaction_id uuid;
  v_is_super_user boolean;
  v_ref text;
BEGIN
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
  END IF;
  IF v_from_user_id IS NULL OR v_to_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Missing user');
  END IF;

  v_is_super_user := public.should_bypass_balance(v_from_user_id);

  IF v_from_user_id < v_to_user_id THEN
    v_from_wallet_id := public.ensure_canonical_wallet(v_from_user_id, NULL);
    v_to_wallet_id := public.ensure_canonical_wallet(v_to_user_id, NULL);
  ELSE
    v_to_wallet_id := public.ensure_canonical_wallet(v_to_user_id, NULL);
    v_from_wallet_id := public.ensure_canonical_wallet(v_from_user_id, NULL);
  END IF;

  v_from_balance := public.canonical_wallet_balance(v_from_user_id);
  v_to_balance := public.canonical_wallet_balance(v_to_user_id);

  IF NOT v_is_super_user AND v_from_balance < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  v_from_new_balance := CASE WHEN v_is_super_user THEN v_from_balance ELSE (v_from_balance - p_amount)::numeric(12,2) END;
  v_to_new_balance := (v_to_balance + p_amount)::numeric(12,2);
  v_ref := 'transfer|' || gen_random_uuid()::text;

  IF NOT v_is_super_user THEN
    INSERT INTO public.wallet_transactions (wallet_id, user_id, type, transaction_type, session_type, amount, balance_after, description, reference_id, idempotency_key, status)
    VALUES (v_from_wallet_id, v_from_user_id, 'debit', 'transfer_out', 'wallet', p_amount, v_from_new_balance, COALESCE(p_description, 'Transfer out'), v_ref, v_ref || '|debit', 'completed')
    RETURNING id INTO v_from_transaction_id;
  END IF;

  INSERT INTO public.wallet_transactions (wallet_id, user_id, type, transaction_type, session_type, amount, balance_after, description, reference_id, idempotency_key, status)
  VALUES (v_to_wallet_id, v_to_user_id, 'credit', 'transfer_in', 'wallet', p_amount, v_to_new_balance, COALESCE(p_description, 'Transfer in'), v_ref, v_ref || '|credit', 'completed')
  RETURNING id INTO v_to_transaction_id;

  RETURN jsonb_build_object(
    'success', true,
    'from_transaction_id', v_from_transaction_id,
    'to_transaction_id', v_to_transaction_id,
    'from_previous_balance', v_from_balance,
    'from_new_balance', v_from_new_balance,
    'to_previous_balance', v_to_balance,
    'to_new_balance', v_to_new_balance,
    'super_user_bypass', v_is_super_user
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION public.safe_ledger_insert(p_user_id uuid, p_session_id uuid, p_entry_type text, p_debit numeric, p_credit numeric, p_rate numeric, p_duration_seconds integer, p_counterparty_id uuid, p_ref_key text, p_description text, p_timestamp timestamp with time zone)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_wallet_id uuid;
  v_amount numeric(12,2);
  v_type text;
  v_session_type text;
  v_balance_before numeric(12,2);
  v_balance_after numeric(12,2);
  v_idem text;
BEGIN
  v_idem := COALESCE(NULLIF(p_ref_key,''), gen_random_uuid()::text);
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem)
     OR EXISTS (SELECT 1 FROM public.wallet_transactions_archive WHERE idempotency_key = v_idem) THEN
    RETURN;
  END IF;

  v_amount := COALESCE(NULLIF(p_debit,0), p_credit, 0);
  IF v_amount = 0 OR v_user_id IS NULL THEN RETURN; END IF;
  v_type := CASE WHEN COALESCE(p_debit,0) > 0 THEN 'debit' ELSE 'credit' END;

  v_session_type := CASE
    WHEN p_entry_type ILIKE 'chat%'  THEN 'chat'
    WHEN p_entry_type ILIKE 'audio%' THEN 'audio_call'
    WHEN p_entry_type ILIKE 'video%' THEN 'video_call'
    WHEN p_entry_type ILIKE 'group%' THEN 'private_group_call'
    WHEN p_entry_type ILIKE 'gift%'  THEN 'gift'
    WHEN p_entry_type ILIKE 'tip%'   THEN 'tip'
    ELSE 'other' END;

  v_wallet_id := public.ensure_canonical_wallet(v_user_id, NULL);
  v_balance_before := public.canonical_wallet_balance(v_user_id);
  v_balance_after := (v_balance_before + CASE WHEN v_type='credit' THEN v_amount ELSE -v_amount END)::numeric(12,2);
  IF v_balance_after < 0 THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, session_type, session_id,
    amount, balance_after, duration_seconds, rate_per_minute,
    description, reference_id, idempotency_key, status, created_at
  ) VALUES (
    v_wallet_id, v_user_id, v_type, p_entry_type, v_session_type, p_session_id,
    v_amount, v_balance_after, p_duration_seconds, p_rate,
    p_description, v_idem, v_idem, 'completed', COALESCE(p_timestamp, now())
  ) ON CONFLICT (idempotency_key) DO NOTHING;
EXCEPTION WHEN unique_violation THEN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.reconcile_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_current_balance numeric := 0;
  v_computed_balance numeric := 0;
  v_diff numeric := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Missing user_id');
  END IF;

  IF auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_user_id
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Not allowed to reconcile this wallet';
  END IF;

  SELECT COALESCE(w.balance, 0) INTO v_current_balance
  FROM public.wallets w WHERE w.user_id = v_user_id;

  v_computed_balance := public.sync_wallet_balance_from_ledger(v_user_id);
  v_diff := v_current_balance - v_computed_balance;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'previous_balance', v_current_balance,
    'computed_balance', v_computed_balance,
    'difference', v_diff,
    'wallet_balance', v_computed_balance,
    'in_sync', true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_billing_seconds_for_month(_user_id uuid, _month text)
RETURNS bigint
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(_user_id);
  v_start timestamptz;
  v_end   timestamptz;
  v_total bigint := 0;
BEGIN
  v_start := (to_timestamp(_month || '-01', 'YYYY-MM-DD') AT TIME ZONE 'Asia/Kolkata');
  v_end   := v_start + interval '1 month';

  SELECT COALESCE(SUM(duration_seconds), 0)::bigint
    INTO v_total
  FROM (
    SELECT transaction_type, amount, duration_seconds, created_at, status FROM public.wallet_transactions WHERE user_id = v_user_id
    UNION ALL
    SELECT transaction_type, amount, duration_seconds, created_at, status FROM public.wallet_transactions_archive WHERE user_id = v_user_id
  ) u
  WHERE u.status = 'completed'
    AND u.transaction_type = 'session_earning'
    AND u.amount > 0
    AND COALESCE(u.duration_seconds, 0) > 0
    AND u.created_at >= v_start
    AND u.created_at <  v_end;

  RETURN v_total;
END;
$$;

CREATE OR REPLACE FUNCTION public.query_wallet_transactions_unified(p_user_id uuid, p_include_archive boolean DEFAULT false, p_limit integer DEFAULT 500)
RETURNS TABLE(id uuid, user_id uuid, type text, amount numeric, description text, reference_id text, status text, created_at timestamp with time zone, session_type text, transaction_type text, balance_after numeric, duration_seconds integer, rate_per_minute numeric, billing_metadata jsonb, source text)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT id, user_id, type, amount, description, reference_id, status,
         created_at, session_type, transaction_type, balance_after,
         duration_seconds, rate_per_minute, billing_metadata, source
  FROM (
    SELECT wt.id, wt.user_id, wt.type, wt.amount, wt.description, wt.reference_id, wt.status,
           wt.created_at, wt.session_type, wt.transaction_type, wt.balance_after,
           wt.duration_seconds, wt.rate_per_minute, wt.billing_metadata, 'live'::text AS source
    FROM public.wallet_transactions wt
    WHERE wt.user_id = public.resolve_wallet_user_id(p_user_id)
    UNION ALL
    SELECT wa.id, wa.user_id, wa.type, wa.amount, wa.description, wa.reference_id, wa.status,
           wa.created_at, wa.session_type, wa.transaction_type, wa.balance_after,
           wa.duration_seconds, wa.rate_per_minute, wa.billing_metadata, 'archive'::text AS source
    FROM public.wallet_transactions_archive wa
    WHERE p_include_archive = true AND wa.user_id = public.resolve_wallet_user_id(p_user_id)
  ) q
  ORDER BY created_at DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 5000);
$$;

-- Stronger SoT validator covers archive and key billing invariants.
CREATE OR REPLACE FUNCTION public.validate_financial_sot()
RETURNS TABLE(check_name text, status text, details text)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_neg int;
  v_null_idem int;
  v_dup int;
  v_unpaired int;
  v_bad_split int;
  v_bad_gift_tip int;
  v_mismatch int;
BEGIN
  SELECT COUNT(*) INTO v_neg FROM (
    SELECT balance_after FROM public.wallet_transactions WHERE balance_after < 0
    UNION ALL
    SELECT balance_after FROM public.wallet_transactions_archive WHERE balance_after < 0
  ) n;
  check_name:='no_negative_balances'; status:=CASE WHEN v_neg=0 THEN 'PASS' ELSE 'FAIL' END; details:='rows: '||v_neg; RETURN NEXT;

  SELECT COUNT(*) INTO v_null_idem FROM (
    SELECT idempotency_key FROM public.wallet_transactions WHERE idempotency_key IS NULL
    UNION ALL
    SELECT idempotency_key FROM public.wallet_transactions_archive WHERE idempotency_key IS NULL
  ) n;
  check_name:='idempotency_keys_present'; status:=CASE WHEN v_null_idem=0 THEN 'PASS' ELSE 'FAIL' END; details:='null rows: '||v_null_idem; RETURN NEXT;

  SELECT COUNT(*) INTO v_dup FROM (
    SELECT idempotency_key FROM (
      SELECT idempotency_key FROM public.wallet_transactions WHERE idempotency_key IS NOT NULL
      UNION ALL
      SELECT idempotency_key FROM public.wallet_transactions_archive WHERE idempotency_key IS NOT NULL
    ) x GROUP BY idempotency_key HAVING COUNT(*) > 1
  ) d;
  check_name:='no_duplicate_idempotency_live_archive'; status:=CASE WHEN v_dup=0 THEN 'PASS' ELSE 'FAIL' END; details:='duplicate keys: '||v_dup; RETURN NEXT;

  SELECT COUNT(*) INTO v_mismatch
  FROM public.wallets w
  WHERE ABS(COALESCE(w.balance,0) - public.canonical_wallet_balance(w.user_id)) > 0.01;
  check_name:='wallet_balance_matches_wallet_transactions'; status:=CASE WHEN v_mismatch=0 THEN 'PASS' ELSE 'FAIL' END; details:='mismatched wallets: '||v_mismatch; RETURN NEXT;

  SELECT COUNT(*) INTO v_unpaired
    FROM public.wallet_transactions c
   WHERE c.transaction_type='session_charge'
     AND c.created_at > now() - interval '30 days'
     AND NOT EXISTS (SELECT 1 FROM public.wallet_transactions e
       WHERE e.transaction_type='session_earning' AND e.session_id=c.session_id);
  check_name:='charge_earning_paired_30d'; status:=CASE WHEN v_unpaired=0 THEN 'PASS' ELSE 'WARN' END; details:='unpaired charges: '||v_unpaired; RETURN NEXT;

  SELECT COUNT(*) INTO v_bad_split FROM (
    SELECT c.session_id,
      SUM(CASE WHEN transaction_type='session_charge'  THEN amount END) AS chg,
      SUM(CASE WHEN transaction_type='session_earning' THEN amount END) AS ern
    FROM public.wallet_transactions c
    WHERE transaction_type IN ('session_charge','session_earning')
      AND created_at > now() - interval '30 days'
      AND COALESCE(session_type,'') IN ('chat','audio_call','video_call')
    GROUP BY c.session_id
  ) s WHERE s.chg IS NOT NULL AND s.ern IS NOT NULL
      AND ABS(s.ern - s.chg/2.0) > 0.05;
  check_name:='rev_share_50pct_1to1_30d'; status:=CASE WHEN v_bad_split=0 THEN 'PASS' ELSE 'FAIL' END; details:='mismatched 1:1 sessions: '||v_bad_split; RETURN NEXT;

  SELECT COUNT(*) INTO v_bad_gift_tip FROM (
    SELECT reference_id,
      SUM(CASE WHEN transaction_type IN ('gift_charge','tip_charge') THEN amount ELSE 0 END) AS charged,
      SUM(CASE WHEN transaction_type IN ('gift_earning','tip_earning') THEN amount ELSE 0 END) AS earned
    FROM public.wallet_transactions
    WHERE transaction_type IN ('gift_charge','tip_charge','gift_earning','tip_earning')
      AND created_at > now() - interval '30 days'
    GROUP BY reference_id
  ) s WHERE charged > 0 AND ABS(earned - charged/2.0) > 0.05;
  check_name:='gift_tip_50pct_woman_share_30d'; status:=CASE WHEN v_bad_gift_tip=0 THEN 'PASS' ELSE 'FAIL' END; details:='mismatched gift/tip refs: '||v_bad_gift_tip; RETURN NEXT;
END;
$$;

-- One-time reconciliation of every cached wallet balance to canonical ledger.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT user_id FROM public.wallets LOOP
    PERFORM public.sync_wallet_balance_from_ledger(r.user_id);
  END LOOP;
END $$;

GRANT EXECUTE ON FUNCTION public.canonical_wallet_balance(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sync_wallet_balance_from_ledger(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_session_balance(uuid, uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bill_session_minute(uuid, text, numeric, uuid, uuid, integer, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bill_gift_or_tip(uuid, uuid, numeric, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bill_group_gift_or_tip(uuid, uuid, numeric, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.validate_financial_sot() TO authenticated, service_role;