-- =====================================================================
-- Month-end rollover: men carry forward, women swept to payouts → 0
-- Runs at 1st 00:00 IST. Closing balance = sum(credit) - sum(debit).
-- Closing balance never negative (GREATEST(..., 0)).
-- =====================================================================

-- 1) Add entry_type to earnings_ledger so we can record payout debits.
--    Default 'credit' keeps every existing row intact.
ALTER TABLE public.earnings_ledger
  ADD COLUMN IF NOT EXISTS entry_type text NOT NULL DEFAULT 'credit'
    CHECK (entry_type IN ('credit', 'debit'));

CREATE INDEX IF NOT EXISTS idx_earnings_ledger_woman_entry
  ON public.earnings_ledger(woman_id, entry_type);

-- 2) Helper: signed sum for women (credit - debit)
CREATE OR REPLACE FUNCTION public.women_ledger_balance(p_woman_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT GREATEST(
    COALESCE(SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END), 0),
    0
  )::numeric(12,2)
  FROM public.earnings_ledger
  WHERE woman_id = p_woman_id;
$$;

-- 3) Helper: signed sum for men (credit - debit) from billing_ledger
CREATE OR REPLACE FUNCTION public.men_ledger_balance(p_man_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT GREATEST(
    COALESCE(SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE -amount END), 0),
    0
  )::numeric(12,2)
  FROM public.billing_ledger
  WHERE man_id = p_man_id;
$$;

-- 4) Rewrite process_monthly_payout to use new dual-ledger SoT
DROP FUNCTION IF EXISTS public.process_monthly_payout() CASCADE;

CREATE OR REPLACE FUNCTION public.process_monthly_payout()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ist_now      timestamptz := NOW() AT TIME ZONE 'Asia/Kolkata';
  v_ist_date     date        := (NOW() AT TIME ZONE 'Asia/Kolkata')::date;
  v_ist_month    text        := TO_CHAR(NOW() AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM');
  v_prev_date    timestamptz := (NOW() AT TIME ZONE 'Asia/Kolkata') - interval '1 day';
  v_prev_month_t text        := TO_CHAR(v_prev_date, 'YYYY-MM');
  v_prev_year    integer     := EXTRACT(YEAR  FROM v_prev_date)::int;
  v_prev_month_n integer     := EXTRACT(MONTH FROM v_prev_date)::int;
  v_period_start timestamptz;
  v_period_end   timestamptz;
  v_rec record;
  v_user record;
  v_balance numeric(12,2);
  v_credits numeric(12,2);
  v_debits  numeric(12,2);
  v_opening numeric(12,2);
  v_closing numeric(12,2);
  v_chat numeric(12,2); v_audio numeric(12,2); v_video numeric(12,2);
  v_group numeric(12,2); v_gift numeric(12,2); v_tip numeric(12,2); v_recharge numeric(12,2);
  v_women_processed int := 0;
  v_women_skipped   int := 0;
  v_men_processed   int := 0;
BEGIN
  v_period_start := make_timestamptz(v_prev_year, v_prev_month_n, 1, 0, 0, 0, 'Asia/Kolkata');
  v_period_end   := v_period_start + interval '1 month';

  -- ============================================================
  -- WOMEN: closing = sum(credit)-sum(debit). Sweep to payout snapshot,
  --        write debit row so closing_balance = 0, sync wallet to 0.
  -- ============================================================
  FOR v_rec IN
    SELECT
      p.id AS user_id,
      p.app_sno,
      k.id AS kyc_id,
      k.verification_status AS kyc_status,
      k.account_holder_name,
      k.full_name_as_per_bank,
      k.bank_name, k.account_number, k.ifsc_code,
      k.mobile_number, k.email_address, k.current_address,
      k.upi_id, k.upi_vpa, k.beneficiary_purpose
    FROM public.profiles p
    LEFT JOIN public.women_kyc k ON k.user_id = p.id
    WHERE p.gender = 'female'
  LOOP
    -- Compute live ledger balance (credits - debits, never negative)
    v_balance := public.women_ledger_balance(v_rec.user_id);

    IF v_balance <= 0 THEN
      CONTINUE;
    END IF;

    -- Skip payout if KYC not approved (record skipped snapshot for audit)
    IF v_rec.kyc_id IS NULL OR v_rec.kyc_status <> 'approved' THEN
      INSERT INTO public.women_payout_snapshots (
        snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
        user_id, full_name, gross_earned, withdrawal_fee_amount, net_payable,
        wallet_balance_at_snapshot, payment_status, app_sno, skipped_reason
      ) VALUES (
        'monthly', v_ist_now, v_ist_date, v_prev_month_t, v_prev_year,
        v_rec.user_id, COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name, 'Unknown'),
        v_balance, 0, 0, v_balance, 'failed',
        v_rec.app_sno, 'KYC not approved'
      )
      ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;
      v_women_skipped := v_women_skipped + 1;
      CONTINUE;
    END IF;

    -- Insert canonical monthly payout snapshot
    INSERT INTO public.women_payout_snapshots (
      snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
      user_id, app_sno, beneficiary_purpose,
      full_name, account_holder_name, mobile_number, email_address, address,
      bank_name, bank_account_number, ifsc_code, upi_vpa,
      gross_earned, withdrawal_fee_amount, net_payable,
      already_paid, incremental_payable,
      wallet_balance_at_snapshot, payment_status
    ) VALUES (
      'monthly', v_ist_now, v_ist_date, v_prev_month_t, v_prev_year,
      v_rec.user_id, v_rec.app_sno, COALESCE(v_rec.beneficiary_purpose, 'others'),
      COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name),
      v_rec.account_holder_name, v_rec.mobile_number, v_rec.email_address,
      v_rec.current_address, v_rec.bank_name, v_rec.account_number,
      v_rec.ifsc_code, COALESCE(v_rec.upi_vpa, v_rec.upi_id),
      v_balance, 0, v_balance,
      0, v_balance,
      v_balance, 'pending'
    )
    ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;

    IF FOUND THEN
      -- Write the debit row in earnings_ledger so closing balance becomes 0.
      INSERT INTO public.earnings_ledger (
        woman_id, man_id, amount, currency, session_type, session_id,
        duration_minutes, rate_applied, description, entry_type, created_at
      ) VALUES (
        v_rec.user_id, v_rec.user_id, v_balance, 'INR', 'payout', NULL,
        0, 0,
        'Monthly payout sweep '||v_prev_month_t||' → admin payout statements',
        'debit', NOW()
      );

      -- Sync wallets table to 0 (closing_balance for women)
      INSERT INTO public.wallets (user_id, gender, balance, currency, updated_at)
      VALUES (v_rec.user_id, 'female', 0, 'INR', NOW())
      ON CONFLICT (user_id) DO UPDATE SET balance = 0, updated_at = NOW();

      v_women_processed := v_women_processed + 1;
    END IF;

    -- Build the women's monthly statement: credits in period, debit = payout, closing = 0
    SELECT
      COALESCE(SUM(CASE WHEN entry_type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN entry_type='debit'  THEN amount ELSE 0 END),0)
    INTO v_credits, v_debits
    FROM public.earnings_ledger
    WHERE woman_id = v_rec.user_id
      AND created_at >= v_period_start AND created_at < v_period_end;

    SELECT
      COALESCE(SUM(CASE WHEN session_type='chat'               AND entry_type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='audio_call'         AND entry_type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='video_call'         AND entry_type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='private_group_call' AND entry_type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='gift'               AND entry_type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='tip'                AND entry_type='credit' THEN amount ELSE 0 END),0)
    INTO v_chat, v_audio, v_video, v_group, v_gift, v_tip
    FROM public.earnings_ledger
    WHERE woman_id = v_rec.user_id
      AND created_at >= v_period_start AND created_at < v_period_end;

    v_closing := GREATEST(v_credits - v_debits, 0); -- always 0 after sweep

    INSERT INTO public.monthly_statements (
      user_id, gender, year, month, opening_balance, total_credit, total_debit,
      closing_balance, chat_amount, audio_call_amount, video_call_amount,
      group_call_amount, gift_amount, tip_amount, payout_amount, payout_status,
      generated_at
    ) VALUES (
      v_rec.user_id, 'female', v_prev_year, v_prev_month_n,
      0, v_credits, v_debits, v_closing,
      v_chat, v_audio, v_video, v_group, v_gift, v_tip,
      v_balance, CASE WHEN v_balance > 0 THEN 'pending' ELSE 'na' END,
      NOW()
    )
    ON CONFLICT (user_id, year, month) DO UPDATE SET
      total_credit    = EXCLUDED.total_credit,
      total_debit     = EXCLUDED.total_debit,
      closing_balance = EXCLUDED.closing_balance,
      chat_amount     = EXCLUDED.chat_amount,
      audio_call_amount = EXCLUDED.audio_call_amount,
      video_call_amount = EXCLUDED.video_call_amount,
      group_call_amount = EXCLUDED.group_call_amount,
      gift_amount     = EXCLUDED.gift_amount,
      tip_amount      = EXCLUDED.tip_amount,
      payout_amount   = EXCLUDED.payout_amount,
      payout_status   = CASE
        WHEN public.monthly_statements.payout_status IN ('approved','paid')
          THEN public.monthly_statements.payout_status
          ELSE EXCLUDED.payout_status
      END,
      generated_at    = NOW();
  END LOOP;

  -- ============================================================
  -- MEN: closing_balance = opening + credits - debits (carry forward).
  --      Wallet stays as the carry-forward balance (NOT reset).
  -- ============================================================
  FOR v_user IN SELECT id FROM public.profiles WHERE gender = 'male' LOOP
    -- Opening = previous month's closing_balance (or 0 if none)
    SELECT COALESCE(closing_balance, 0) INTO v_opening
    FROM public.monthly_statements
    WHERE user_id = v_user.id
      AND ((year * 12 + month) = (v_prev_year * 12 + v_prev_month_n) - 1);
    v_opening := COALESCE(v_opening, 0);

    SELECT
      COALESCE(SUM(CASE WHEN entry_type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN entry_type='debit'  THEN amount ELSE 0 END),0)
    INTO v_credits, v_debits
    FROM public.billing_ledger
    WHERE man_id = v_user.id
      AND created_at >= v_period_start AND created_at < v_period_end;

    SELECT
      COALESCE(SUM(CASE WHEN session_type='chat'               THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='audio_call'         THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='video_call'         THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='private_group_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='gift'               THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='tip'                THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN session_type='recharge'           THEN amount ELSE 0 END),0)
    INTO v_chat, v_audio, v_video, v_group, v_gift, v_tip, v_recharge
    FROM public.billing_ledger
    WHERE man_id = v_user.id
      AND created_at >= v_period_start AND created_at < v_period_end;

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
    )
    ON CONFLICT (user_id, year, month) DO UPDATE SET
      opening_balance = EXCLUDED.opening_balance,
      total_credit    = EXCLUDED.total_credit,
      total_debit     = EXCLUDED.total_debit,
      closing_balance = EXCLUDED.closing_balance,
      chat_amount     = EXCLUDED.chat_amount,
      audio_call_amount = EXCLUDED.audio_call_amount,
      video_call_amount = EXCLUDED.video_call_amount,
      group_call_amount = EXCLUDED.group_call_amount,
      gift_amount     = EXCLUDED.gift_amount,
      tip_amount      = EXCLUDED.tip_amount,
      recharge_amount = EXCLUDED.recharge_amount,
      generated_at    = NOW();

    -- Sync men's wallet to live ledger balance (carry forward)
    INSERT INTO public.wallets (user_id, gender, balance, currency, updated_at)
    VALUES (v_user.id, 'male', v_closing, 'INR', NOW())
    ON CONFLICT (user_id) DO UPDATE SET
      balance = EXCLUDED.balance, updated_at = NOW();

    v_men_processed := v_men_processed + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'ist_datetime', v_ist_now,
    'ist_date', v_ist_date,
    'period', v_prev_month_t,
    'women_processed', v_women_processed,
    'women_skipped_no_kyc', v_women_skipped,
    'men_processed', v_men_processed
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_monthly_payout() TO service_role;
GRANT EXECUTE ON FUNCTION public.women_ledger_balance(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.men_ledger_balance(uuid) TO authenticated, service_role;