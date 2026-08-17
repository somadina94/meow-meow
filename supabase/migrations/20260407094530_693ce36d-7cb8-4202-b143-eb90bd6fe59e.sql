
-- ============================================================
-- COMPLETE BILLING SYSTEM V2
-- ============================================================

-- Helper: get current IST timestamp
CREATE OR REPLACE FUNCTION public.now_ist()
RETURNS timestamptz
LANGUAGE sql STABLE
AS $$ SELECT NOW() AT TIME ZONE 'Asia/Kolkata'; $$;

-- Helper: get IST date
CREATE OR REPLACE FUNCTION public.today_ist()
RETURNS date
LANGUAGE sql STABLE
AS $$ SELECT (NOW() AT TIME ZONE 'Asia/Kolkata')::date; $$;

-- ── 1. Add missing columns to chat_pricing ──────────────
ALTER TABLE public.chat_pricing
  ADD COLUMN IF NOT EXISTS gift_women_percent            NUMERIC NOT NULL DEFAULT 50.00,
  ADD COLUMN IF NOT EXISTS recharge_platform_fee_percent NUMERIC NOT NULL DEFAULT 3.00,
  ADD COLUMN IF NOT EXISTS withdrawal_fee_percent        NUMERIC NOT NULL DEFAULT 5.00;

UPDATE public.chat_pricing SET
  rate_per_minute            = 4.00,
  video_rate_per_minute      = 8.00,
  audio_rate_per_minute      = 6.00,
  group_call_rate_per_minute = 4.00,
  women_earning_rate         = 2.00,
  video_women_earning_rate   = 4.00,
  audio_women_earning_rate   = 3.00,
  group_call_women_earning_rate = 0.50,
  gift_women_percent         = 50.00,
  recharge_platform_fee_percent = 3.00,
  withdrawal_fee_percent     = 5.00,
  is_active                  = true,
  updated_at                 = NOW()
WHERE is_active = true;

-- ── 2. MASTER LEDGER TABLE (no generated columns) ─────────────
CREATE TABLE IF NOT EXISTS public.platform_ledger (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid        NOT NULL,
  user_gender         text        NOT NULL CHECK (user_gender IN ('men', 'women')),
  entry_type          text        NOT NULL CHECK (entry_type IN (
                        'recharge', 'recharge_fee',
                        'chat_debit', 'chat_credit',
                        'video_debit', 'video_credit',
                        'audio_debit', 'audio_credit',
                        'group_call_debit', 'group_call_credit',
                        'gift_debit', 'gift_credit', 'gift_platform_fee',
                        'withdrawal', 'withdrawal_fee',
                        'refund'
                      )),
  debit               numeric(12,2) NOT NULL DEFAULT 0.00,
  credit              numeric(12,2) NOT NULL DEFAULT 0.00,
  balance_after       numeric(12,2) NOT NULL DEFAULT 0.00,
  session_id          text,
  counterparty_id     uuid,
  session_type        text,
  duration_minutes    numeric(8,2),
  rate_per_unit       numeric(8,2),
  idempotency_key     text UNIQUE,
  reference_number    text,
  description         text,
  created_at_ist      timestamptz NOT NULL DEFAULT (NOW() AT TIME ZONE 'Asia/Kolkata'),
  ist_date            date,
  ist_month           text,
  ist_year            int
);

-- Trigger to auto-populate IST date fields
CREATE OR REPLACE FUNCTION public.set_ledger_ist_fields()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.ist_date  := (NEW.created_at_ist AT TIME ZONE 'Asia/Kolkata')::date;
  NEW.ist_month := TO_CHAR(NEW.created_at_ist AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM');
  NEW.ist_year  := EXTRACT(YEAR FROM NEW.created_at_ist AT TIME ZONE 'Asia/Kolkata')::int;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ledger_ist_fields
  BEFORE INSERT OR UPDATE ON public.platform_ledger
  FOR EACH ROW EXECUTE FUNCTION public.set_ledger_ist_fields();

ALTER TABLE public.platform_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users view own ledger"   ON public.platform_ledger FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Admin views all ledger"  ON public.platform_ledger FOR SELECT USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "System inserts ledger"   ON public.platform_ledger FOR INSERT WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_ledger_user_month   ON public.platform_ledger (user_id, ist_month);
CREATE INDEX IF NOT EXISTS idx_ledger_gender_month ON public.platform_ledger (user_gender, ist_month);
CREATE INDEX IF NOT EXISTS idx_ledger_session      ON public.platform_ledger (session_id);
CREATE INDEX IF NOT EXISTS idx_ledger_date         ON public.platform_ledger (ist_date DESC);
CREATE INDEX IF NOT EXISTS idx_ledger_idempotency  ON public.platform_ledger (idempotency_key) WHERE idempotency_key IS NOT NULL;

-- ── 3. WOMEN PAYOUT SNAPSHOTS TABLE ───────────────────────────
CREATE TABLE IF NOT EXISTS public.women_payout_snapshots (
  id                    uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_type         text    NOT NULL CHECK (snapshot_type IN ('mid_month', 'end_month')),
  snapshot_ist_datetime timestamptz NOT NULL,
  snapshot_ist_date     date    NOT NULL,
  ist_month             text    NOT NULL,
  ist_year              int     NOT NULL,
  user_id               uuid    NOT NULL,
  full_name             text    NOT NULL,
  bank_name             text,
  bank_account_number   text,
  ifsc_code             text,
  gross_earned          numeric(12,2) NOT NULL DEFAULT 0.00,
  withdrawal_fee_amount numeric(12,2) NOT NULL DEFAULT 0.00,
  net_payable           numeric(12,2) NOT NULL DEFAULT 0.00,
  already_paid          numeric(12,2) NOT NULL DEFAULT 0.00,
  incremental_payable   numeric(12,2) NOT NULL DEFAULT 0.00,
  wallet_balance_at_snapshot numeric(12,2) NOT NULL DEFAULT 0.00,
  payment_status        text    NOT NULL DEFAULT 'pending'
                                CHECK (payment_status IN ('pending', 'processed', 'failed')),
  processed_at          timestamptz,
  processed_by          uuid,
  bank_reference        text,
  created_at            timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, snapshot_type, ist_month)
);

ALTER TABLE public.women_payout_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin manages snapshots" ON public.women_payout_snapshots FOR ALL USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Women view own snapshots" ON public.women_payout_snapshots FOR SELECT USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_snapshots_month_type ON public.women_payout_snapshots (ist_month, snapshot_type);
CREATE INDEX IF NOT EXISTS idx_snapshots_user       ON public.women_payout_snapshots (user_id, ist_month);
CREATE INDEX IF NOT EXISTS idx_snapshots_status     ON public.women_payout_snapshots (payment_status);

-- ── 4. Add missing columns to withdrawal_requests ─────────────
ALTER TABLE public.withdrawal_requests
  ADD COLUMN IF NOT EXISTS net_amount         numeric(12,2),
  ADD COLUMN IF NOT EXISTS fee_amount         numeric(12,2),
  ADD COLUMN IF NOT EXISTS fee_percent        numeric(5,2) DEFAULT 5.00,
  ADD COLUMN IF NOT EXISTS bank_name          text,
  ADD COLUMN IF NOT EXISTS bank_account_number text,
  ADD COLUMN IF NOT EXISTS ifsc_code          text;

-- ── 5. Add bank columns to female_profiles ────────────────────
ALTER TABLE public.female_profiles
  ADD COLUMN IF NOT EXISTS bank_name           text,
  ADD COLUMN IF NOT EXISTS bank_account_number text,
  ADD COLUMN IF NOT EXISTS ifsc_code           text,
  ADD COLUMN IF NOT EXISTS pan_number          text;

-- ── 6. RECHARGE FUNCTION ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_men_recharge(
  p_user_id       uuid,
  p_gross_amount  numeric,
  p_reference     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pricing         record;
  v_fee_pct         numeric;
  v_fee_amount      numeric;
  v_net_credit      numeric;
  v_new_balance     numeric;
  v_idempotency_key text;
BEGIN
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_fee_pct    := COALESCE(v_pricing.recharge_platform_fee_percent, 3.00);
  v_fee_amount := ROUND(p_gross_amount * v_fee_pct / 100.0, 2);
  v_net_credit := p_gross_amount - v_fee_amount;
  v_idempotency_key := 'recharge_' || p_user_id || '_' || COALESCE(p_reference, extract(epoch from now())::text);

  IF EXISTS (SELECT 1 FROM public.platform_ledger WHERE idempotency_key = v_idempotency_key) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_transaction');
  END IF;

  UPDATE public.wallets SET balance = balance + v_net_credit, updated_at = NOW()
  WHERE user_id = p_user_id;
  SELECT balance INTO v_new_balance FROM public.wallets WHERE user_id = p_user_id;

  INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, credit, balance_after,
    rate_per_unit, reference_number, idempotency_key, description, created_at_ist)
  VALUES (p_user_id, 'men', 'recharge', v_net_credit, v_new_balance,
    p_gross_amount, p_reference, v_idempotency_key,
    'Recharge ₹' || p_gross_amount || ' (fee ₹' || v_fee_amount || ', net ₹' || v_net_credit || ')',
    NOW() AT TIME ZONE 'Asia/Kolkata');

  INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, debit, balance_after,
    reference_number, description, created_at_ist)
  VALUES (p_user_id, 'men', 'recharge_fee', v_fee_amount, v_new_balance,
    p_reference, '3% platform fee on recharge of ₹' || p_gross_amount,
    NOW() AT TIME ZONE 'Asia/Kolkata');

  RETURN jsonb_build_object('success', true, 'gross_paid', p_gross_amount,
    'fee', v_fee_amount, 'credited', v_net_credit, 'new_balance', v_new_balance);
END;
$$;

-- ── 7. CHAT BILLING ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_chat_billing(
  p_session_id    text,
  p_man_id        uuid,
  p_woman_id      uuid,
  p_minutes       numeric,
  p_idempotency   text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pricing       record;
  v_man_charge    numeric;
  v_woman_earn    numeric;
  v_man_balance   numeric;
  v_woman_balance numeric;
  v_idem          text;
BEGIN
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_man_charge  := ROUND(p_minutes * COALESCE(v_pricing.rate_per_minute, 4.00), 2);
  v_woman_earn  := ROUND(p_minutes * COALESCE(v_pricing.women_earning_rate, 2.00), 2);
  v_idem        := COALESCE(p_idempotency, 'chat_' || p_session_id || '_' || p_minutes);

  IF EXISTS (SELECT 1 FROM public.platform_ledger WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_skipped');
  END IF;

  SELECT balance INTO v_man_balance FROM public.wallets WHERE user_id = p_man_id;
  IF v_man_balance IS NULL OR v_man_balance < v_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance');
  END IF;

  UPDATE public.wallets SET balance = balance - v_man_charge, updated_at = NOW()
  WHERE user_id = p_man_id RETURNING balance INTO v_man_balance;

  UPDATE public.wallets SET balance = balance + v_woman_earn, updated_at = NOW()
  WHERE user_id = p_woman_id RETURNING balance INTO v_woman_balance;

  INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, debit, balance_after,
    session_id, session_type, counterparty_id, duration_minutes, rate_per_unit,
    idempotency_key, description, created_at_ist)
  VALUES (p_man_id, 'men', 'chat_debit', v_man_charge, v_man_balance,
    p_session_id, 'chat', p_woman_id, p_minutes, COALESCE(v_pricing.rate_per_minute, 4.00),
    v_idem, 'Chat ' || p_minutes || ' min @ ₹' || COALESCE(v_pricing.rate_per_minute, 4.00) || '/min',
    NOW() AT TIME ZONE 'Asia/Kolkata');

  INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, credit, balance_after,
    session_id, session_type, counterparty_id, duration_minutes, rate_per_unit,
    description, created_at_ist)
  VALUES (p_woman_id, 'women', 'chat_credit', v_woman_earn, v_woman_balance,
    p_session_id, 'chat', p_man_id, p_minutes, COALESCE(v_pricing.women_earning_rate, 2.00),
    'Chat earning ' || p_minutes || ' min @ ₹' || COALESCE(v_pricing.women_earning_rate, 2.00) || '/min',
    NOW() AT TIME ZONE 'Asia/Kolkata');

  RETURN jsonb_build_object('success', true, 'man_charged', v_man_charge,
    'woman_earned', v_woman_earn, 'man_balance', v_man_balance);
END;
$$;

-- ── 8. VIDEO BILLING ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_video_billing_v2(
  p_session_id text, p_man_id uuid, p_woman_id uuid,
  p_minutes numeric, p_idempotency text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_pricing record; v_man_charge numeric; v_woman_earn numeric;
  v_man_balance numeric; v_woman_balance numeric; v_idem text;
BEGIN
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_man_charge := ROUND(p_minutes * COALESCE(v_pricing.video_rate_per_minute, 8.00), 2);
  v_woman_earn := ROUND(p_minutes * COALESCE(v_pricing.video_women_earning_rate, 4.00), 2);
  v_idem := COALESCE(p_idempotency, 'video_' || p_session_id || '_' || ROUND(p_minutes,4));
  IF EXISTS (SELECT 1 FROM public.platform_ledger WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_skipped'); END IF;
  SELECT balance INTO v_man_balance FROM public.wallets WHERE user_id = p_man_id;
  IF COALESCE(v_man_balance, 0) < v_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance', 'session_ended', true); END IF;
  UPDATE public.wallets SET balance = balance - v_man_charge, updated_at = NOW()
  WHERE user_id = p_man_id RETURNING balance INTO v_man_balance;
  UPDATE public.wallets SET balance = balance + v_woman_earn, updated_at = NOW()
  WHERE user_id = p_woman_id RETURNING balance INTO v_woman_balance;
  INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, debit, balance_after,
    session_id, session_type, counterparty_id, duration_minutes, rate_per_unit,
    idempotency_key, description, created_at_ist)
  VALUES (p_man_id, 'men', 'video_debit', v_man_charge, v_man_balance,
    p_session_id, 'video', p_woman_id, p_minutes, COALESCE(v_pricing.video_rate_per_minute, 8.00),
    v_idem, 'Video call ' || p_minutes || ' min @ ₹' || COALESCE(v_pricing.video_rate_per_minute, 8.00) || '/min',
    NOW() AT TIME ZONE 'Asia/Kolkata');
  INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, credit, balance_after,
    session_id, session_type, counterparty_id, duration_minutes, rate_per_unit, description, created_at_ist)
  VALUES (p_woman_id, 'women', 'video_credit', v_woman_earn, v_woman_balance,
    p_session_id, 'video', p_man_id, p_minutes, COALESCE(v_pricing.video_women_earning_rate, 4.00),
    'Video call earning ' || p_minutes || ' min @ ₹' || COALESCE(v_pricing.video_women_earning_rate, 4.00) || '/min',
    NOW() AT TIME ZONE 'Asia/Kolkata');
  RETURN jsonb_build_object('success', true, 'man_charged', v_man_charge, 'woman_earned', v_woman_earn);
END; $$;

-- ── 9. AUDIO BILLING ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_audio_billing(
  p_session_id text, p_man_id uuid, p_woman_id uuid,
  p_minutes numeric, p_idempotency text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_pricing record; v_man_charge numeric; v_woman_earn numeric;
  v_man_balance numeric; v_woman_balance numeric; v_idem text;
BEGIN
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_man_charge := ROUND(p_minutes * COALESCE(v_pricing.audio_rate_per_minute, 6.00), 2);
  v_woman_earn := ROUND(p_minutes * COALESCE(v_pricing.audio_women_earning_rate, 3.00), 2);
  v_idem := COALESCE(p_idempotency, 'audio_' || p_session_id || '_' || ROUND(p_minutes,4));
  IF EXISTS (SELECT 1 FROM public.platform_ledger WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_skipped'); END IF;
  SELECT balance INTO v_man_balance FROM public.wallets WHERE user_id = p_man_id;
  IF COALESCE(v_man_balance, 0) < v_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance', 'session_ended', true); END IF;
  UPDATE public.wallets SET balance = balance - v_man_charge, updated_at = NOW()
  WHERE user_id = p_man_id RETURNING balance INTO v_man_balance;
  UPDATE public.wallets SET balance = balance + v_woman_earn, updated_at = NOW()
  WHERE user_id = p_woman_id RETURNING balance INTO v_woman_balance;
  INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, debit, balance_after,
    session_id, session_type, counterparty_id, duration_minutes, rate_per_unit,
    idempotency_key, description, created_at_ist)
  VALUES (p_man_id, 'men', 'audio_debit', v_man_charge, v_man_balance,
    p_session_id, 'audio', p_woman_id, p_minutes, COALESCE(v_pricing.audio_rate_per_minute, 6.00),
    v_idem, 'Audio call ' || p_minutes || ' min @ ₹' || COALESCE(v_pricing.audio_rate_per_minute, 6.00) || '/min',
    NOW() AT TIME ZONE 'Asia/Kolkata');
  INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, credit, balance_after,
    session_id, session_type, counterparty_id, duration_minutes, rate_per_unit, description, created_at_ist)
  VALUES (p_woman_id, 'women', 'audio_credit', v_woman_earn, v_woman_balance,
    p_session_id, 'audio', p_man_id, p_minutes, COALESCE(v_pricing.audio_women_earning_rate, 3.00),
    'Audio call earning ' || p_minutes || ' min @ ₹' || COALESCE(v_pricing.audio_women_earning_rate, 3.00) || '/min',
    NOW() AT TIME ZONE 'Asia/Kolkata');
  RETURN jsonb_build_object('success', true, 'man_charged', v_man_charge, 'woman_earned', v_woman_earn);
END; $$;

-- ── 10. GROUP CALL BILLING ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_group_billing_v2(
  p_group_id text, p_session_id text, p_host_id uuid,
  p_man_ids uuid[], p_minutes numeric, p_idempotency text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_pricing record; v_rate_per_man numeric; v_earn_per_man numeric;
  v_man_id uuid; v_man_balance numeric; v_total_earned numeric := 0;
  v_active_count int := 0; v_removed_men uuid[] := '{}'; v_woman_balance numeric; v_idem text;
BEGIN
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_rate_per_man := ROUND(p_minutes * COALESCE(v_pricing.group_call_rate_per_minute, 4.00), 2);
  v_earn_per_man := ROUND(p_minutes * COALESCE(v_pricing.group_call_women_earning_rate, 0.50), 2);
  v_idem := COALESCE(p_idempotency, 'group_' || p_session_id || '_' || array_length(p_man_ids,1) || '_' || ROUND(p_minutes,4));
  IF EXISTS (SELECT 1 FROM public.platform_ledger WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_skipped'); END IF;
  FOREACH v_man_id IN ARRAY p_man_ids LOOP
    SELECT balance INTO v_man_balance FROM public.wallets WHERE user_id = v_man_id;
    IF COALESCE(v_man_balance, 0) < v_rate_per_man THEN
      v_removed_men := array_append(v_removed_men, v_man_id); CONTINUE; END IF;
    UPDATE public.wallets SET balance = balance - v_rate_per_man, updated_at = NOW()
    WHERE user_id = v_man_id RETURNING balance INTO v_man_balance;
    INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, debit, balance_after,
      session_id, session_type, counterparty_id, duration_minutes, rate_per_unit, description, created_at_ist)
    VALUES (v_man_id, 'men', 'group_call_debit', v_rate_per_man, v_man_balance,
      p_session_id, 'group', p_host_id, p_minutes, COALESCE(v_pricing.group_call_rate_per_minute, 4.00),
      'Group call ' || p_minutes || ' min @ ₹' || COALESCE(v_pricing.group_call_rate_per_minute, 4.00) || '/min',
      NOW() AT TIME ZONE 'Asia/Kolkata');
    v_total_earned := v_total_earned + v_earn_per_man;
    v_active_count := v_active_count + 1;
  END LOOP;
  IF v_total_earned > 0 THEN
    UPDATE public.wallets SET balance = balance + v_total_earned, updated_at = NOW()
    WHERE user_id = p_host_id RETURNING balance INTO v_woman_balance;
    INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, credit, balance_after,
      session_id, session_type, duration_minutes, rate_per_unit,
      idempotency_key, description, created_at_ist)
    VALUES (p_host_id, 'women', 'group_call_credit', v_total_earned, v_woman_balance,
      p_session_id, 'group', p_minutes, COALESCE(v_pricing.group_call_women_earning_rate, 0.50),
      v_idem, 'Group call: ' || v_active_count || ' men × ₹' || v_earn_per_man || ' = ₹' || v_total_earned,
      NOW() AT TIME ZONE 'Asia/Kolkata');
  END IF;
  RETURN jsonb_build_object('success', true, 'active_count', v_active_count,
    'host_earned', v_total_earned, 'removed_users', v_removed_men);
END; $$;

-- ── 11. GIFT BILLING ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_gift_billing(
  p_man_id uuid, p_woman_id uuid, p_gift_value numeric,
  p_gift_name text DEFAULT 'Gift', p_idempotency text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_pricing record; v_woman_pct numeric; v_woman_earn numeric;
  v_platform_take numeric; v_man_balance numeric; v_woman_balance numeric; v_idem text;
BEGIN
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_woman_pct := COALESCE(v_pricing.gift_women_percent, 50.00);
  v_woman_earn := ROUND(p_gift_value * v_woman_pct / 100.0, 2);
  v_platform_take := p_gift_value - v_woman_earn;
  v_idem := COALESCE(p_idempotency, 'gift_' || p_man_id || '_' || p_woman_id || '_' || extract(epoch from now())::text);
  IF EXISTS (SELECT 1 FROM public.platform_ledger WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_skipped'); END IF;
  SELECT balance INTO v_man_balance FROM public.wallets WHERE user_id = p_man_id;
  IF COALESCE(v_man_balance, 0) < p_gift_value THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance'); END IF;
  UPDATE public.wallets SET balance = balance - p_gift_value, updated_at = NOW()
  WHERE user_id = p_man_id RETURNING balance INTO v_man_balance;
  UPDATE public.wallets SET balance = balance + v_woman_earn, updated_at = NOW()
  WHERE user_id = p_woman_id RETURNING balance INTO v_woman_balance;
  INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, debit, balance_after,
    session_type, counterparty_id, rate_per_unit, idempotency_key, description, created_at_ist)
  VALUES (p_man_id, 'men', 'gift_debit', p_gift_value, v_man_balance,
    'gift', p_woman_id, p_gift_value, v_idem,
    p_gift_name || ': ₹' || p_gift_value || ' sent (100% deducted)', NOW() AT TIME ZONE 'Asia/Kolkata');
  INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, credit, balance_after,
    session_type, counterparty_id, rate_per_unit, description, created_at_ist)
  VALUES (p_woman_id, 'women', 'gift_credit', v_woman_earn, v_woman_balance,
    'gift', p_man_id, v_woman_pct, p_gift_name || ': ₹' || v_woman_earn || ' (50% of ₹' || p_gift_value || ')',
    NOW() AT TIME ZONE 'Asia/Kolkata');
  RETURN jsonb_build_object('success', true, 'man_charged', p_gift_value,
    'woman_earned', v_woman_earn, 'platform_earned', v_platform_take);
END; $$;

-- ── 12. WITHDRAWAL ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.process_withdrawal(
  p_user_id uuid, p_amount numeric, p_bank_name text,
  p_account_no text, p_ifsc_code text, p_idempotency text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_pricing record; v_fee_pct numeric; v_fee_amount numeric;
  v_net_amount numeric; v_current_balance numeric; v_new_balance numeric; v_idem text;
BEGIN
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_fee_pct := COALESCE(v_pricing.withdrawal_fee_percent, 5.00);
  v_fee_amount := ROUND(p_amount * v_fee_pct / 100.0, 2);
  v_net_amount := p_amount - v_fee_amount;
  v_idem := COALESCE(p_idempotency, 'withdrawal_' || p_user_id || '_' || extract(epoch from now())::text);
  IF EXISTS (SELECT 1 FROM public.platform_ledger WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_transaction'); END IF;
  SELECT balance INTO v_current_balance FROM public.wallets WHERE user_id = p_user_id;
  IF COALESCE(v_current_balance, 0) < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance',
      'balance', COALESCE(v_current_balance, 0), 'requested', p_amount); END IF;
  UPDATE public.wallets SET balance = balance - p_amount, updated_at = NOW()
  WHERE user_id = p_user_id RETURNING balance INTO v_new_balance;
  INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, debit, balance_after,
    session_type, idempotency_key, description, created_at_ist)
  VALUES (p_user_id, 'women', 'withdrawal', p_amount, v_new_balance,
    'withdrawal', v_idem,
    'Withdrawal ₹' || p_amount || ' (fee ₹' || v_fee_amount || ', net ₹' || v_net_amount || ')',
    NOW() AT TIME ZONE 'Asia/Kolkata');
  INSERT INTO public.platform_ledger (user_id, user_gender, entry_type, debit, balance_after,
    session_type, description, created_at_ist)
  VALUES (p_user_id, 'women', 'withdrawal_fee', v_fee_amount, v_new_balance,
    'withdrawal', '5% withdrawal fee on ₹' || p_amount, NOW() AT TIME ZONE 'Asia/Kolkata');
  INSERT INTO public.withdrawal_requests (user_id, amount, net_amount, fee_amount,
    fee_percent, bank_name, bank_account_number, ifsc_code, status)
  VALUES (p_user_id, p_amount, v_net_amount, v_fee_amount, v_fee_pct,
    p_bank_name, p_account_no, p_ifsc_code, 'pending');
  RETURN jsonb_build_object('success', true, 'gross', p_amount,
    'fee', v_fee_amount, 'net_payable', v_net_amount, 'new_balance', v_new_balance);
END; $$;

-- ── 13. PAYOUT SNAPSHOT ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.capture_payout_snapshot(
  p_snapshot_type text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ist_now timestamptz; v_ist_date date; v_ist_month text; v_ist_year int;
  v_pricing record; v_fee_pct numeric; v_rec record; v_count int := 0;
  v_already_paid numeric; v_gross_earned numeric;
BEGIN
  v_ist_now := NOW() AT TIME ZONE 'Asia/Kolkata';
  v_ist_date := v_ist_now::date;
  v_ist_month := TO_CHAR(v_ist_now, 'YYYY-MM');
  v_ist_year := EXTRACT(YEAR FROM v_ist_now)::int;
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_fee_pct := COALESCE(v_pricing.withdrawal_fee_percent, 5.00);

  FOR v_rec IN
    SELECT w.user_id, w.balance AS wallet_balance,
      COALESCE(fp.full_name, 'Unknown') AS full_name,
      fp.bank_name, fp.bank_account_number, fp.ifsc_code
    FROM public.wallets w
    LEFT JOIN public.female_profiles fp ON fp.user_id = w.user_id
    WHERE w.gender = 'female' AND w.balance > 0
  LOOP
    SELECT COALESCE(SUM(credit), 0) INTO v_gross_earned FROM public.platform_ledger
    WHERE user_id = v_rec.user_id AND ist_month = v_ist_month
      AND entry_type IN ('chat_credit','video_credit','audio_credit','group_call_credit','gift_credit');

    IF p_snapshot_type = 'end_month' THEN
      SELECT COALESCE(net_payable, 0) INTO v_already_paid FROM public.women_payout_snapshots
      WHERE user_id = v_rec.user_id AND ist_month = v_ist_month AND snapshot_type = 'mid_month' LIMIT 1;
    ELSE v_already_paid := 0.00; END IF;

    INSERT INTO public.women_payout_snapshots (
      snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
      user_id, full_name, bank_name, bank_account_number, ifsc_code,
      gross_earned, withdrawal_fee_amount, net_payable, already_paid, incremental_payable,
      wallet_balance_at_snapshot, payment_status, created_at)
    VALUES (
      p_snapshot_type, v_ist_now, v_ist_date, v_ist_month, v_ist_year,
      v_rec.user_id, v_rec.full_name, v_rec.bank_name, v_rec.bank_account_number, v_rec.ifsc_code,
      v_gross_earned, ROUND(v_gross_earned * v_fee_pct / 100.0, 2),
      ROUND(v_gross_earned * (100 - v_fee_pct) / 100.0, 2), COALESCE(v_already_paid, 0),
      ROUND(v_gross_earned * (100 - v_fee_pct) / 100.0, 2) - COALESCE(v_already_paid, 0),
      v_rec.wallet_balance, 'pending', NOW())
    ON CONFLICT (user_id, snapshot_type, ist_month)
    DO UPDATE SET gross_earned = EXCLUDED.gross_earned,
      withdrawal_fee_amount = EXCLUDED.withdrawal_fee_amount,
      net_payable = EXCLUDED.net_payable,
      incremental_payable = EXCLUDED.incremental_payable,
      wallet_balance_at_snapshot = EXCLUDED.wallet_balance_at_snapshot,
      created_at = NOW();
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'snapshot_type', p_snapshot_type,
    'women_processed', v_count, 'ist_datetime', v_ist_now);
END; $$;

-- ── 14. RESET WOMEN WALLETS ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.reset_women_wallets_after_snapshot()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int := 0;
BEGIN
  UPDATE public.wallets SET balance = 0, updated_at = NOW()
  WHERE gender = 'female' AND balance > 0;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('success', true, 'wallets_reset', v_count);
END; $$;
