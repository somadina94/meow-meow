-- 1. Allow 'monthly' snapshot type
ALTER TABLE public.women_payout_snapshots
  DROP CONSTRAINT IF EXISTS women_payout_snapshots_snapshot_type_check;
ALTER TABLE public.women_payout_snapshots
  ADD CONSTRAINT women_payout_snapshots_snapshot_type_check
  CHECK (snapshot_type = ANY (ARRAY['mid_month','end_month','monthly']));

-- 2. Add spec-required KYC fields (sourced from women_kyc)
ALTER TABLE public.women_payout_snapshots
  ADD COLUMN IF NOT EXISTS app_sno integer,
  ADD COLUMN IF NOT EXISTS beneficiary_purpose text DEFAULT 'others',
  ADD COLUMN IF NOT EXISTS account_holder_name text,
  ADD COLUMN IF NOT EXISTS mobile_number text,
  ADD COLUMN IF NOT EXISTS email_address text,
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS upi_vpa text,
  ADD COLUMN IF NOT EXISTS skipped_reason text;

CREATE INDEX IF NOT EXISTS idx_women_payout_snapshots_user_month
  ON public.women_payout_snapshots(user_id, ist_month, snapshot_type);

-- 3. Helper: get current IST date / month / year
CREATE OR REPLACE FUNCTION public.ist_now()
RETURNS timestamptz
LANGUAGE sql STABLE AS $$ SELECT (NOW() AT TIME ZONE 'Asia/Kolkata')::timestamptz $$;

-- 4. Master monthly payout processor
-- Captures payout snapshots for women + carry-forward statements for men, then resets women wallets.
-- Designed to be idempotent: re-running on the same IST month is a no-op due to the unique constraint.
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
  v_ist_year     integer     := EXTRACT(YEAR FROM NOW() AT TIME ZONE 'Asia/Kolkata')::int;
  v_prev_month   text        := TO_CHAR((NOW() AT TIME ZONE 'Asia/Kolkata') - interval '1 day', 'YYYY-MM');
  v_prev_year    integer     := EXTRACT(YEAR FROM (NOW() AT TIME ZONE 'Asia/Kolkata') - interval '1 day')::int;
  v_prev_month_n integer     := EXTRACT(MONTH FROM (NOW() AT TIME ZONE 'Asia/Kolkata') - interval '1 day')::int;
  v_women_processed int := 0;
  v_women_skipped   int := 0;
  v_men_processed   int := 0;
  v_rec record;
  v_new_balance numeric(12,2);
BEGIN
  -- ============================================================
  -- WOMEN: snapshot payout from KYC, then reset wallet to 0
  -- ============================================================
  FOR v_rec IN
    SELECT
      w.user_id,
      w.balance AS wallet_balance,
      p.app_sno,
      p.app_id,
      k.id AS kyc_id,
      k.verification_status AS kyc_status,
      k.account_holder_name,
      k.full_name_as_per_bank,
      k.bank_name,
      k.account_number,
      k.ifsc_code,
      k.mobile_number,
      k.email_address,
      k.current_address,
      k.upi_id,
      k.upi_vpa,
      k.beneficiary_purpose
    FROM public.wallets w
    JOIN public.profiles p ON p.user_id = w.user_id AND p.gender = 'female'
    LEFT JOIN public.women_kyc k ON k.user_id = w.user_id
    WHERE w.gender = 'female'
      AND w.balance > 0
  LOOP
    -- Skip if KYC not approved (spec section 12)
    IF v_rec.kyc_id IS NULL OR v_rec.kyc_status <> 'approved' THEN
      INSERT INTO public.women_payout_snapshots (
        snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
        user_id, full_name, gross_earned, withdrawal_fee_amount, net_payable,
        wallet_balance_at_snapshot, payment_status, app_sno, skipped_reason
      ) VALUES (
        'monthly', v_ist_now, v_ist_date, v_prev_month, v_prev_year,
        v_rec.user_id, COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name, 'Unknown'),
        v_rec.wallet_balance, 0, 0, v_rec.wallet_balance, 'failed',
        v_rec.app_sno, 'KYC not approved'
      )
      ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;
      v_women_skipped := v_women_skipped + 1;
      CONTINUE;
    END IF;

    -- Insert canonical monthly payout snapshot pulling all fields from women_kyc
    INSERT INTO public.women_payout_snapshots (
      snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
      user_id,
      app_sno,
      beneficiary_purpose,
      full_name,
      account_holder_name,
      mobile_number,
      email_address,
      address,
      bank_name,
      bank_account_number,
      ifsc_code,
      upi_vpa,
      gross_earned,
      withdrawal_fee_amount,
      net_payable,
      already_paid,
      incremental_payable,
      wallet_balance_at_snapshot,
      payment_status
    ) VALUES (
      'monthly', v_ist_now, v_ist_date, v_prev_month, v_prev_year,
      v_rec.user_id,
      v_rec.app_sno,
      COALESCE(v_rec.beneficiary_purpose, 'others'),
      COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name),
      v_rec.account_holder_name,
      v_rec.mobile_number,
      v_rec.email_address,
      v_rec.current_address,
      v_rec.bank_name,
      v_rec.account_number,
      v_rec.ifsc_code,
      COALESCE(v_rec.upi_vpa, v_rec.upi_id),
      v_rec.wallet_balance,            -- gross_earned == final wallet balance
      0,                                -- no withdrawal fee per spec
      v_rec.wallet_balance,            -- net_payable == amount to pay
      0,
      v_rec.wallet_balance,
      v_rec.wallet_balance,
      'pending'
    )
    ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;

    -- Only reset wallet if a fresh row was actually inserted (idempotency)
    IF FOUND THEN
      -- Record the reset as a wallet_transactions ledger entry (single source of truth)
      INSERT INTO public.wallet_transactions (
        user_id, amount, transaction_type, description, balance_after, created_at
      ) VALUES (
        v_rec.user_id, v_rec.wallet_balance, 'reconciliation',
        'Monthly payout reset - moved to admin payout statements',
        0, NOW()
      );

      UPDATE public.wallets
        SET balance = 0, updated_at = NOW()
        WHERE user_id = v_rec.user_id;

      v_women_processed := v_women_processed + 1;
    END IF;
  END LOOP;

  -- ============================================================
  -- MEN: generate carry-forward monthly statement for previous month
  -- ============================================================
  FOR v_rec IN
    SELECT p.user_id
    FROM public.profiles p
    WHERE p.gender = 'male'
  LOOP
    PERFORM public.generate_monthly_statement(v_rec.user_id, v_prev_year, v_prev_month_n);
    v_men_processed := v_men_processed + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'ist_datetime', v_ist_now,
    'ist_date', v_ist_date,
    'period', v_prev_month,
    'women_processed', v_women_processed,
    'women_skipped_no_kyc', v_women_skipped,
    'men_processed', v_men_processed
  );
END;
$$;

REVOKE ALL ON FUNCTION public.process_monthly_payout() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_monthly_payout() TO service_role;