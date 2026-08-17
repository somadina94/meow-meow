-- Fix statement/billing identity mismatch and restore statement RPC access.
-- Canonical ledger user_id is auth user id. Some existing callers pass profiles.id;
-- normalize both forms inside DB functions so all rows land in wallet_transactions correctly.

CREATE OR REPLACE FUNCTION public.resolve_wallet_user_id(p_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT p.user_id FROM public.profiles p WHERE p.id = p_id LIMIT 1),
    p_id
  );
$$;

REVOKE ALL ON FUNCTION public.resolve_wallet_user_id(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_wallet_user_id(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_ledger_statement(
  p_user_id uuid,
  p_from_date text DEFAULT NULL::text,
  p_to_date text DEFAULT NULL::text
)
RETURNS TABLE(
  id uuid,
  session_id text,
  transaction_type text,
  debit numeric,
  credit numeric,
  description text,
  reference_id text,
  counterparty_id text,
  running_balance numeric,
  created_at timestamptz,
  duration_seconds integer,
  rate_per_minute numeric
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_from timestamptz;
  v_to timestamptz;
  v_opening_balance numeric := 0;
  v_archive_cutoff timestamptz := now() - interval '3 months';
  v_need_archive boolean;
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  IF auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_user_id
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Not allowed to view this statement';
  END IF;

  IF p_from_date IS NOT NULL THEN
    v_from := (p_from_date::date::timestamp AT TIME ZONE 'Asia/Kolkata');
  END IF;
  IF p_to_date IS NOT NULL THEN
    v_to := ((p_to_date::date + 1)::timestamp AT TIME ZONE 'Asia/Kolkata');
  END IF;

  v_need_archive := (v_from IS NULL) OR (v_from < v_archive_cutoff);

  IF v_from IS NOT NULL THEN
    SELECT GREATEST(COALESCE(SUM(CASE WHEN type='credit' THEN amount WHEN type='debit' THEN -amount ELSE 0 END), 0), 0)
    INTO v_opening_balance
    FROM (
      SELECT type, amount FROM public.wallet_transactions
        WHERE user_id = v_user_id AND status='completed' AND created_at < v_from
      UNION ALL
      SELECT type, amount FROM public.wallet_transactions_archive
        WHERE user_id = v_user_id AND status='completed' AND created_at < v_from
    ) prev;
  END IF;

  RETURN QUERY
  WITH unified AS (
    SELECT wt.id, wt.session_id, wt.type, wt.transaction_type, wt.amount,
           wt.description, wt.reference_id, wt.idempotency_key, wt.created_at,
           wt.duration_seconds, wt.rate_per_minute
    FROM public.wallet_transactions wt
    WHERE wt.user_id = v_user_id AND wt.status='completed'
      AND (v_from IS NULL OR wt.created_at >= v_from)
      AND (v_to IS NULL OR wt.created_at < v_to)
    UNION ALL
    SELECT wa.id, wa.session_id, wa.type, wa.transaction_type, wa.amount,
           wa.description, wa.reference_id, wa.idempotency_key, wa.created_at,
           wa.duration_seconds, wa.rate_per_minute
    FROM public.wallet_transactions_archive wa
    WHERE v_need_archive AND wa.user_id = v_user_id AND wa.status='completed'
      AND (v_from IS NULL OR wa.created_at >= v_from)
      AND (v_to IS NULL OR wa.created_at < v_to)
  ), filtered AS (
    SELECT u.id,
      u.session_id::text AS session_id,
      COALESCE(u.transaction_type, u.type)::text AS transaction_type,
      CASE WHEN u.type='debit' THEN u.amount ELSE 0::numeric END AS debit,
      CASE WHEN u.type='credit' THEN u.amount ELSE 0::numeric END AS credit,
      u.description,
      COALESCE(u.reference_id, u.idempotency_key)::text AS reference_id,
      NULL::text AS counterparty_id,
      u.created_at,
      COALESCE(u.duration_seconds,
        CASE WHEN u.rate_per_minute IS NOT NULL AND u.rate_per_minute > 0 AND u.amount > 0
             THEN ROUND((u.amount / u.rate_per_minute) * 60)::integer
             ELSE NULL END
      ) AS duration_seconds,
      u.rate_per_minute
    FROM unified u
  ), ordered AS (
    SELECT f.*,
      GREATEST(
        v_opening_balance + SUM(f.credit - f.debit) OVER (ORDER BY f.created_at, f.id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
        0
      )::numeric AS running_balance
    FROM filtered f
  )
  SELECT o.id, o.session_id, o.transaction_type, o.debit, o.credit,
         o.description, o.reference_id, o.counterparty_id, o.running_balance,
         o.created_at, o.duration_seconds, o.rate_per_minute
  FROM ordered o
  ORDER BY o.created_at DESC, o.id DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_men_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
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

  RETURN jsonb_build_object('balance', v_balance, 'currency', COALESCE(v_currency, 'INR'), 'total_recharges', v_recharges, 'total_spending', v_spending);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
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

CREATE OR REPLACE FUNCTION public.women_ledger_balance(p_woman_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT GREATEST(COALESCE(SUM(
    CASE WHEN type='credit' THEN amount WHEN type='debit' THEN -amount ELSE 0 END
  ), 0), 0)::numeric(12,2)
  FROM (
    SELECT type, amount FROM public.wallet_transactions
      WHERE user_id = public.resolve_wallet_user_id(p_woman_id) AND status='completed'
    UNION ALL
    SELECT type, amount FROM public.wallet_transactions_archive
      WHERE user_id = public.resolve_wallet_user_id(p_woman_id) AND status='completed'
  ) t;
$$;

CREATE OR REPLACE FUNCTION public.bill_session_minute(
  p_session_id uuid,
  p_session_type text,
  p_minutes numeric,
  p_man_id uuid,
  p_woman_id uuid,
  p_man_count integer DEFAULT 1,
  p_minute_index integer DEFAULT NULL::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pricing jsonb;
  v_man_wallet RECORD;
  v_woman_wallet RECORD;
  v_man_id uuid := public.resolve_wallet_user_id(p_man_id);
  v_woman_id uuid := public.resolve_wallet_user_id(p_woman_id);
  v_man_rate numeric(10,2);
  v_woman_rate numeric(10,2);
  v_charge numeric(10,2);
  v_earn numeric(10,2);
  v_man_balance_after numeric(10,2);
  v_woman_balance_after numeric(10,2);
  v_idem_key text;
  v_idem_earn text;
  v_is_super boolean := false;
  v_minute_idx integer;
  v_label text;
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

  IF auth.role() <> 'service_role' AND auth.uid() IS DISTINCT FROM v_man_id AND NOT public.has_role(auth.uid(), 'admin') THEN
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
  v_label  := initcap(replace(p_session_type,'_',' '));

  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = v_man_id AND role IN ('admin','super_user')) INTO v_is_super;

  IF NOT v_is_super THEN
    SELECT * INTO v_man_wallet FROM public.wallets WHERE user_id = v_man_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success',false,'error','Wallet not found');
    END IF;
    IF v_man_wallet.balance < v_charge THEN
      RETURN jsonb_build_object('success',false,'error','Insufficient balance','balance',v_man_wallet.balance,'required',v_charge);
    END IF;
    v_man_balance_after := v_man_wallet.balance - v_charge;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type, session_id,
      amount, balance_after, duration_seconds, rate_per_minute,
      description, idempotency_key, status
    ) VALUES (
      v_man_wallet.id, v_man_id, 'debit', p_session_type, p_session_type, p_session_id,
      v_charge, v_man_balance_after, ROUND(p_minutes * 60)::int, v_man_rate,
      v_label || ' — ' || p_minutes || ' min @ ₹' || v_man_rate || '/min',
      v_idem_key, 'completed'
    );

    UPDATE public.wallets SET balance = v_man_balance_after, updated_at = now() WHERE id = v_man_wallet.id;
  END IF;

  IF v_earn > 0 THEN
    SELECT * INTO v_woman_wallet FROM public.wallets WHERE user_id = v_woman_id FOR UPDATE;
    IF NOT FOUND THEN
      INSERT INTO public.wallets (user_id, gender, balance, currency)
      VALUES (v_woman_id, 'female', 0, 'INR')
      RETURNING * INTO v_woman_wallet;
    END IF;
    v_woman_balance_after := v_woman_wallet.balance + v_earn;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type, session_id,
      amount, balance_after, duration_seconds, rate_per_minute,
      description, idempotency_key, status
    ) VALUES (
      v_woman_wallet.id, v_woman_id, 'credit', p_session_type || '_earning', p_session_type, p_session_id,
      v_earn, v_woman_balance_after, ROUND(p_minutes * 60)::int, v_woman_rate,
      v_label || ' earnings — ' || p_minutes || ' min @ ₹' || v_woman_rate || '/min',
      v_idem_earn, 'completed'
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    UPDATE public.wallets SET balance = v_woman_balance_after, updated_at = now() WHERE id = v_woman_wallet.id;
  END IF;

  RETURN jsonb_build_object('success',true,'session_type',p_session_type,'charged',CASE WHEN v_is_super THEN 0 ELSE v_charge END,'earned',v_earn,'man_rate',v_man_rate,'woman_rate',v_woman_rate,'minutes',p_minutes,'super_user_skip',v_is_super,'minute_index',v_minute_idx);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
END;
$$;

CREATE OR REPLACE FUNCTION public.bill_gift_or_tip(
  p_man_id uuid,
  p_woman_id uuid,
  p_amount numeric,
  p_type text,
  p_description text DEFAULT NULL::text,
  p_reference_id text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pricing jsonb; v_man_wallet RECORD; v_woman_wallet RECORD;
  v_man_id uuid := public.resolve_wallet_user_id(p_man_id);
  v_woman_id uuid := public.resolve_wallet_user_id(p_woman_id);
  v_pct numeric(5,2); v_woman_credit numeric(10,2);
  v_man_balance_after numeric(10,2); v_woman_balance_after numeric(10,2);
  v_is_super boolean := false;
  v_idem_man text;
  v_idem_woman text;
  v_ref text;
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

  IF auth.role() <> 'service_role' AND auth.uid() IS DISTINCT FROM v_man_id AND NOT public.has_role(auth.uid(), 'admin') THEN
    RETURN jsonb_build_object('success',false,'error','Not allowed to bill for this user');
  END IF;

  v_ref := COALESCE(NULLIF(p_reference_id, ''), gen_random_uuid()::text);
  v_idem_man   := p_type || '|' || v_man_id::text || '|' || v_woman_id::text || '|' || v_ref;
  v_idem_woman := p_type || '_earn|' || v_woman_id::text || '|' || v_man_id::text || '|' || v_ref;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_man)
     OR EXISTS (SELECT 1 FROM public.wallet_transactions_archive WHERE idempotency_key = v_idem_man) THEN
    RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
  END IF;

  v_pricing := public.get_unified_pricing();
  v_pct := CASE p_type WHEN 'gift' THEN (v_pricing->>'gift_woman_pct')::numeric ELSE (v_pricing->>'tip_woman_pct')::numeric END;
  v_woman_credit := ROUND(p_amount * v_pct / 100.0, 2);

  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = v_man_id AND role IN ('admin','super_user')) INTO v_is_super;

  IF NOT v_is_super THEN
    SELECT * INTO v_man_wallet FROM public.wallets WHERE user_id = v_man_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success',false,'error','Wallet not found');
    END IF;
    IF v_man_wallet.balance < p_amount THEN
      RETURN jsonb_build_object('success',false,'error','Insufficient balance','balance',v_man_wallet.balance,'required',p_amount);
    END IF;
    v_man_balance_after := v_man_wallet.balance - p_amount;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type,
      amount, balance_after, description, reference_id, idempotency_key, status
    ) VALUES (
      v_man_wallet.id, v_man_id, 'debit', p_type, p_type,
      p_amount, v_man_balance_after,
      COALESCE(p_description, initcap(p_type) || ' sent — ₹' || p_amount),
      v_ref, v_idem_man, 'completed'
    );

    UPDATE public.wallets SET balance = v_man_balance_after, updated_at = now() WHERE id = v_man_wallet.id;
  END IF;

  IF v_woman_credit > 0 THEN
    SELECT * INTO v_woman_wallet FROM public.wallets WHERE user_id = v_woman_id FOR UPDATE;
    IF NOT FOUND THEN
      INSERT INTO public.wallets (user_id, gender, balance, currency)
      VALUES (v_woman_id, 'female', 0, 'INR')
      RETURNING * INTO v_woman_wallet;
    END IF;
    v_woman_balance_after := v_woman_wallet.balance + v_woman_credit;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type,
      amount, balance_after, description, reference_id, idempotency_key, status
    ) VALUES (
      v_woman_wallet.id, v_woman_id, 'credit', p_type || '_earning', p_type,
      v_woman_credit, v_woman_balance_after,
      COALESCE(p_description, initcap(p_type) || ' received — ' || v_pct || '% of ₹' || p_amount),
      v_ref, v_idem_woman, 'completed'
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    UPDATE public.wallets SET balance = v_woman_balance_after, updated_at = now() WHERE id = v_woman_wallet.id;
  END IF;

  RETURN jsonb_build_object('success',true,'type',p_type,'charged',CASE WHEN v_is_super THEN 0 ELSE p_amount END,'woman_credit',v_woman_credit,'woman_pct',v_pct,'idempotency_key',v_idem_man);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
END;
$$;

CREATE OR REPLACE FUNCTION public.ledger_withdrawal(p_user_id uuid, p_amount numeric, p_payment_method text DEFAULT 'upi'::text, p_payment_details jsonb DEFAULT NULL::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_wallet RECORD;
  v_pending numeric := 0;
  v_available numeric;
  v_min_withdrawal numeric := 100;
  v_request_id uuid;
  v_fee_pct numeric := 5.00;
  v_fee_amount numeric;
  v_net_payout numeric;
  v_balance_after numeric;
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

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  SELECT COALESCE(SUM(amount),0) INTO v_pending
    FROM public.withdrawal_requests
    WHERE public.resolve_wallet_user_id(user_id) = v_user_id AND status = 'pending';
  v_available := v_wallet.balance - v_pending;

  IF p_amount < v_min_withdrawal THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum withdrawal is ₹' || v_min_withdrawal);
  END IF;
  IF p_amount > v_available THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance. Available: ₹' || v_available);
  END IF;

  v_fee_amount := ROUND(p_amount * v_fee_pct / 100.0, 2);
  v_net_payout := p_amount - v_fee_amount;
  v_balance_after := v_wallet.balance - p_amount;

  INSERT INTO public.withdrawal_requests (user_id, amount, payment_method, payment_details, status)
  VALUES (v_user_id, v_net_payout, p_payment_method, p_payment_details, 'pending')
  RETURNING id INTO v_request_id;

  v_idem     := 'withdrawal|' || v_request_id::text;
  v_idem_fee := 'withdrawal_fee|' || v_request_id::text;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, session_type,
    amount, balance_after, description, reference_id, idempotency_key, status
  ) VALUES (
    v_wallet.id, v_user_id, 'debit', 'withdrawal', 'wallet',
    v_net_payout, v_balance_after,
    'Withdrawal payout (₹' || p_amount || ' − ' || v_fee_pct || '% fee ₹' || v_fee_amount || ')',
    v_request_id::text, v_idem, 'completed'
  );

  IF v_fee_amount > 0 THEN
    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type,
      amount, balance_after, description, reference_id, idempotency_key, status
    ) VALUES (
      v_wallet.id, v_user_id, 'debit', 'withdrawal_fee', 'wallet',
      v_fee_amount, v_balance_after,
      'Withdrawal platform fee (' || v_fee_pct || '% of ₹' || p_amount || ')',
      v_request_id::text, v_idem_fee, 'completed'
    );
  END IF;

  UPDATE public.wallets SET balance = v_balance_after, updated_at = now() WHERE id = v_wallet.id;

  RETURN jsonb_build_object('success', true, 'request_id', v_request_id, 'requested_amount', p_amount, 'fee_percent', v_fee_pct, 'fee_amount', v_fee_amount, 'net_payout', v_net_payout, 'available_balance', v_available - p_amount, 'new_balance', v_balance_after);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Monthly payout / admin summaries must match profiles through auth user_id.
CREATE OR REPLACE FUNCTION public.admin_list_statements(p_gender text DEFAULT NULL::text, p_year integer DEFAULT NULL::integer, p_month integer DEFAULT NULL::integer, p_payout_status text DEFAULT NULL::text, p_user_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0)
RETURNS TABLE(statement_id uuid, user_id uuid, full_name text, gender text, year integer, month integer, opening_balance numeric, total_credit numeric, total_debit numeric, closing_balance numeric, chat_amount numeric, audio_call_amount numeric, video_call_amount numeric, group_call_amount numeric, gift_amount numeric, tip_amount numeric, recharge_amount numeric, payout_amount numeric, payout_status text, pdf_url text, excel_url text, generated_at timestamptz, paid_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_filter uuid := public.resolve_wallet_user_id(p_user_id);
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;
  RETURN QUERY
    SELECT ms.id, ms.user_id, p.full_name, ms.gender,
           ms.year, ms.month, ms.opening_balance, ms.total_credit,
           ms.total_debit, ms.closing_balance, ms.chat_amount,
           ms.audio_call_amount, ms.video_call_amount, ms.group_call_amount,
           ms.gift_amount, ms.tip_amount, ms.recharge_amount,
           ms.payout_amount, ms.payout_status, ms.pdf_url, ms.excel_url,
           ms.generated_at, ms.paid_at
    FROM public.monthly_statements ms
    LEFT JOIN public.profiles p ON p.user_id = ms.user_id
    WHERE (p_gender IS NULL OR ms.gender = p_gender)
      AND (p_year IS NULL OR ms.year = p_year)
      AND (p_month IS NULL OR ms.month = p_month)
      AND (p_payout_status IS NULL OR ms.payout_status = p_payout_status)
      AND (v_user_filter IS NULL OR ms.user_id = v_user_filter)
    ORDER BY ms.year DESC, ms.month DESC, ms.payout_amount DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

REVOKE ALL ON FUNCTION public.get_ledger_statement(uuid,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_men_wallet_balance(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_women_wallet_balance(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.women_ledger_balance(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.bill_session_minute(uuid,text,numeric,uuid,uuid,integer,integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.bill_gift_or_tip(uuid,uuid,numeric,text,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.ledger_withdrawal(uuid,numeric,text,jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_statements(text,integer,integer,text,uuid,integer,integer) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_ledger_statement(uuid,text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_men_wallet_balance(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_women_wallet_balance(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.women_ledger_balance(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bill_session_minute(uuid,text,numeric,uuid,uuid,integer,integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bill_gift_or_tip(uuid,uuid,numeric,text,text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ledger_withdrawal(uuid,numeric,text,jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_statements(text,integer,integer,text,uuid,integer,integer) TO authenticated, service_role;

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_status_created
  ON public.wallet_transactions(user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_archive_user_status_created
  ON public.wallet_transactions_archive(user_id, status, created_at DESC);