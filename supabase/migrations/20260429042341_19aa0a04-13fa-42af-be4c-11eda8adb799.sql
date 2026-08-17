
-- ════════════════════════════════════════════════════════════════
-- UNIFIED BILLING SYSTEM — Full Replacement
-- ════════════════════════════════════════════════════════════════

-- 1. Drop old monthly_statements (will be recreated with full schema)
DROP TABLE IF EXISTS public.monthly_statements CASCADE;

-- 2. billing_ledger — men's single ledger
CREATE TABLE IF NOT EXISTS public.billing_ledger (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  man_id            uuid        NOT NULL,
  woman_id          uuid,
  entry_type        text        NOT NULL CHECK (entry_type IN ('debit','credit')),
  amount            numeric(10,2) NOT NULL CHECK (amount > 0),
  balance_after     numeric(10,2) NOT NULL,
  currency          text        NOT NULL DEFAULT 'INR',
  session_type      text        NOT NULL CHECK (session_type IN (
                      'chat','audio_call','video_call',
                      'private_group_call','gift','tip','recharge'
                    )),
  session_id        uuid,
  duration_minutes  numeric(10,4),
  rate_applied      numeric(10,2),
  description       text,
  reference_id      text,
  idempotency_key   text        UNIQUE,
  status            text        NOT NULL DEFAULT 'completed'
                      CHECK (status IN ('pending','completed','failed')),
  created_at        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.billing_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY billing_ledger_admin ON public.billing_ledger
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));
CREATE INDEX idx_bl_man_created    ON public.billing_ledger(man_id, created_at DESC);
CREATE INDEX idx_bl_session_type   ON public.billing_ledger(session_type, created_at DESC);
CREATE INDEX idx_bl_session_id     ON public.billing_ledger(session_id) WHERE session_id IS NOT NULL;
CREATE INDEX idx_bl_idempotency    ON public.billing_ledger(idempotency_key) WHERE idempotency_key IS NOT NULL;

-- 3. earnings_ledger — women's single ledger
CREATE TABLE IF NOT EXISTS public.earnings_ledger (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  woman_id          uuid        NOT NULL,
  man_id            uuid,
  amount            numeric(10,2) NOT NULL CHECK (amount >= 0),
  currency          text        NOT NULL DEFAULT 'INR',
  session_type      text        NOT NULL CHECK (session_type IN (
                      'chat','audio_call','video_call',
                      'private_group_call','gift','tip','bonus'
                    )),
  session_id        uuid,
  duration_minutes  numeric(10,4),
  rate_applied      numeric(10,2),
  description       text,
  created_at        timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.earnings_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY earnings_ledger_admin ON public.earnings_ledger
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));
CREATE INDEX idx_el_woman_created  ON public.earnings_ledger(woman_id, created_at DESC);
CREATE INDEX idx_el_session_type   ON public.earnings_ledger(session_type, created_at DESC);
CREATE INDEX idx_el_session_id     ON public.earnings_ledger(session_id) WHERE session_id IS NOT NULL;

-- 4. monthly_statements (recreated with unified schema)
CREATE TABLE public.monthly_statements (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        NOT NULL,
  gender            text        NOT NULL CHECK (gender IN ('male','female')),
  year              integer     NOT NULL,
  month             integer     NOT NULL CHECK (month BETWEEN 1 AND 12),
  opening_balance   numeric(10,2) NOT NULL DEFAULT 0,
  total_credit      numeric(10,2) NOT NULL DEFAULT 0,
  total_debit       numeric(10,2) NOT NULL DEFAULT 0,
  closing_balance   numeric(10,2) NOT NULL DEFAULT 0,
  chat_amount       numeric(10,2) NOT NULL DEFAULT 0,
  audio_call_amount numeric(10,2) NOT NULL DEFAULT 0,
  video_call_amount numeric(10,2) NOT NULL DEFAULT 0,
  group_call_amount numeric(10,2) NOT NULL DEFAULT 0,
  gift_amount       numeric(10,2) NOT NULL DEFAULT 0,
  tip_amount        numeric(10,2) NOT NULL DEFAULT 0,
  recharge_amount   numeric(10,2) NOT NULL DEFAULT 0,
  payout_amount     numeric(10,2) NOT NULL DEFAULT 0,
  payout_status     text        NOT NULL DEFAULT 'na'
                      CHECK (payout_status IN ('na','pending','approved','paid','rejected')),
  pdf_url           text,
  excel_url         text,
  notes             text,
  paid_at           timestamptz,
  generated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, year, month)
);
ALTER TABLE public.monthly_statements ENABLE ROW LEVEL SECURITY;
CREATE POLICY ms_admin_all ON public.monthly_statements
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin'));
CREATE POLICY ms_user_own_select ON public.monthly_statements
  FOR SELECT TO authenticated
  USING (user_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));
CREATE INDEX idx_ms_user_period   ON public.monthly_statements(user_id, year DESC, month DESC);
CREATE INDEX idx_ms_payout_status ON public.monthly_statements(payout_status, year DESC, month DESC)
  WHERE gender = 'female';

-- ════════════════════════════════════════════════════════════════
-- RPCs
-- ════════════════════════════════════════════════════════════════

-- get_unified_pricing — maps existing chat_pricing columns to spec names
CREATE OR REPLACE FUNCTION public.get_unified_pricing()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_p RECORD;
BEGIN
  SELECT * INTO v_p FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'chat_man_rate',4,'chat_woman_rate',2,
      'audio_man_rate',6,'audio_woman_rate',3,
      'video_man_rate',8,'video_woman_rate',4,
      'group_man_rate',4,'group_woman_rate',2,
      'gift_woman_pct',50,'tip_woman_pct',100,
      'withdrawal_fee_pct',5,'min_withdrawal_amount',5000,
      'currency','INR'
    );
  END IF;
  RETURN jsonb_build_object(
    'chat_man_rate',         COALESCE(v_p.rate_per_minute,4),
    'chat_woman_rate',       COALESCE(v_p.women_earning_rate,2),
    'audio_man_rate',        COALESCE(v_p.audio_rate_per_minute,6),
    'audio_woman_rate',      COALESCE(v_p.audio_women_earning_rate,3),
    'video_man_rate',        COALESCE(v_p.video_rate_per_minute,8),
    'video_woman_rate',      COALESCE(v_p.video_women_earning_rate,4),
    'group_man_rate',        COALESCE(v_p.group_call_rate_per_minute,4),
    'group_woman_rate',      COALESCE(v_p.group_call_women_earning_rate,2),
    'gift_woman_pct',        COALESCE(v_p.gift_women_percent,50),
    'tip_woman_pct',         100,
    'withdrawal_fee_pct',    COALESCE(v_p.withdrawal_fee_percent,5),
    'min_withdrawal_amount', COALESCE(v_p.min_withdrawal_balance,5000),
    'currency',              COALESCE(v_p.currency,'INR')
  );
END; $$;
GRANT EXECUTE ON FUNCTION public.get_unified_pricing() TO authenticated, anon;

-- bill_session_minute — single per-minute billing function
CREATE OR REPLACE FUNCTION public.bill_session_minute(
  p_session_id    uuid,
  p_session_type  text,
  p_minutes       numeric,
  p_man_id        uuid,
  p_woman_id      uuid,
  p_man_count     integer DEFAULT 1
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_pricing jsonb;
  v_wallet RECORD;
  v_man_rate numeric(10,2);
  v_woman_rate numeric(10,2);
  v_charge numeric(10,2);
  v_earn numeric(10,2);
  v_balance_after numeric(10,2);
  v_idem_key text;
  v_is_super boolean := false;
BEGIN
  IF p_session_type NOT IN ('chat','audio_call','video_call','private_group_call') THEN
    RETURN jsonb_build_object('success',false,'error','Invalid session_type');
  END IF;

  v_idem_key := p_session_id::text || '|' || p_session_type || '|' || p_man_id::text || '|' || p_minutes::text || '|' || EXTRACT(EPOCH FROM date_trunc('minute', now()))::text;
  IF EXISTS (SELECT 1 FROM public.billing_ledger WHERE idempotency_key = v_idem_key) THEN
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
  v_earn   := ROUND(v_woman_rate * p_minutes * p_man_count, 2);

  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id IN (SELECT user_id FROM public.profiles WHERE id = p_man_id)
      AND role IN ('admin','super_user')
  ) INTO v_is_super;

  IF NOT v_is_super THEN
    SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success',false,'error','Wallet not found');
    END IF;
    IF v_wallet.balance < v_charge THEN
      RETURN jsonb_build_object('success',false,'error','Insufficient balance',
                                'balance',v_wallet.balance,'required',v_charge);
    END IF;
    v_balance_after := v_wallet.balance - v_charge;
    UPDATE public.wallets SET balance = v_balance_after, updated_at = now() WHERE id = v_wallet.id;
    INSERT INTO public.billing_ledger (
      man_id, woman_id, entry_type, amount, balance_after,
      session_type, session_id, duration_minutes, rate_applied,
      description, idempotency_key, status
    ) VALUES (
      p_man_id, p_woman_id, 'debit', v_charge, v_balance_after,
      p_session_type, p_session_id, p_minutes, v_man_rate,
      initcap(replace(p_session_type,'_',' ')) || ' — ' || p_minutes || ' min @ ₹' || v_man_rate || '/min',
      v_idem_key, 'completed'
    );
  END IF;

  IF v_earn > 0 AND p_woman_id IS NOT NULL THEN
    INSERT INTO public.earnings_ledger (
      woman_id, man_id, amount, session_type, session_id,
      duration_minutes, rate_applied, description
    ) VALUES (
      p_woman_id, p_man_id, v_earn, p_session_type, p_session_id,
      p_minutes, v_woman_rate,
      initcap(replace(p_session_type,'_',' ')) || ' earnings — ' || p_minutes || ' min @ ₹' || v_woman_rate || '/min'
    );
  END IF;

  RETURN jsonb_build_object(
    'success',true,'session_type',p_session_type,
    'charged',CASE WHEN v_is_super THEN 0 ELSE v_charge END,
    'earned',v_earn,'man_rate',v_man_rate,'woman_rate',v_woman_rate,
    'minutes',p_minutes,'super_user_skip',v_is_super
  );
END; $$;
GRANT EXECUTE ON FUNCTION public.bill_session_minute(uuid,text,numeric,uuid,uuid,integer) TO authenticated;

-- bill_gift_or_tip
CREATE OR REPLACE FUNCTION public.bill_gift_or_tip(
  p_man_id uuid, p_woman_id uuid, p_amount numeric, p_type text,
  p_description text DEFAULT NULL, p_reference_id text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_pricing jsonb; v_wallet RECORD;
  v_pct numeric(5,2); v_woman_credit numeric(10,2);
  v_balance_after numeric(10,2); v_is_super boolean := false;
BEGIN
  IF p_type NOT IN ('gift','tip') THEN
    RETURN jsonb_build_object('success',false,'error','type must be gift or tip');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','amount must be > 0');
  END IF;

  v_pricing := public.get_unified_pricing();
  v_pct := CASE p_type
    WHEN 'gift' THEN (v_pricing->>'gift_woman_pct')::numeric
    ELSE (v_pricing->>'tip_woman_pct')::numeric
  END;
  v_woman_credit := ROUND(p_amount * v_pct / 100.0, 2);

  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id IN (SELECT user_id FROM public.profiles WHERE id = p_man_id)
      AND role IN ('admin','super_user')
  ) INTO v_is_super;

  IF NOT v_is_super THEN
    SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success',false,'error','Wallet not found');
    END IF;
    IF v_wallet.balance < p_amount THEN
      RETURN jsonb_build_object('success',false,'error','Insufficient balance',
                                'balance',v_wallet.balance,'required',p_amount);
    END IF;
    v_balance_after := v_wallet.balance - p_amount;
    UPDATE public.wallets SET balance = v_balance_after, updated_at = now() WHERE id = v_wallet.id;
    INSERT INTO public.billing_ledger (
      man_id, woman_id, entry_type, amount, balance_after,
      session_type, rate_applied, description, reference_id, status,
      idempotency_key
    ) VALUES (
      p_man_id, p_woman_id, 'debit', p_amount, v_balance_after,
      p_type, p_amount,
      COALESCE(p_description, initcap(p_type) || ' sent — ₹' || p_amount),
      p_reference_id, 'completed',
      p_type || '|' || p_man_id::text || '|' || COALESCE(p_reference_id,'') || '|' || EXTRACT(EPOCH FROM now())::text
    );
  END IF;

  IF v_woman_credit > 0 AND p_woman_id IS NOT NULL THEN
    INSERT INTO public.earnings_ledger (
      woman_id, man_id, amount, session_type, rate_applied, description
    ) VALUES (
      p_woman_id, p_man_id, v_woman_credit, p_type, v_pct,
      COALESCE(p_description, initcap(p_type) || ' received — ' || v_pct || '% of ₹' || p_amount)
    );
  END IF;

  RETURN jsonb_build_object(
    'success',true,'type',p_type,
    'charged',CASE WHEN v_is_super THEN 0 ELSE p_amount END,
    'woman_credit',v_woman_credit,'woman_pct',v_pct
  );
END; $$;
GRANT EXECUTE ON FUNCTION public.bill_gift_or_tip(uuid,uuid,numeric,text,text,text) TO authenticated;

-- get_man_balance
CREATE OR REPLACE FUNCTION public.get_man_balance(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_balance numeric(10,2);
BEGIN
  SELECT COALESCE(balance,0) INTO v_balance FROM public.wallets WHERE user_id = p_user_id;
  RETURN jsonb_build_object('balance',COALESCE(v_balance,0),'currency','INR');
END; $$;
GRANT EXECUTE ON FUNCTION public.get_man_balance(uuid) TO authenticated;

-- get_woman_balance
CREATE OR REPLACE FUNCTION public.get_woman_balance(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total_earned numeric(10,2);
  v_paid_out numeric(10,2);
  v_today numeric(10,2);
BEGIN
  SELECT COALESCE(SUM(amount),0) INTO v_total_earned
  FROM public.earnings_ledger WHERE woman_id = p_user_id;

  SELECT COALESCE(SUM(payout_amount),0) INTO v_paid_out
  FROM public.monthly_statements
  WHERE user_id = p_user_id AND gender = 'female'
    AND payout_status IN ('approved','paid');

  SELECT COALESCE(SUM(amount),0) INTO v_today
  FROM public.earnings_ledger
  WHERE woman_id = p_user_id
    AND created_at >= date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata';

  RETURN jsonb_build_object(
    'available_balance',GREATEST(v_total_earned - v_paid_out,0),
    'total_earned',v_total_earned,'paid_out',v_paid_out,
    'today_earnings',v_today,'currency','INR'
  );
END; $$;
GRANT EXECUTE ON FUNCTION public.get_woman_balance(uuid) TO authenticated;

-- run_monthly_closing
CREATE OR REPLACE FUNCTION public.run_monthly_closing(
  p_year integer DEFAULT NULL, p_month integer DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_year int; v_month int;
  v_period_start timestamptz; v_period_end timestamptz;
  v_prev_year int; v_prev_month int;
  v_user RECORD;
  v_opening numeric(10,2); v_credits numeric(10,2); v_debits numeric(10,2);
  v_closing numeric(10,2); v_payout numeric(10,2); v_pstatus text;
  v_men_done int := 0; v_women_done int := 0; v_payouts_made int := 0;
  v_chat numeric(10,2); v_audio numeric(10,2); v_video numeric(10,2);
  v_group numeric(10,2); v_gift numeric(10,2); v_tip numeric(10,2); v_recharge numeric(10,2);
BEGIN
  v_year  := COALESCE(p_year,  EXTRACT(year FROM (now() AT TIME ZONE 'Asia/Kolkata' - interval '1 day'))::int);
  v_month := COALESCE(p_month, EXTRACT(month FROM (now() AT TIME ZONE 'Asia/Kolkata' - interval '1 day'))::int);
  v_period_start := make_timestamptz(v_year, v_month, 1, 0, 0, 0, 'Asia/Kolkata');
  v_period_end := v_period_start + interval '1 month';
  IF v_month = 1 THEN v_prev_year := v_year - 1; v_prev_month := 12;
  ELSE v_prev_year := v_year; v_prev_month := v_month - 1; END IF;

  -- MEN
  FOR v_user IN SELECT id FROM public.profiles WHERE gender = 'male' LOOP
    SELECT closing_balance INTO v_opening FROM public.monthly_statements
    WHERE user_id = v_user.id AND year = v_prev_year AND month = v_prev_month;
    v_opening := COALESCE(v_opening, 0);

    SELECT
      COALESCE(SUM(CASE WHEN entry_type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN entry_type='debit' THEN amount ELSE 0 END),0)
    INTO v_credits, v_debits
    FROM public.billing_ledger
    WHERE man_id = v_user.id AND created_at >= v_period_start AND created_at < v_period_end;

    SELECT
      COALESCE(SUM(CASE WHEN session_type='chat' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='audio_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='video_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='private_group_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='gift' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='tip' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='recharge' THEN amount ELSE 0 END),0)
    INTO v_chat,v_audio,v_video,v_group,v_gift,v_tip,v_recharge
    FROM public.billing_ledger
    WHERE man_id = v_user.id AND created_at >= v_period_start AND created_at < v_period_end;

    v_closing := GREATEST(v_opening + v_credits - v_debits, 0);

    INSERT INTO public.monthly_statements (
      user_id, gender, year, month, opening_balance, total_credit, total_debit,
      closing_balance, chat_amount, audio_call_amount, video_call_amount,
      group_call_amount, gift_amount, tip_amount, recharge_amount,
      payout_amount, payout_status
    ) VALUES (
      v_user.id, 'male', v_year, v_month, v_opening, v_credits, v_debits,
      v_closing, v_chat, v_audio, v_video, v_group, v_gift, v_tip, v_recharge, 0, 'na'
    ) ON CONFLICT (user_id, year, month) DO UPDATE SET
      opening_balance=EXCLUDED.opening_balance, total_credit=EXCLUDED.total_credit,
      total_debit=EXCLUDED.total_debit, closing_balance=EXCLUDED.closing_balance,
      chat_amount=EXCLUDED.chat_amount, audio_call_amount=EXCLUDED.audio_call_amount,
      video_call_amount=EXCLUDED.video_call_amount, group_call_amount=EXCLUDED.group_call_amount,
      gift_amount=EXCLUDED.gift_amount, tip_amount=EXCLUDED.tip_amount,
      recharge_amount=EXCLUDED.recharge_amount;
    v_men_done := v_men_done + 1;
  END LOOP;

  -- WOMEN
  FOR v_user IN SELECT id FROM public.profiles WHERE gender = 'female' LOOP
    SELECT COALESCE(SUM(amount),0) INTO v_credits
    FROM public.earnings_ledger
    WHERE woman_id = v_user.id AND created_at >= v_period_start AND created_at < v_period_end;

    SELECT
      COALESCE(SUM(CASE WHEN session_type='chat' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='audio_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='video_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='private_group_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='gift' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='tip' THEN amount ELSE 0 END),0)
    INTO v_chat,v_audio,v_video,v_group,v_gift,v_tip
    FROM public.earnings_ledger
    WHERE woman_id = v_user.id AND created_at >= v_period_start AND created_at < v_period_end;

    v_closing := v_credits;
    v_payout := v_closing;
    v_pstatus := CASE WHEN v_payout > 0 THEN 'pending' ELSE 'na' END;

    INSERT INTO public.monthly_statements (
      user_id, gender, year, month, opening_balance, total_credit, total_debit,
      closing_balance, chat_amount, audio_call_amount, video_call_amount,
      group_call_amount, gift_amount, tip_amount, payout_amount, payout_status
    ) VALUES (
      v_user.id, 'female', v_year, v_month, 0, v_credits, 0, v_closing,
      v_chat, v_audio, v_video, v_group, v_gift, v_tip, v_payout, v_pstatus
    ) ON CONFLICT (user_id, year, month) DO UPDATE SET
      total_credit=EXCLUDED.total_credit, closing_balance=EXCLUDED.closing_balance,
      chat_amount=EXCLUDED.chat_amount, audio_call_amount=EXCLUDED.audio_call_amount,
      video_call_amount=EXCLUDED.video_call_amount, group_call_amount=EXCLUDED.group_call_amount,
      gift_amount=EXCLUDED.gift_amount, tip_amount=EXCLUDED.tip_amount,
      payout_amount=EXCLUDED.payout_amount,
      payout_status = CASE
        WHEN public.monthly_statements.payout_status IN ('approved','paid')
          THEN public.monthly_statements.payout_status
        ELSE EXCLUDED.payout_status
      END;
    IF v_payout > 0 THEN v_payouts_made := v_payouts_made + 1; END IF;
    v_women_done := v_women_done + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success',true,'year',v_year,'month',v_month,
    'men_processed',v_men_done,'women_processed',v_women_done,
    'payouts_queued',v_payouts_made
  );
END; $$;
GRANT EXECUTE ON FUNCTION public.run_monthly_closing(integer,integer) TO authenticated;

-- generate_payout_snapshot_unified — admin "Generate Now" button
-- Creates a current-month statement for every woman with un-paid earnings,
-- using ALL of their lifetime earnings minus what's already been paid out.
CREATE OR REPLACE FUNCTION public.generate_payout_snapshot_unified()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_now timestamptz := now() AT TIME ZONE 'Asia/Kolkata';
  v_year int := EXTRACT(year FROM v_now)::int;
  v_month int := EXTRACT(month FROM v_now)::int;
  v_user RECORD;
  v_total_earned numeric(10,2);
  v_paid_out numeric(10,2);
  v_available numeric(10,2);
  v_chat numeric(10,2); v_audio numeric(10,2); v_video numeric(10,2);
  v_group numeric(10,2); v_gift numeric(10,2); v_tip numeric(10,2);
  v_count int := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  FOR v_user IN SELECT id FROM public.profiles WHERE gender = 'female' LOOP
    SELECT COALESCE(SUM(amount),0) INTO v_total_earned
    FROM public.earnings_ledger WHERE woman_id = v_user.id;

    SELECT COALESCE(SUM(payout_amount),0) INTO v_paid_out
    FROM public.monthly_statements
    WHERE user_id = v_user.id AND gender='female' AND payout_status IN ('approved','paid');

    v_available := GREATEST(v_total_earned - v_paid_out, 0);
    IF v_available <= 0 THEN CONTINUE; END IF;

    -- Breakdown across ALL un-paid-out earnings (lifetime minus already-paid statements)
    SELECT
      COALESCE(SUM(CASE WHEN session_type='chat' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='audio_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='video_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='private_group_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='gift' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='tip' THEN amount ELSE 0 END),0)
    INTO v_chat,v_audio,v_video,v_group,v_gift,v_tip
    FROM public.earnings_ledger WHERE woman_id = v_user.id;

    INSERT INTO public.monthly_statements (
      user_id, gender, year, month, opening_balance, total_credit,
      total_debit, closing_balance, chat_amount, audio_call_amount,
      video_call_amount, group_call_amount, gift_amount, tip_amount,
      payout_amount, payout_status, generated_at
    ) VALUES (
      v_user.id, 'female', v_year, v_month, 0, v_available, 0, v_available,
      v_chat, v_audio, v_video, v_group, v_gift, v_tip,
      v_available, 'pending', now()
    ) ON CONFLICT (user_id, year, month) DO UPDATE SET
      total_credit = EXCLUDED.total_credit,
      closing_balance = EXCLUDED.closing_balance,
      chat_amount = EXCLUDED.chat_amount,
      audio_call_amount = EXCLUDED.audio_call_amount,
      video_call_amount = EXCLUDED.video_call_amount,
      group_call_amount = EXCLUDED.group_call_amount,
      gift_amount = EXCLUDED.gift_amount,
      tip_amount = EXCLUDED.tip_amount,
      payout_amount = EXCLUDED.payout_amount,
      payout_status = CASE
        WHEN public.monthly_statements.payout_status IN ('approved','paid')
          THEN public.monthly_statements.payout_status
        ELSE 'pending'
      END,
      generated_at = now();
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('success',true,'count',v_count,'year',v_year,'month',v_month);
END; $$;
GRANT EXECUTE ON FUNCTION public.generate_payout_snapshot_unified() TO authenticated;

-- admin_list_statements
CREATE OR REPLACE FUNCTION public.admin_list_statements(
  p_gender text DEFAULT NULL, p_year int DEFAULT NULL, p_month int DEFAULT NULL,
  p_payout_status text DEFAULT NULL, p_user_id uuid DEFAULT NULL,
  p_limit int DEFAULT 100, p_offset int DEFAULT 0
) RETURNS TABLE (
  statement_id uuid, user_id uuid, full_name text, gender text,
  year int, month int, opening_balance numeric, total_credit numeric,
  total_debit numeric, closing_balance numeric, chat_amount numeric,
  audio_call_amount numeric, video_call_amount numeric, group_call_amount numeric,
  gift_amount numeric, tip_amount numeric, recharge_amount numeric,
  payout_amount numeric, payout_status text, pdf_url text, excel_url text,
  generated_at timestamptz, paid_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin') THEN
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
    JOIN public.profiles p ON p.id = ms.user_id
    WHERE (p_gender IS NULL OR ms.gender = p_gender)
      AND (p_year IS NULL OR ms.year = p_year)
      AND (p_month IS NULL OR ms.month = p_month)
      AND (p_payout_status IS NULL OR ms.payout_status = p_payout_status)
      AND (p_user_id IS NULL OR ms.user_id = p_user_id)
    ORDER BY ms.year DESC, ms.month DESC, ms.payout_amount DESC
    LIMIT p_limit OFFSET p_offset;
END; $$;
GRANT EXECUTE ON FUNCTION public.admin_list_statements(text,int,int,text,uuid,int,int) TO authenticated;

-- admin_update_payout
CREATE OR REPLACE FUNCTION public.admin_update_payout(
  p_statement_id uuid, p_status text DEFAULT NULL,
  p_pdf_url text DEFAULT NULL, p_excel_url text DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;
  UPDATE public.monthly_statements SET
    payout_status = COALESCE(p_status, payout_status),
    pdf_url = COALESCE(p_pdf_url, pdf_url),
    excel_url = COALESCE(p_excel_url, excel_url),
    notes = COALESCE(p_notes, notes),
    paid_at = CASE WHEN p_status = 'paid' AND paid_at IS NULL THEN now() ELSE paid_at END
  WHERE id = p_statement_id AND gender = 'female';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','Statement not found');
  END IF;
  RETURN jsonb_build_object('success',true);
END; $$;
GRANT EXECUTE ON FUNCTION public.admin_update_payout(uuid,text,text,text,text) TO authenticated;

-- Override ledger_recharge to ALSO write into billing_ledger so men's recharges
-- show in monthly statements as recharge_amount (per user request).
CREATE OR REPLACE FUNCTION public.ledger_recharge(
  p_user_id uuid, p_amount numeric, p_reference_id text DEFAULT NULL,
  p_gateway text DEFAULT 'razorpay', p_gateway_txn_id text DEFAULT NULL,
  p_description text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_wallet RECORD;
  v_balance_after numeric(10,2);
  v_man_id uuid;
  v_idem text;
BEGIN
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','amount must be > 0');
  END IF;

  v_idem := 'recharge|' || p_user_id::text || '|' || COALESCE(p_gateway_txn_id, p_reference_id, EXTRACT(EPOCH FROM now())::text);
  IF EXISTS (SELECT 1 FROM public.billing_ledger WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO public.wallets (user_id, balance, currency)
      VALUES (p_user_id, 0, 'INR') RETURNING * INTO v_wallet;
  END IF;

  v_balance_after := v_wallet.balance + p_amount;
  UPDATE public.wallets SET balance = v_balance_after, updated_at = now() WHERE id = v_wallet.id;

  SELECT id INTO v_man_id FROM public.profiles WHERE user_id = p_user_id;

  IF v_man_id IS NOT NULL THEN
    INSERT INTO public.billing_ledger (
      man_id, entry_type, amount, balance_after, session_type,
      rate_applied, description, reference_id, idempotency_key, status
    ) VALUES (
      v_man_id, 'credit', p_amount, v_balance_after, 'recharge',
      p_amount,
      COALESCE(p_description, 'Wallet recharge — ₹' || p_amount || ' via ' || p_gateway),
      COALESCE(p_gateway_txn_id, p_reference_id), v_idem, 'completed'
    );
  END IF;

  RETURN jsonb_build_object('success',true,'balance',v_balance_after,'amount',p_amount);
END; $$;
GRANT EXECUTE ON FUNCTION public.ledger_recharge(uuid,numeric,text,text,text,text) TO authenticated, service_role;
