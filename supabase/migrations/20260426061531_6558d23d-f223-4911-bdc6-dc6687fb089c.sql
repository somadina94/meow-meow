-- Upgrade capture_payout_snapshot() to pull all 10 spec fields from women_kyc
-- and use wallet.balance (closing balance) as the payout amount.
-- This makes manual admin-triggered snapshots match the automated 1st-of-month cron.

CREATE OR REPLACE FUNCTION public.capture_payout_snapshot(p_snapshot_type text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ist_now timestamptz;
  v_ist_date date;
  v_ist_month text;
  v_ist_year int;
  v_rec record;
  v_count int := 0;
  v_skipped int := 0;
  v_already_paid numeric;
BEGIN
  v_ist_now   := NOW() AT TIME ZONE 'Asia/Kolkata';
  v_ist_date  := v_ist_now::date;
  v_ist_month := TO_CHAR(v_ist_now, 'YYYY-MM');
  v_ist_year  := EXTRACT(YEAR FROM v_ist_now)::int;

  FOR v_rec IN
    SELECT
      w.user_id,
      w.balance AS wallet_balance,
      p.app_sno,
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
    WHERE w.gender = 'female' AND w.balance > 0
  LOOP
    -- Skip if KYC missing/not approved → flag with skipped_reason
    IF v_rec.kyc_id IS NULL OR v_rec.kyc_status <> 'approved' THEN
      INSERT INTO public.women_payout_snapshots (
        snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
        user_id, full_name, gross_earned, withdrawal_fee_amount, net_payable,
        wallet_balance_at_snapshot, payment_status, app_sno, skipped_reason
      ) VALUES (
        p_snapshot_type, v_ist_now, v_ist_date, v_ist_month, v_ist_year,
        v_rec.user_id, COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name, 'Unknown'),
        v_rec.wallet_balance, 0, 0, v_rec.wallet_balance, 'failed',
        v_rec.app_sno, 'KYC not approved'
      )
      ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    -- Carry forward already paid amount for end_month snapshots
    IF p_snapshot_type = 'end_month' THEN
      SELECT COALESCE(net_payable, 0) INTO v_already_paid
      FROM public.women_payout_snapshots
      WHERE user_id = v_rec.user_id AND ist_month = v_ist_month AND snapshot_type = 'mid_month'
      LIMIT 1;
    ELSE
      v_already_paid := 0;
    END IF;

    -- Insert canonical snapshot pulling all 10 spec fields from women_kyc
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
      p_snapshot_type, v_ist_now, v_ist_date, v_ist_month, v_ist_year,
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
      v_rec.wallet_balance,                            -- gross == closing wallet balance
      0,                                                -- no fee per spec
      v_rec.wallet_balance,                            -- net payable
      COALESCE(v_already_paid, 0),
      v_rec.wallet_balance - COALESCE(v_already_paid, 0),
      v_rec.wallet_balance,                            -- closing balance at snapshot
      'pending'
    )
    ON CONFLICT (user_id, snapshot_type, ist_month)
    DO UPDATE SET
      app_sno                    = EXCLUDED.app_sno,
      beneficiary_purpose        = EXCLUDED.beneficiary_purpose,
      full_name                  = EXCLUDED.full_name,
      account_holder_name        = EXCLUDED.account_holder_name,
      mobile_number              = EXCLUDED.mobile_number,
      email_address              = EXCLUDED.email_address,
      address                    = EXCLUDED.address,
      bank_name                  = EXCLUDED.bank_name,
      bank_account_number        = EXCLUDED.bank_account_number,
      ifsc_code                  = EXCLUDED.ifsc_code,
      upi_vpa                    = EXCLUDED.upi_vpa,
      gross_earned               = EXCLUDED.gross_earned,
      net_payable                = EXCLUDED.net_payable,
      incremental_payable        = EXCLUDED.incremental_payable,
      wallet_balance_at_snapshot = EXCLUDED.wallet_balance_at_snapshot;

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'snapshot_type', p_snapshot_type,
    'women_processed', v_count,
    'women_skipped_no_kyc', v_skipped,
    'ist_datetime', v_ist_now
  );
END;
$function$;