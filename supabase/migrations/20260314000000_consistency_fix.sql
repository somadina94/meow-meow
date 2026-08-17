-- =============================================================================
-- CONSISTENCY FIX MIGRATION
-- Generated: 2026-03-14
-- Fixes all gaps between TypeScript code and Supabase database schema.
--
-- ISSUES FIXED:
--   A. 5 missing tables:
--        users_wallet, wallet_recharges, monthly_wallet_summary,
--        platform_metrics, group_video_access
--   B. 14 missing RPC functions:
--        ledger_recharge, ledger_bill_session, ledger_bill_group_call,
--        ledger_withdrawal, get_ledger_statement,
--        update_daily_platform_metrics, sweep_stale_statuses,
--        revert_busy_to_online, rotate_monthly_shifts,
--        migrate_existing_wallets_to_ledger,
--        cleanup_chat_media, cleanup_idle_sessions,
--        cleanup_video_sessions, expire_group_video_access
--   C. check_session_balance: TS sends p_session_type but DB expects p_session_id
--        → fixed to accept both signatures
--   D. wallet_transactions: missing columns transaction_type, balance_after,
--        session_id, idempotency_key (already added in previous migration but
--        re-ensured here with IF NOT EXISTS)
--   E. wallets / users_wallet duality → users_wallet is now a view over wallets
--        so both .from('wallets') and .from('users_wallet') work identically
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- A1. users_wallet — needed by ledger-wallet.service.ts
--     Implemented as a VIEW over the existing wallets table so both
--     .from('wallets') and .from('users_wallet') work transparently.
-- ─────────────────────────────────────────────────────────────────────────────

-- Ensure wallets has the gender column (users_wallet type includes it)
ALTER TABLE public.wallets ADD COLUMN IF NOT EXISTS gender text DEFAULT 'male';

-- Create users_wallet as a view so ledger-wallet.service can use it
DROP VIEW IF EXISTS public.users_wallet;
CREATE OR REPLACE VIEW public.users_wallet AS
  SELECT
    id,
    user_id,
    balance,
    currency,
    gender,
    created_at,
    updated_at
  FROM public.wallets;

-- Allow authenticated users to select their own row via the view
DROP POLICY IF EXISTS "users_wallet_select_own" ON public.wallets;
CREATE POLICY "users_wallet_select_own" ON public.wallets
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- A2. wallet_recharges — used by ledger-wallet.service getRechargeHistory()
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.wallet_recharges (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount                numeric(12,2) NOT NULL,
  payment_gateway       text        NOT NULL DEFAULT 'razorpay',
  gateway_transaction_id text,
  status                text        NOT NULL DEFAULT 'pending'
                                    CHECK (status IN ('pending','success','failed')),
  description           text,
  created_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.wallet_recharges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallet_recharges_own_select" ON public.wallet_recharges;
CREATE POLICY "wallet_recharges_own_select" ON public.wallet_recharges
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "wallet_recharges_admin_all" ON public.wallet_recharges;
CREATE POLICY "wallet_recharges_admin_all" ON public.wallet_recharges
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));

CREATE INDEX IF NOT EXISTS idx_wallet_recharges_user ON public.wallet_recharges(user_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- A3. monthly_wallet_summary — used by ledger-wallet.service getMonthlyWalletSummary()
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.monthly_wallet_summary (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  month             integer     NOT NULL CHECK (month BETWEEN 1 AND 12),
  year              integer     NOT NULL,
  opening_balance   numeric(12,2) NOT NULL DEFAULT 0,
  total_credit      numeric(12,2) NOT NULL DEFAULT 0,
  total_debit       numeric(12,2) NOT NULL DEFAULT 0,
  withdrawals       numeric(12,2) NOT NULL DEFAULT 0,
  closing_balance   numeric(12,2) NOT NULL DEFAULT 0,
  forwarded_balance numeric(12,2) NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, year, month)
);

ALTER TABLE public.monthly_wallet_summary ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "monthly_wallet_summary_own" ON public.monthly_wallet_summary;
CREATE POLICY "monthly_wallet_summary_own" ON public.monthly_wallet_summary
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "monthly_wallet_summary_admin" ON public.monthly_wallet_summary;
CREATE POLICY "monthly_wallet_summary_admin" ON public.monthly_wallet_summary
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));

CREATE INDEX IF NOT EXISTS idx_monthly_wallet_summary_user ON public.monthly_wallet_summary(user_id, year DESC, month DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- A4. platform_metrics — used by admin.service and AdminFinanceDashboard
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.platform_metrics (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_date           date        NOT NULL DEFAULT CURRENT_DATE,
  total_users           integer     NOT NULL DEFAULT 0,
  active_users          integer     NOT NULL DEFAULT 0,
  male_users            integer     NOT NULL DEFAULT 0,
  female_users          integer     NOT NULL DEFAULT 0,
  new_users             integer     NOT NULL DEFAULT 0,
  total_chats           integer     NOT NULL DEFAULT 0,
  active_chats          integer     NOT NULL DEFAULT 0,
  total_messages        integer     NOT NULL DEFAULT 0,
  total_matches         integer     NOT NULL DEFAULT 0,
  total_video_calls     integer     NOT NULL DEFAULT 0,
  video_call_minutes    integer     NOT NULL DEFAULT 0,
  video_call_revenue    numeric(12,2) NOT NULL DEFAULT 0,
  men_recharges         numeric(12,2) NOT NULL DEFAULT 0,
  men_spent             numeric(12,2) NOT NULL DEFAULT 0,
  women_earnings        numeric(12,2) NOT NULL DEFAULT 0,
  gift_revenue          numeric(12,2) NOT NULL DEFAULT 0,
  admin_profit          numeric(12,2) NOT NULL DEFAULT 0,
  pending_withdrawals   numeric(12,2) NOT NULL DEFAULT 0,
  completed_withdrawals numeric(12,2) NOT NULL DEFAULT 0,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (metric_date)
);

ALTER TABLE public.platform_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "platform_metrics_admin_only" ON public.platform_metrics;
CREATE POLICY "platform_metrics_admin_only" ON public.platform_metrics
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));

CREATE INDEX IF NOT EXISTS idx_platform_metrics_date ON public.platform_metrics(metric_date DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- A5. group_video_access — used by private group video gifting flow
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.group_video_access (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id          uuid        NOT NULL REFERENCES public.private_groups(id) ON DELETE CASCADE,
  user_id           uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  gift_id           uuid        REFERENCES public.gifts(id),
  gift_amount       numeric(12,2) NOT NULL DEFAULT 0,
  is_active         boolean     NOT NULL DEFAULT true,
  access_granted_at timestamptz NOT NULL DEFAULT now(),
  access_expires_at timestamptz NOT NULL DEFAULT (now() + interval '1 hour'),
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (group_id, user_id)
);

ALTER TABLE public.group_video_access ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "group_video_access_own" ON public.group_video_access;
CREATE POLICY "group_video_access_own" ON public.group_video_access
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "group_video_access_admin" ON public.group_video_access;
CREATE POLICY "group_video_access_admin" ON public.group_video_access
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));

CREATE INDEX IF NOT EXISTS idx_group_video_access_group ON public.group_video_access(group_id, is_active);
CREATE INDEX IF NOT EXISTS idx_group_video_access_user ON public.group_video_access(user_id, is_active);

-- ─────────────────────────────────────────────────────────────────────────────
-- B. wallet_transactions: add missing columns (safe with IF NOT EXISTS)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.wallet_transactions
  ADD COLUMN IF NOT EXISTS transaction_type text,
  ADD COLUMN IF NOT EXISTS balance_after     numeric(12,2),
  ADD COLUMN IF NOT EXISTS session_id        uuid,
  ADD COLUMN IF NOT EXISTS idempotency_key   text;

ALTER TABLE public.wallet_transactions ALTER COLUMN wallet_id DROP NOT NULL;

-- Back-fill transaction_type from type for pre-existing rows
UPDATE public.wallet_transactions
SET transaction_type = COALESCE(transaction_type, type)
WHERE transaction_type IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_txn_idempotency
  ON public.wallet_transactions (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- C. check_session_balance — fix argument mismatch
--    types.ts has: { p_session_id, p_user_id }
--    ledger-wallet.service.ts sends: { p_user_id, p_session_type }
--    Fix: accept both, use p_session_type when p_session_id is null
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.check_session_balance(
  p_user_id    uuid,
  p_session_id uuid    DEFAULT NULL,
  p_session_type text  DEFAULT 'chat'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance    numeric := 0;
  v_pricing    RECORD;
  v_min_needed numeric;
BEGIN
  SELECT COALESCE(balance, 0) INTO v_balance
  FROM public.wallets WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('sufficient', false, 'balance', 0, 'required', 4, 'shortfall', 4,
                              'has_balance', false, 'error', 'Wallet not found');
  END IF;

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;

  v_min_needed := CASE p_session_type
    WHEN 'video_call'         THEN COALESCE(v_pricing.video_rate_per_minute, 8)
    WHEN 'private_group_call' THEN COALESCE(v_pricing.group_call_rate_per_minute, 4)
    ELSE                           COALESCE(v_pricing.rate_per_minute, 4)
  END;

  RETURN jsonb_build_object(
    'sufficient',   v_balance >= v_min_needed,
    'has_balance',  v_balance >= v_min_needed,
    'balance',      v_balance,
    'required',     v_min_needed,
    'shortfall',    GREATEST(v_min_needed - v_balance, 0),
    'min_required', v_min_needed
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('sufficient', false, 'has_balance', false, 'balance', 0,
                            'required', 4, 'shortfall', 4, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_session_balance(uuid, uuid, text) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- D. ledger_recharge — used by ledger-wallet.service.ts rechargeWallet()
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ledger_recharge(
  p_user_id        uuid,
  p_amount         numeric,
  p_gateway        text    DEFAULT 'razorpay',
  p_gateway_txn_id text    DEFAULT NULL,
  p_description    text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_id   uuid;
  v_old_balance numeric;
  v_new_balance numeric;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
  END IF;

  SELECT id, balance INTO v_wallet_id, v_old_balance
  FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.wallets (user_id, balance, currency)
    VALUES (p_user_id, 0, 'INR')
    RETURNING id, balance INTO v_wallet_id, v_old_balance;
  END IF;

  v_new_balance := v_old_balance + p_amount;

  UPDATE public.wallets SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  -- Record in wallet_transactions (admin audit)
  INSERT INTO public.wallet_transactions
    (user_id, type, transaction_type, amount, description, balance_after, status, created_at)
  VALUES
    (p_user_id, 'credit', 'recharge', p_amount,
     COALESCE(p_description, 'Wallet recharge via ' || p_gateway),
     v_new_balance, 'completed', now());

  -- Record in wallet_recharges
  INSERT INTO public.wallet_recharges
    (user_id, amount, payment_gateway, gateway_transaction_id, status, description)
  VALUES
    (p_user_id, p_amount, p_gateway, p_gateway_txn_id, 'success',
     COALESCE(p_description, 'Recharge'));

  RETURN jsonb_build_object(
    'success', true,
    'previous_balance', v_old_balance,
    'new_balance', v_new_balance,
    'amount_recharged', p_amount
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.ledger_recharge(uuid, numeric, text, text, text) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- E. ledger_bill_session — used by ledger-wallet.service.ts billSessionMinute()
--    Bills one man, credits Indian woman exactly half. Idempotent by minute_number.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ledger_bill_session(
  p_session_id   uuid,
  p_session_type text,
  p_man_id       uuid,
  p_woman_id     uuid,
  p_minute_number integer,
  p_man_charge   numeric DEFAULT 4,
  p_woman_earn   numeric DEFAULT 2
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_idem_key      text;
  v_man_wallet_id uuid;
  v_man_balance   numeric;
  v_woman_wallet  uuid;
  v_woman_indian  boolean := false;
BEGIN
  -- Idempotency key prevents duplicate minute billing
  v_idem_key := p_session_type || ':' || p_session_id::text || ':min:' || p_minute_number::text;
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'idempotency_key', v_idem_key);
  END IF;

  -- Check if woman is Indian (only Indian women earn)
  SELECT COALESCE(fp.is_indian, pr.is_indian, false) INTO v_woman_indian
  FROM public.profiles pr
  LEFT JOIN public.female_profiles fp ON fp.user_id = pr.user_id
  WHERE pr.user_id = p_woman_id;

  -- Validate half-rule
  IF v_woman_indian AND ROUND(p_woman_earn, 2) <> ROUND(p_man_charge / 2.0, 2) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Half-rule violation: woman_earn must equal man_charge/2');
  END IF;

  -- Lock and check man's wallet
  SELECT id, balance INTO v_man_wallet_id, v_man_balance
  FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;

  IF v_man_balance IS NULL OR v_man_balance < p_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance',
                              'balance', COALESCE(v_man_balance, 0), 'required', p_man_charge);
  END IF;

  -- Debit man
  UPDATE public.wallets SET balance = balance - p_man_charge, updated_at = now()
  WHERE id = v_man_wallet_id;

  INSERT INTO public.wallet_transactions
    (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status)
  VALUES
    (p_man_id, 'debit', 'debit', p_man_charge,
     initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_man_charge || '/min',
     p_session_id, (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id),
     v_idem_key, 'completed');

  -- Credit woman (Indian only)
  IF v_woman_indian AND p_woman_earn > 0 THEN
    SELECT id INTO v_woman_wallet FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF v_woman_wallet IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + p_woman_earn, updated_at = now()
      WHERE id = v_woman_wallet;
    END IF;
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, created_at)
    VALUES (p_woman_id, p_woman_earn, p_session_type,
            initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number ||
            ' @ ₹' || p_woman_earn || '/min (½ of ₹' || p_man_charge || ')', now());
  END IF;

  RETURN jsonb_build_object(
    'success', true, 'charged', p_man_charge, 'earned', CASE WHEN v_woman_indian THEN p_woman_earn ELSE 0 END,
    'minute_number', p_minute_number, 'idempotency_key', v_idem_key
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.ledger_bill_session(uuid, text, uuid, uuid, integer, numeric, numeric) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- F. ledger_bill_group_call — used by ledger-wallet.service.ts billGroupCallMinute()
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ledger_bill_group_call(
  p_session_id     uuid,
  p_woman_id       uuid,
  p_man_ids        uuid[],
  p_minute_number  integer,
  p_charge_per_man numeric DEFAULT 4,
  p_earn_per_man   numeric DEFAULT 2
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_man_id        uuid;
  v_wallet        RECORD;
  v_woman_wallet  uuid;
  v_idem_key      text;
  v_man_idem_key  text;
  v_total_charged numeric := 0;
  v_total_earned  numeric := 0;
  v_billed        uuid[]  := '{}';
  v_failed        uuid[]  := '{}';
BEGIN
  -- Group-level idempotency
  v_idem_key := 'grp:' || p_session_id::text || ':min:' || p_minute_number::text;
  IF EXISTS (SELECT 1 FROM public.women_earnings
             WHERE user_id = p_woman_id
               AND description LIKE '%min ' || p_minute_number || ' group ' || p_session_id::text || '%') THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
  END IF;

  SELECT id INTO v_woman_wallet FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;

  FOREACH v_man_id IN ARRAY p_man_ids LOOP
    v_man_idem_key := v_idem_key || ':man:' || v_man_id::text;
    IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_man_idem_key) THEN
      CONTINUE;
    END IF;

    SELECT id, balance INTO v_wallet FROM public.wallets WHERE user_id = v_man_id FOR UPDATE;
    IF v_wallet.balance IS NULL OR v_wallet.balance < p_charge_per_man THEN
      v_failed := array_append(v_failed, v_man_id);
      CONTINUE;
    END IF;

    UPDATE public.wallets SET balance = balance - p_charge_per_man, updated_at = now()
    WHERE id = v_wallet.id;

    INSERT INTO public.wallet_transactions
      (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status)
    VALUES
      (v_man_id, 'debit', 'debit', p_charge_per_man,
       'Group call: min ' || p_minute_number || ' @ ₹' || p_charge_per_man || '/min',
       p_session_id, (SELECT balance FROM public.wallets WHERE id = v_wallet.id),
       v_man_idem_key, 'completed');

    v_total_charged := v_total_charged + p_charge_per_man;
    v_total_earned  := v_total_earned  + p_earn_per_man;
    v_billed        := array_append(v_billed, v_man_id);
  END LOOP;

  -- Validate half-rule then credit host
  IF array_length(v_billed, 1) > 0 THEN
    IF ROUND(v_total_charged / 2.0, 2) <> ROUND(v_total_earned, 2) THEN
      RAISE EXCEPTION 'Half-rule failed: charged=% earned=%', v_total_charged, v_total_earned;
    END IF;

    IF v_woman_wallet IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_total_earned, updated_at = now()
      WHERE id = v_woman_wallet;
    END IF;

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, created_at)
    VALUES (p_woman_id, v_total_earned, 'group_call',
            'Group call: ' || array_length(v_billed,1) || ' man(s) × ₹' || p_earn_per_man ||
            '/min = ₹' || v_total_earned || ' (½ of ₹' || v_total_charged ||
            ', min ' || p_minute_number || ' group ' || p_session_id::text || ')', now());
  END IF;

  RETURN jsonb_build_object(
    'success', true, 'billed_count', array_length(v_billed,1),
    'total_charged', v_total_charged, 'total_earned', v_total_earned,
    'billed_men', to_jsonb(v_billed), 'failed_men', to_jsonb(v_failed)
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.ledger_bill_group_call(uuid, uuid, uuid[], integer, numeric, numeric) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- G. ledger_withdrawal — used by ledger-wallet.service.ts requestLedgerWithdrawal()
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ledger_withdrawal(
  p_user_id        uuid,
  p_amount         numeric,
  p_payment_method text    DEFAULT 'upi',
  p_payment_details jsonb  DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_id          uuid;
  v_balance            numeric;
  v_pending            numeric := 0;
  v_available          numeric;
  v_min_withdrawal     numeric := 5000;
  v_request_id         uuid;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
  END IF;

  SELECT min_withdrawal_balance INTO v_min_withdrawal
  FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
  v_min_withdrawal := COALESCE(v_min_withdrawal, 5000);

  SELECT id, balance INTO v_wallet_id, v_balance
  FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_pending
  FROM public.withdrawal_requests WHERE user_id = p_user_id AND status = 'pending';

  v_available := v_balance - v_pending;

  IF v_available < v_min_withdrawal THEN
    RETURN jsonb_build_object('success', false, 'error',
      'Minimum withdrawal is ₹' || v_min_withdrawal || '. Available: ₹' || v_available);
  END IF;
  IF p_amount > v_available THEN
    RETURN jsonb_build_object('success', false, 'error',
      'Insufficient balance. Available: ₹' || v_available);
  END IF;

  INSERT INTO public.withdrawal_requests
    (user_id, amount, payment_method, payment_details, status)
  VALUES (p_user_id, p_amount, p_payment_method, p_payment_details, 'pending')
  RETURNING id INTO v_request_id;

  RETURN jsonb_build_object(
    'success', true, 'request_id', v_request_id,
    'amount', p_amount, 'available_balance', v_available - p_amount
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.ledger_withdrawal(uuid, numeric, text, jsonb) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- H. get_ledger_statement — used by ledger-wallet.service.ts getLedgerStatement()
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_ledger_statement(
  p_user_id   uuid,
  p_from_date text DEFAULT NULL,
  p_to_date   text DEFAULT NULL
)
RETURNS TABLE (
  id               text,
  session_id       text,
  transaction_type text,
  debit            numeric,
  credit           numeric,
  description      text,
  reference_id     text,
  counterparty_id  text,
  running_balance  numeric,
  created_at       timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from timestamptz := COALESCE(p_from_date::timestamptz, now() - interval '6 months');
  v_to   timestamptz := COALESCE(p_to_date::timestamptz,   now());
BEGIN
  RETURN QUERY
    SELECT
      wt.id::text,
      wt.session_id::text,
      COALESCE(wt.transaction_type, wt.type)::text,
      CASE WHEN COALESCE(wt.transaction_type, wt.type) IN ('debit','withdrawal')
           THEN wt.amount ELSE 0 END                              AS debit,
      CASE WHEN COALESCE(wt.transaction_type, wt.type) IN ('credit','recharge','refund')
           THEN wt.amount ELSE 0 END                              AS credit,
      wt.description,
      wt.reference_id::text,
      NULL::text                                                   AS counterparty_id,
      SUM(
        CASE WHEN COALESCE(wt.transaction_type, wt.type) IN ('credit','recharge','refund')
             THEN wt.amount
             ELSE -wt.amount END
      ) OVER (ORDER BY wt.created_at ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                                   AS running_balance,
      wt.created_at
    FROM public.wallet_transactions wt
    WHERE wt.user_id = p_user_id
      AND wt.created_at >= v_from
      AND wt.created_at <= v_to
    ORDER BY wt.created_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_ledger_statement(uuid, text, text) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- I. update_daily_platform_metrics — called by admin dashboard
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_daily_platform_metrics()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.platform_metrics (
    metric_date, total_users, active_users, male_users, female_users, new_users,
    total_chats, active_chats, total_messages, total_video_calls,
    men_recharges, men_spent, women_earnings, admin_profit,
    pending_withdrawals, completed_withdrawals, updated_at
  )
  SELECT
    CURRENT_DATE,
    (SELECT count(*) FROM public.profiles)::integer,
    (SELECT count(*) FROM public.user_status WHERE is_online = true)::integer,
    (SELECT count(*) FROM public.profiles WHERE gender = 'male')::integer,
    (SELECT count(*) FROM public.profiles WHERE gender = 'female')::integer,
    (SELECT count(*) FROM public.profiles WHERE created_at >= CURRENT_DATE)::integer,
    (SELECT count(*) FROM public.active_chat_sessions WHERE created_at >= CURRENT_DATE)::integer,
    (SELECT count(*) FROM public.active_chat_sessions WHERE status = 'active')::integer,
    (SELECT count(*) FROM public.chat_messages WHERE created_at >= CURRENT_DATE)::integer,
    (SELECT count(*) FROM public.video_call_sessions WHERE created_at >= CURRENT_DATE)::integer,
    COALESCE((SELECT SUM(amount) FROM public.wallet_recharges WHERE status = 'success' AND created_at >= CURRENT_DATE), 0),
    COALESCE((SELECT SUM(amount) FROM public.wallet_transactions WHERE COALESCE(transaction_type,type) IN ('debit','withdrawal') AND created_at >= CURRENT_DATE), 0),
    COALESCE((SELECT SUM(amount) FROM public.women_earnings WHERE created_at >= CURRENT_DATE), 0),
    COALESCE((SELECT SUM(amount) FROM public.wallet_transactions WHERE COALESCE(transaction_type,type) IN ('debit','withdrawal') AND created_at >= CURRENT_DATE), 0)
    - COALESCE((SELECT SUM(amount) FROM public.women_earnings WHERE created_at >= CURRENT_DATE), 0),
    COALESCE((SELECT SUM(amount) FROM public.withdrawal_requests WHERE status = 'pending'), 0),
    COALESCE((SELECT SUM(amount) FROM public.withdrawal_requests WHERE status IN ('approved','processed') AND updated_at >= CURRENT_DATE), 0),
    now()
  ON CONFLICT (metric_date) DO UPDATE SET
    total_users           = EXCLUDED.total_users,
    active_users          = EXCLUDED.active_users,
    male_users            = EXCLUDED.male_users,
    female_users          = EXCLUDED.female_users,
    new_users             = EXCLUDED.new_users,
    total_chats           = EXCLUDED.total_chats,
    active_chats          = EXCLUDED.active_chats,
    total_messages        = EXCLUDED.total_messages,
    total_video_calls     = EXCLUDED.total_video_calls,
    men_recharges         = EXCLUDED.men_recharges,
    men_spent             = EXCLUDED.men_spent,
    women_earnings        = EXCLUDED.women_earnings,
    admin_profit          = EXCLUDED.admin_profit,
    pending_withdrawals   = EXCLUDED.pending_withdrawals,
    completed_withdrawals = EXCLUDED.completed_withdrawals,
    updated_at            = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_daily_platform_metrics() TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- J. sweep_stale_statuses — referenced in types.ts (alias for sweep_stale_user_status)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sweep_stale_statuses()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_count integer;
BEGIN
  UPDATE public.user_status
  SET is_online = false, status = 'offline'
  WHERE is_online = true AND last_seen < now() - interval '5 minutes';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sweep_stale_statuses() TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- K. revert_busy_to_online — used in call flow
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.revert_busy_to_online(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.user_status
  SET status = 'online', updated_at = now()
  WHERE user_id = p_user_id AND status = 'busy';
END;
$$;

GRANT EXECUTE ON FUNCTION public.revert_busy_to_online(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- L. rotate_monthly_shifts — scheduler stub
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.rotate_monthly_shifts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Placeholder: mark completed shifts as archived
  UPDATE public.shifts
  SET status = 'completed'
  WHERE status = 'active' AND end_time < now() - interval '30 days';
END;
$$;

GRANT EXECUTE ON FUNCTION public.rotate_monthly_shifts() TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- M. migrate_existing_wallets_to_ledger — one-time migration helper
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.migrate_existing_wallets_to_ledger()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  -- Ensure gender column is populated on wallets from profiles
  UPDATE public.wallets w
  SET gender = p.gender
  FROM public.profiles p
  WHERE p.user_id = w.user_id AND w.gender IS NULL;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('success', true, 'wallets_updated', v_count,
    'message', 'Wallets synced with profiles. users_wallet view is ready.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.migrate_existing_wallets_to_ledger() TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- N. expire_group_video_access / cleanup_* stubs (needed by types.ts)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.expire_group_video_access()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.group_video_access
  SET is_active = false
  WHERE is_active = true AND access_expires_at < now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.expire_group_video_access() TO authenticated;

CREATE OR REPLACE FUNCTION public.cleanup_chat_media()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Placeholder: clean up orphaned chat media references
  DELETE FROM public.chat_messages
  WHERE created_at < now() - interval '6 months'
    AND message IS NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_chat_media() TO authenticated;

CREATE OR REPLACE FUNCTION public.cleanup_idle_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.active_chat_sessions
  SET status = 'ended', ended_at = now(), end_reason = 'idle_timeout'
  WHERE status = 'active' AND last_activity_at < now() - interval '30 minutes';

  UPDATE public.video_call_sessions
  SET status = 'ended', ended_at = now(), end_reason = 'idle_timeout'
  WHERE status = 'active' AND updated_at < now() - interval '30 minutes';
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_idle_sessions() TO authenticated;

CREATE OR REPLACE FUNCTION public.cleanup_video_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.video_call_sessions
  SET status = 'ended', ended_at = now(), end_reason = 'stale_cleanup'
  WHERE status IN ('active','ringing') AND updated_at < now() - interval '2 hours';
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_video_sessions() TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- O. Ensure wallets.gender default is set for new users via trigger
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_wallet_gender()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.wallets SET gender = NEW.gender
  WHERE user_id = NEW.user_id AND (gender IS NULL OR gender <> NEW.gender);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_sync_wallet_gender ON public.profiles;
CREATE TRIGGER trigger_sync_wallet_gender
  AFTER INSERT OR UPDATE OF gender ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_wallet_gender();

-- ─────────────────────────────────────────────────────────────────────────────
-- P. Final: run migrate to sync existing wallets
-- ─────────────────────────────────────────────────────────────────────────────
SELECT public.migrate_existing_wallets_to_ledger();
