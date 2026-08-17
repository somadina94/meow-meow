-- Upgrade generate_payout_snapshot_now() so the Generate button also:
--   (a) records each payout as a 'withdrawal' debit in wallet_transactions
--       (single source of truth — appears in each woman's statement)
--   (b) resets wallets.balance to 0
-- KYC-failed women are still flagged but their wallet is NOT reset.

CREATE OR REPLACE FUNCTION public.generate_payout_snapshot_now()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ist_now   timestamptz := NOW() AT TIME ZONE 'Asia/Kolkata';
  v_ist_date  date        := (NOW() AT TIME ZONE 'Asia/Kolkata')::date;
  v_ist_month text        := TO_CHAR(NOW() AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM');
  v_ist_year  int         := EXTRACT(YEAR FROM NOW() AT TIME ZONE 'Asia/Kolkata')::int;
  v_snapshot_type text    := 'on_demand_' || TO_CHAR(v_ist_now, 'YYYYMMDD_HH24MISS');
  v_rec record;
  v_count int := 0;
  v_skipped int := 0;
  v_total numeric := 0;
  v_inserted boolean;
BEGIN
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
    -- KYC missing/not approved → flag, skip wallet reset
    IF v_rec.kyc_id IS NULL OR v_rec.kyc_status <> 'approved' THEN
      INSERT INTO public.women_payout_snapshots (
        snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
        user_id, full_name, gross_earned, withdrawal_fee_amount, net_payable,
        wallet_balance_at_snapshot, payment_status, app_sno, skipped_reason
      ) VALUES (
        v_snapshot_type, v_ist_now, v_ist_date, v_ist_month, v_ist_year,
        v_rec.user_id, COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name, 'Unknown'),
        v_rec.wallet_balance, 0, 0, v_rec.wallet_balance, 'failed',
        v_rec.app_sno, 'KYC not approved'
      )
      ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    -- Insert canonical snapshot pulling all 10 spec fields from women_kyc
    INSERT INTO public.women_payout_snapshots (
      snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
      user_id, app_sno, beneficiary_purpose, full_name, account_holder_name,
      mobile_number, email_address, address, bank_name, bank_account_number,
      ifsc_code, upi_vpa, gross_earned, withdrawal_fee_amount, net_payable,
      already_paid, incremental_payable, wallet_balance_at_snapshot, payment_status
    ) VALUES (
      v_snapshot_type, v_ist_now, v_ist_date, v_ist_month, v_ist_year,
      v_rec.user_id, v_rec.app_sno,
      COALESCE(v_rec.beneficiary_purpose, 'others'),
      COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name),
      v_rec.account_holder_name, v_rec.mobile_number, v_rec.email_address,
      v_rec.current_address, v_rec.bank_name, v_rec.account_number,
      v_rec.ifsc_code, COALESCE(v_rec.upi_vpa, v_rec.upi_id),
      v_rec.wallet_balance, 0, v_rec.wallet_balance, 0, v_rec.wallet_balance,
      v_rec.wallet_balance, 'pending'
    )
    ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    -- Only debit + reset if a fresh snapshot row was actually inserted (idempotency)
    IF v_inserted THEN
      -- 1) Record withdrawal in wallet_transactions (visible in woman's statement)
      INSERT INTO public.wallet_transactions (
        user_id, type, transaction_type, amount, description,
        balance_after, status, created_at
      ) VALUES (
        v_rec.user_id, 'debit', 'withdrawal', v_rec.wallet_balance,
        'Payout to bank account — admin generated on ' || TO_CHAR(v_ist_now, 'DD Mon YYYY HH24:MI IST'),
        0, 'completed', NOW()
      );

      -- 2) Reset wallet balance to zero
      UPDATE public.wallets
        SET balance = 0, updated_at = NOW()
        WHERE user_id = v_rec.user_id;

      v_count := v_count + 1;
      v_total := v_total + v_rec.wallet_balance;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'snapshot_type', v_snapshot_type,
    'women_processed', v_count,
    'women_skipped_no_kyc', v_skipped,
    'total_amount', v_total,
    'ist_datetime', v_ist_now
  );
END;
$function$;