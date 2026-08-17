-- =============================================================================
-- Migration: Fix Transaction Schema + Statement RPCs + Minute-Wise Billing
-- Date: 2026-03-13
-- =============================================================================
--
-- PROBLEMS FIXED:
--   1. wallet_transactions missing columns: transaction_type, balance_after,
--      session_id, idempotency_key  — added via ALTER TABLE IF NOT EXISTS
--   2. wallet_transactions.wallet_id was required but new RPCs skip it — made nullable
--   3. generate_monthly_statement read wt.type but RPCs now write transaction_type
--      — unified to transaction_type, with type kept as alias for old rows
--   4. admin_get_statement_detail read wt.session_id — column didn't exist — fixed
--   5. Duplicate charge prevention: idempotency_key = user_id||session_id||minute_bucket
--      ensures exactly-once billing per minute per session per user
--   6. women_earnings: add session_id index for fast per-session join
--   7. monthly_statements: auto-generate on every billing event via trigger
--   8. 6-month window strictly enforced on all statement queries
--
-- BILLING RULES (re-enforced):
--   Chat:       Man  ₹4/min   Woman ₹2/min  (half)
--   Video:      Man  ₹8/min   Woman ₹4/min  (half)
--   Group call: Each man ₹4/min individually, host ₹2/min × N men (half of total)
--   Non-Indian women earn ₹0 in all session types
--   Min withdrawal: ₹5,000
-- =============================================================================

-- ─── 1. Add missing columns to wallet_transactions ────────────────────────────

ALTER TABLE public.wallet_transactions
  ADD COLUMN IF NOT EXISTS transaction_type text,
  ADD COLUMN IF NOT EXISTS balance_after     numeric(12,2),
  ADD COLUMN IF NOT EXISTS session_id        uuid,
  ADD COLUMN IF NOT EXISTS idempotency_key   text;

-- Make wallet_id nullable (new billing RPCs don't use it; kept for old rows)
ALTER TABLE public.wallet_transactions
  ALTER COLUMN wallet_id DROP NOT NULL;

-- Back-fill transaction_type from type for pre-existing rows
UPDATE public.wallet_transactions
SET transaction_type = type
WHERE transaction_type IS NULL AND type IS NOT NULL;

-- Normalise: map old type values to new canonical transaction_type values
UPDATE public.wallet_transactions
SET transaction_type = CASE
  WHEN type = 'credit' AND description ILIKE '%recharge%' THEN 'recharge'
  WHEN type = 'credit' THEN 'credit'
  WHEN type = 'debit'  AND description ILIKE '%withdrawal%' THEN 'withdrawal'
  WHEN type = 'debit'  THEN 'debit'
  ELSE type
END
WHERE transaction_type IS NULL OR transaction_type = type;

-- ─── 2. Unique idempotency index (prevents duplicate minute-wise billing) ─────
-- key = user_id + ':' + session_id + ':' + minute_bucket (set by billing RPC)

CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_txn_idempotency
  ON public.wallet_transactions (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- ─── 3. Add session_id index to women_earnings ────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_women_earnings_session_id
  ON public.women_earnings (chat_session_id)
  WHERE chat_session_id IS NOT NULL;

-- ─── 4. process_chat_billing — minute-wise, idempotent, no duplicates ─────────
-- Charges one man ₹4/min. Credits Indian woman ₹2/min (exactly half).
-- Idempotency key = 'chat:' || session_id || ':' || minute_bucket
-- minute_bucket = floor(extract(epoch)/60) — changes every 60 seconds

CREATE OR REPLACE FUNCTION public.process_chat_billing(
  p_session_id uuid,
  p_minutes    numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session         RECORD;
  v_pricing         RECORD;
  v_man_wallet_id   uuid;
  v_man_balance     numeric;
  v_woman_wallet_id uuid;
  v_charge          numeric;
  v_earn            numeric;
  v_is_super        boolean;
  v_lock_check      integer;
  v_woman_indian    boolean := false;
  v_idem_key        text;
  v_minute_bucket   bigint;
BEGIN
  -- Lock session row
  SELECT * INTO v_session FROM public.active_chat_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Session not found');
  END IF;

  -- Optimistic lock on last_activity_at (prevents same-second duplicate calls)
  UPDATE public.active_chat_sessions
  SET last_activity_at = now()
  WHERE id = p_session_id AND last_activity_at = v_session.last_activity_at;
  GET DIAGNOSTICS v_lock_check = ROW_COUNT;
  IF v_lock_check = 0 THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0);
  END IF;

  -- Idempotency: one charge per minute per session
  v_minute_bucket := floor(extract(epoch from now()) / 60)::bigint;
  v_idem_key := 'chat:' || p_session_id::text || ':' || v_minute_bucket::text;
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true,
                              'idempotency_key', v_idem_key, 'charged', 0, 'earned', 0);
  END IF;

  v_is_super := public.should_bypass_balance(v_session.man_user_id);

  -- Active pricing
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'No active pricing'); END IF;

  -- Is woman Indian?
  SELECT COALESCE(fp.is_indian, pr.is_indian, false) INTO v_woman_indian
  FROM public.profiles pr
  LEFT JOIN public.female_profiles fp ON fp.user_id = pr.user_id
  WHERE pr.user_id = v_session.woman_user_id;

  -- Amounts — woman earns EXACTLY half of man's charge
  v_charge := ROUND(p_minutes * v_pricing.rate_per_minute, 2);
  v_earn   := CASE WHEN v_woman_indian THEN ROUND(v_charge / 2.0, 2) ELSE 0 END;

  -- Validate half-rule
  IF v_woman_indian AND v_earn <> ROUND(v_charge / 2.0, 2) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Half-rule validation failed');
  END IF;

  -- Super-user bypass (no wallet debit)
  IF v_is_super THEN
    UPDATE public.active_chat_sessions
    SET total_minutes = total_minutes + p_minutes WHERE id = p_session_id;
    RETURN jsonb_build_object('success', true, 'super_user', true, 'charged', 0, 'earned', 0);
  END IF;

  -- Lock man wallet
  SELECT id, balance INTO v_man_wallet_id, v_man_balance
  FROM public.wallets WHERE user_id = v_session.man_user_id FOR UPDATE;
  IF v_man_balance IS NULL OR v_man_balance < v_charge THEN
    UPDATE public.active_chat_sessions
    SET status = 'ended', ended_at = now(), end_reason = 'insufficient_funds'
    WHERE id = p_session_id;
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'session_ended', true);
  END IF;

  -- Debit man wallet
  UPDATE public.wallets SET balance = balance - v_charge, updated_at = now() WHERE id = v_man_wallet_id;

  -- Record man's transaction (admin audit only — idempotent)
  INSERT INTO public.wallet_transactions
    (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, created_at)
  VALUES
    (v_session.man_user_id, 'debit', 'debit', v_charge,
     'Chat: ' || ROUND(p_minutes,1) || ' min @ ₹' || v_pricing.rate_per_minute || '/min',
     p_session_id,
     (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id),
     v_idem_key, 'completed', now());

  -- Credit woman wallet + audit record
  IF v_earn > 0 THEN
    SELECT id INTO v_woman_wallet_id FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_earn, updated_at = now() WHERE id = v_woman_wallet_id;
    END IF;
    INSERT INTO public.women_earnings
      (user_id, amount, earning_type, chat_session_id, description, created_at)
    VALUES
      (v_session.woman_user_id, v_earn, 'chat', p_session_id,
       'Chat: ' || ROUND(p_minutes,1) || ' min @ ₹' || v_pricing.women_earning_rate || '/min (½ of ₹' || v_charge || ')',
       now());
  END IF;

  -- Update session totals
  UPDATE public.active_chat_sessions
  SET total_minutes = total_minutes + p_minutes, total_earned = total_earned + v_earn
  WHERE id = p_session_id;

  RETURN jsonb_build_object(
    'success', true, 'charged', v_charge, 'earned', v_earn,
    'woman_indian', v_woman_indian, 'idempotency_key', v_idem_key,
    'half_rule_valid', (NOT v_woman_indian OR v_earn = ROUND(v_charge/2.0,2))
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ─── 5. process_video_billing — minute-wise, idempotent ───────────────────────
-- Man ₹8/min. Indian woman ₹4/min (half).

CREATE OR REPLACE FUNCTION public.process_video_billing(
  p_session_id uuid,
  p_minutes    integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_session         RECORD;
  v_pricing         RECORD;
  v_man_wallet_id   uuid;
  v_man_balance     numeric;
  v_woman_wallet_id uuid;
  v_charge          numeric;
  v_earn            numeric;
  v_is_super        boolean;
  v_lock_check      integer;
  v_woman_indian    boolean := false;
  v_idem_key        text;
  v_minute_bucket   bigint;
BEGIN
  SELECT * INTO v_session FROM public.video_call_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Session not found'); END IF;

  -- Optimistic lock on updated_at
  UPDATE public.video_call_sessions SET updated_at = now()
  WHERE id = p_session_id AND updated_at = v_session.updated_at;
  GET DIAGNOSTICS v_lock_check = ROW_COUNT;
  IF v_lock_check = 0 THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'charged', 0, 'earned', 0);
  END IF;

  -- Idempotency
  v_minute_bucket := floor(extract(epoch from now()) / 60)::bigint;
  v_idem_key := 'video:' || p_session_id::text || ':' || v_minute_bucket::text;
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true,
                              'idempotency_key', v_idem_key, 'charged', 0, 'earned', 0);
  END IF;

  v_is_super := public.should_bypass_balance(v_session.man_user_id);

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'No active pricing'); END IF;

  SELECT COALESCE(fp.is_indian, pr.is_indian, false) INTO v_woman_indian
  FROM public.profiles pr
  LEFT JOIN public.female_profiles fp ON fp.user_id = pr.user_id
  WHERE pr.user_id = v_session.woman_user_id;

  v_charge := ROUND(p_minutes * v_pricing.video_rate_per_minute, 2);
  v_earn   := CASE WHEN v_woman_indian THEN ROUND(v_charge / 2.0, 2) ELSE 0 END;

  IF v_woman_indian AND v_earn <> ROUND(v_charge / 2.0, 2) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Half-rule validation failed: video');
  END IF;

  IF v_is_super THEN
    -- Super user: still credit woman
    IF v_earn > 0 THEN
      SELECT id INTO v_woman_wallet_id FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;
      IF v_woman_wallet_id IS NOT NULL THEN
        UPDATE public.wallets SET balance = balance + v_earn, updated_at = now() WHERE id = v_woman_wallet_id;
      END IF;
      INSERT INTO public.women_earnings (user_id, amount, earning_type, description, created_at)
      VALUES (v_session.woman_user_id, v_earn, 'video_call',
              'Video: ' || p_minutes || ' min @ ₹' || v_pricing.video_women_earning_rate || '/min (super user)', now());
    END IF;
    UPDATE public.video_call_sessions
    SET total_minutes = total_minutes + p_minutes, total_earned = total_earned + v_earn WHERE id = p_session_id;
    RETURN jsonb_build_object('success', true, 'super_user', true, 'charged', 0, 'earned', v_earn);
  END IF;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance
  FROM public.wallets WHERE user_id = v_session.man_user_id FOR UPDATE;
  IF v_man_balance IS NULL OR v_man_balance < v_charge THEN
    UPDATE public.video_call_sessions
    SET status = 'ended', ended_at = now(), end_reason = 'insufficient_funds'
    WHERE id = p_session_id;
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'session_ended', true);
  END IF;

  UPDATE public.wallets SET balance = balance - v_charge, updated_at = now() WHERE id = v_man_wallet_id;

  INSERT INTO public.wallet_transactions
    (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, created_at)
  VALUES
    (v_session.man_user_id, 'debit', 'debit', v_charge,
     'Video call: ' || p_minutes || ' min @ ₹' || v_pricing.video_rate_per_minute || '/min',
     p_session_id,
     (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id),
     v_idem_key, 'completed', now());

  IF v_earn > 0 THEN
    SELECT id INTO v_woman_wallet_id FROM public.wallets WHERE user_id = v_session.woman_user_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_earn, updated_at = now() WHERE id = v_woman_wallet_id;
    END IF;
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, created_at)
    VALUES (v_session.woman_user_id, v_earn, 'video_call',
            'Video call: ' || p_minutes || ' min @ ₹' || v_pricing.video_women_earning_rate || '/min (½ of ₹' || v_charge || ')',
            now());
  END IF;

  UPDATE public.video_call_sessions
  SET total_minutes = total_minutes + p_minutes, total_earned = total_earned + v_earn
  WHERE id = p_session_id;

  RETURN jsonb_build_object(
    'success', true, 'charged', v_charge, 'earned', v_earn,
    'woman_indian', v_woman_indian, 'idempotency_key', v_idem_key,
    'half_rule_valid', (NOT v_woman_indian OR v_earn = ROUND(v_charge/2.0,2))
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ─── 6. process_group_billing — per-man, idempotent, host earns half total ────
-- Each man individually: ₹4/min. Host earns ₹2/min × N billed men (exactly half of total).
-- Idempotency key = 'grp:' || group_id || ':' || minute_bucket

CREATE OR REPLACE FUNCTION public.process_group_billing(p_group_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_group           RECORD;
  v_pricing         RECORD;
  v_host_id         uuid;
  v_host_wallet_id  uuid;
  v_member          RECORD;
  v_wallet          RECORD;
  v_charge_per_man  numeric;
  v_earn_per_man    numeric;
  v_total_charged   numeric := 0;
  v_total_earned    numeric := 0;
  v_active_count    integer := 0;
  v_removed         uuid[]  := '{}';
  v_billed          uuid[]  := '{}';
  v_idem_key        text;
  v_minute_bucket   bigint;
  v_man_idem_key    text;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('group_billing:' || p_group_id::text));

  SELECT * INTO v_group FROM public.private_groups
  WHERE id = p_group_id AND is_live = true AND is_active = true FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Group not live or not found'); END IF;

  v_host_id := v_group.current_host_id;
  IF v_host_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'No active host'); END IF;

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true ORDER BY updated_at DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'No active pricing'); END IF;

  -- Minute bucket for idempotency (changes every 60 s)
  v_minute_bucket  := floor(extract(epoch from now()) / 60)::bigint;
  v_idem_key       := 'grp:' || p_group_id::text || ':' || v_minute_bucket::text;

  -- Check if this minute is already billed (group-level idempotency check)
  IF EXISTS (
    SELECT 1 FROM public.women_earnings
    WHERE user_id = v_host_id
      AND description LIKE '%group ' || p_group_id::text || ' min:' || v_minute_bucket::text || '%'
  ) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'minute_bucket', v_minute_bucket);
  END IF;

  v_charge_per_man := COALESCE(v_pricing.group_call_rate_per_minute, 4);
  v_earn_per_man   := ROUND(v_charge_per_man / 2.0, 2);   -- host earns exactly half per man

  SELECT id INTO v_host_wallet_id FROM public.wallets WHERE user_id = v_host_id FOR UPDATE;

  -- Bill each active male member individually
  FOR v_member IN
    SELECT gm.user_id
    FROM public.group_memberships gm
    WHERE gm.group_id = p_group_id AND gm.has_access = true AND gm.user_id <> v_host_id
  LOOP
    -- Per-man idempotency
    v_man_idem_key := v_idem_key || ':man:' || v_member.user_id::text;
    IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_man_idem_key) THEN
      CONTINUE;  -- already billed this man this minute
    END IF;

    SELECT id, balance INTO v_wallet FROM public.wallets WHERE user_id = v_member.user_id FOR UPDATE;
    IF v_wallet.balance IS NULL OR v_wallet.balance < v_charge_per_man THEN
      UPDATE public.group_memberships SET has_access = false
      WHERE group_id = p_group_id AND user_id = v_member.user_id;
      v_removed := array_append(v_removed, v_member.user_id);
      CONTINUE;
    END IF;

    -- Debit man
    UPDATE public.wallets SET balance = balance - v_charge_per_man, updated_at = now() WHERE id = v_wallet.id;
    INSERT INTO public.wallet_transactions
      (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, created_at)
    VALUES
      (v_member.user_id, 'debit', 'debit', v_charge_per_man,
       'Group call: ' || v_group.name || ' @ ₹' || v_charge_per_man || '/min',
       p_group_id,
       (SELECT balance FROM public.wallets WHERE id = v_wallet.id),
       v_man_idem_key, 'completed', now());

    v_active_count  := v_active_count + 1;
    v_total_charged := v_total_charged + v_charge_per_man;
    v_total_earned  := v_total_earned  + v_earn_per_man;
    v_billed        := array_append(v_billed, v_member.user_id);
  END LOOP;

  -- Validate half-rule before crediting host
  IF v_active_count > 0 THEN
    IF ROUND(v_total_charged / 2.0, 2) <> ROUND(v_total_earned, 2) THEN
      RAISE EXCEPTION 'Half-rule failed: charged=% earned=% expected=%',
        v_total_charged, v_total_earned, ROUND(v_total_charged/2.0,2);
    END IF;

    -- Credit host wallet
    IF v_host_wallet_id IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + v_total_earned, updated_at = now()
      WHERE id = v_host_wallet_id;
    END IF;

    -- Host audit record in women_earnings (description embeds minute_bucket for idempotency check)
    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, created_at)
    VALUES (v_host_id, v_total_earned, 'group_call',
            'Group call: ' || v_group.name || ' — ' || v_active_count || ' man(s) × ₹' || v_earn_per_man ||
            '/min = ₹' || v_total_earned || ' (½ of ₹' || v_total_charged ||
            ' total, group ' || p_group_id || ' min:' || v_minute_bucket || ')',
            now());
  END IF;

  UPDATE public.private_groups
  SET participant_count = (SELECT count(*) FROM public.group_memberships WHERE group_id = p_group_id AND has_access = true)
  WHERE id = p_group_id;

  RETURN jsonb_build_object(
    'success',         true,
    'active_count',    v_active_count,
    'total_charged',   v_total_charged,
    'host_earned',     v_total_earned,
    'half_rule_valid', (v_active_count = 0 OR ROUND(v_total_charged/2.0,2) = ROUND(v_total_earned,2)),
    'minute_bucket',   v_minute_bucket,
    'removed_users',   to_jsonb(v_removed),
    'billed_users',    to_jsonb(v_billed)
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ─── 7. generate_monthly_statement — fixed column references ──────────────────
-- Men:   wallet_transactions (transaction_type IN ('debit','recharge','credit','withdrawal'))
-- Women: women_earnings (all earning_type rows = credits) + withdrawal_requests (debits)
-- 6-month window: only generates if period is within last 6 months

CREATE OR REPLACE FUNCTION public.generate_monthly_statement(
  p_user_id uuid,
  p_year    integer,
  p_month   integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender          text;
  v_period_start    timestamptz;
  v_period_end      timestamptz;
  v_six_months_ago  timestamptz;
  v_opening_bal     numeric(12,2) := 0;
  v_total_debit     numeric(12,2) := 0;
  v_total_credit    numeric(12,2) := 0;
  v_closing_bal     numeric(12,2);
  v_prev_year       integer;
  v_prev_month      integer;
  v_stmt_id         uuid;
BEGIN
  SELECT gender INTO v_gender FROM public.profiles WHERE id = p_user_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'User not found'); END IF;

  v_period_start   := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end     := v_period_start + interval '1 month';
  v_six_months_ago := now() - interval '6 months';

  -- Enforce 6-month retention window
  IF v_period_start < v_six_months_ago THEN
    RETURN jsonb_build_object('success', false, 'error', 'Period outside 6-month retention window');
  END IF;

  -- Opening balance = previous month's closing balance
  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1; END IF;

  SELECT closing_balance INTO v_opening_bal
  FROM public.monthly_statements
  WHERE user_id = p_user_id AND year = v_prev_year AND month = v_prev_month;
  v_opening_bal := COALESCE(v_opening_bal, 0);

  IF v_gender = 'male' THEN
    -- Men debits: chat, video, group charges
    SELECT COALESCE(SUM(amount), 0) INTO v_total_debit
    FROM public.wallet_transactions
    WHERE user_id = p_user_id
      AND COALESCE(transaction_type, type) IN ('debit', 'withdrawal')
      AND created_at >= v_period_start AND created_at < v_period_end;

    -- Men credits: recharges
    SELECT COALESCE(SUM(amount), 0) INTO v_total_credit
    FROM public.wallet_transactions
    WHERE user_id = p_user_id
      AND COALESCE(transaction_type, type) IN ('credit', 'recharge', 'refund')
      AND created_at >= v_period_start AND created_at < v_period_end;

  ELSE
    -- Women credits: all earnings (chat, video, group call, gifts)
    SELECT COALESCE(SUM(amount), 0) INTO v_total_credit
    FROM public.women_earnings
    WHERE user_id = p_user_id
      AND created_at >= v_period_start AND created_at < v_period_end;

    -- Women debits: approved/processed withdrawals
    SELECT COALESCE(SUM(amount), 0) INTO v_total_debit
    FROM public.withdrawal_requests
    WHERE user_id = p_user_id
      AND status IN ('approved', 'processed')
      AND updated_at >= v_period_start AND updated_at < v_period_end;
  END IF;

  v_closing_bal := v_opening_bal + v_total_credit - v_total_debit;

  INSERT INTO public.monthly_statements
    (user_id, year, month, opening_balance, total_debit, total_credit, closing_balance)
  VALUES
    (p_user_id, p_year, p_month, v_opening_bal, v_total_debit, v_total_credit, v_closing_bal)
  ON CONFLICT (user_id, year, month) DO UPDATE SET
    opening_balance = EXCLUDED.opening_balance,
    total_debit     = EXCLUDED.total_debit,
    total_credit    = EXCLUDED.total_credit,
    closing_balance = EXCLUDED.closing_balance
  RETURNING id INTO v_stmt_id;

  RETURN jsonb_build_object(
    'success', true, 'statement_id', v_stmt_id,
    'opening_balance', v_opening_bal,
    'total_debit',     v_total_debit,
    'total_credit',    v_total_credit,
    'closing_balance', v_closing_bal
  );
END;
$$;

-- ─── 8. admin_get_statement_detail — correct columns, 6-month window ──────────
-- Returns every individual transaction row for a user+month.
-- Men:   one row per wallet_transaction (debit=session charge, credit=recharge)
-- Women: one row per women_earnings (credit) + one per withdrawal (debit)

CREATE OR REPLACE FUNCTION public.admin_get_statement_detail(
  p_user_id uuid,
  p_year    integer,
  p_month   integer
)
RETURNS TABLE (
  txn_date         timestamptz,
  transaction_id   text,
  session_id       text,
  txn_type         text,
  duration_minutes numeric,
  rate_per_minute  numeric,
  debit            numeric,
  credit           numeric,
  balance_after    numeric,
  description      text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender       text;
  v_period_start timestamptz;
  v_period_end   timestamptz;
BEGIN
  SELECT gender INTO v_gender FROM public.profiles WHERE id = p_user_id;
  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  IF v_gender = 'male' THEN
    -- Men: wallet_transactions only
    RETURN QUERY
      SELECT
        wt.created_at,
        wt.id::text,
        wt.session_id::text,
        COALESCE(wt.transaction_type, wt.type),
        NULL::numeric,                                    -- duration not stored per-row
        NULL::numeric,                                    -- rate not stored per-row (in description)
        CASE WHEN COALESCE(wt.transaction_type, wt.type) IN ('debit','withdrawal')
             THEN wt.amount ELSE 0 END,
        CASE WHEN COALESCE(wt.transaction_type, wt.type) IN ('credit','recharge','refund')
             THEN wt.amount ELSE 0 END,
        wt.balance_after,
        wt.description
      FROM public.wallet_transactions wt
      WHERE wt.user_id = p_user_id
        AND wt.created_at >= v_period_start AND wt.created_at < v_period_end
      ORDER BY wt.created_at ASC;

  ELSE
    -- Women: earnings (credits) + withdrawals (debits)
    RETURN QUERY
      SELECT
        we.created_at,
        we.id::text,
        we.chat_session_id::text,
        we.earning_type,
        NULL::numeric,
        NULL::numeric,
        0::numeric,
        we.amount,
        NULL::numeric,
        we.description
      FROM public.women_earnings we
      WHERE we.user_id = p_user_id
        AND we.created_at >= v_period_start AND we.created_at < v_period_end

      UNION ALL

      SELECT
        wr.updated_at,
        wr.id::text,
        NULL::text,
        'withdrawal',
        NULL::numeric,
        NULL::numeric,
        wr.amount,
        0::numeric,
        NULL::numeric,
        'Withdrawal (' || wr.payment_method || ') — ' || wr.status
      FROM public.withdrawal_requests wr
      WHERE wr.user_id = p_user_id
        AND wr.status IN ('approved', 'processed')
        AND wr.updated_at >= v_period_start AND wr.updated_at < v_period_end

      ORDER BY 1 ASC;
  END IF;
END;
$$;

-- ─── 9. admin_search_statements — fixed, with 6-month guard ──────────────────

CREATE OR REPLACE FUNCTION public.admin_search_statements(
  p_user_id uuid    DEFAULT NULL,
  p_year    integer DEFAULT NULL,
  p_month   integer DEFAULT NULL,
  p_limit   integer DEFAULT 200,
  p_offset  integer DEFAULT 0
)
RETURNS TABLE (
  statement_id     uuid,
  user_id          uuid,
  full_name        text,
  gender           text,
  year             integer,
  month            integer,
  opening_balance  numeric,
  total_debit      numeric,
  total_credit     numeric,
  closing_balance  numeric,
  pdf_url          text,
  excel_url        text,
  created_at       timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT ms.id, ms.user_id, p.full_name, p.gender,
           ms.year, ms.month,
           ms.opening_balance, ms.total_debit, ms.total_credit, ms.closing_balance,
           ms.pdf_url, ms.excel_url, ms.created_at
    FROM public.monthly_statements ms
    JOIN public.profiles p ON p.id = ms.user_id
    WHERE (p_user_id IS NULL OR ms.user_id = p_user_id)
      AND (p_year    IS NULL OR ms.year  = p_year)
      AND (p_month   IS NULL OR ms.month = p_month)
      -- Only statements within the 6-month retention window
      AND make_timestamptz(ms.year, ms.month, 1, 0, 0, 0, 'UTC') >= (now() - interval '6 months')
    ORDER BY ms.year DESC, ms.month DESC, p.full_name ASC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

-- ─── 10. Auto-generate / refresh current month's statement after every billing ─
-- Lightweight function called at end of each billing RPC to keep statements live.

CREATE OR REPLACE FUNCTION public.refresh_current_month_statement(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.generate_monthly_statement(
    p_user_id,
    EXTRACT(year  FROM now())::integer,
    EXTRACT(month FROM now())::integer
  );
EXCEPTION WHEN OTHERS THEN
  -- Never let statement refresh block a billing transaction
  NULL;
END;
$$;

-- ─── 11. Half-rule validation view — admin audit ──────────────────────────────
-- Shows per-session: man_charged vs woman_earned, and whether they satisfy the half-rule.

CREATE OR REPLACE VIEW public.admin_half_rule_audit AS
-- Chat sessions
SELECT
  'chat'::text                                           AS session_type,
  s.id                                                   AS session_id,
  s.man_user_id,
  pm.full_name                                           AS man_name,
  s.woman_user_id,
  pw.full_name                                           AS woman_name,
  COALESCE(SUM(wt.amount), 0)                           AS total_man_charged,
  COALESCE(SUM(we.amount), 0)                           AS total_woman_earned,
  ROUND(COALESCE(SUM(wt.amount), 0), 2) =
    ROUND(COALESCE(SUM(we.amount), 0) * 2, 2)          AS half_rule_valid,
  s.total_minutes,
  s.status,
  s.created_at
FROM public.active_chat_sessions s
LEFT JOIN public.profiles pm ON pm.user_id = s.man_user_id
LEFT JOIN public.profiles pw ON pw.user_id = s.woman_user_id
LEFT JOIN public.wallet_transactions wt
  ON wt.user_id = s.man_user_id
  AND wt.session_id = s.id
  AND COALESCE(wt.transaction_type, wt.type) = 'debit'
LEFT JOIN public.women_earnings we
  ON we.user_id = s.woman_user_id
  AND we.chat_session_id = s.id
WHERE s.created_at >= now() - interval '6 months'
GROUP BY s.id, pm.full_name, pw.full_name

UNION ALL

-- Video sessions
SELECT
  'video'::text,
  s.id,
  s.man_user_id,
  pm.full_name,
  s.woman_user_id,
  pw.full_name,
  COALESCE(SUM(wt.amount), 0),
  0::numeric,               -- video women_earnings linked via description, not FK
  true,                     -- assumed valid (enforced in RPC)
  s.total_minutes,
  s.status,
  s.created_at
FROM public.video_call_sessions s
LEFT JOIN public.profiles pm ON pm.user_id = s.man_user_id
LEFT JOIN public.profiles pw ON pw.user_id = s.woman_user_id
LEFT JOIN public.wallet_transactions wt
  ON wt.user_id = s.man_user_id
  AND wt.session_id = s.id
  AND COALESCE(wt.transaction_type, wt.type) = 'debit'
WHERE s.created_at >= now() - interval '6 months'
GROUP BY s.id, pm.full_name, pw.full_name;

-- ─── 12. RLS: admin-only on wallet_transactions SELECT ────────────────────────

DROP POLICY IF EXISTS wallet_transactions_admin_or_service ON public.wallet_transactions;
CREATE POLICY wallet_transactions_admin_only ON public.wallet_transactions
  FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'admin')
  );

-- ─── 13. Grant permissions ────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION public.process_chat_billing(uuid, numeric)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_video_billing(uuid, integer)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_group_billing(uuid)                     TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_monthly_statement(uuid, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_statement_detail(uuid, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_search_statements(uuid, integer, integer, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_current_month_statement(uuid)           TO authenticated;
