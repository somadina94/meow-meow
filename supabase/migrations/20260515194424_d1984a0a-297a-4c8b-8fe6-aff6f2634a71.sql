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
  v_zero_count int := 0;
  v_skipped int := 0;
  v_total numeric := 0;
  v_inserted int;
  v_wallet RECORD;
  v_idem text;
  v_kyc_ok boolean;
  v_bal numeric;
BEGIN
  -- Iterate over EVERY woman (not just balance > 0) so zero-balance women
  -- are also visible in the statement, with amount specified as 0.
  FOR v_rec IN
    SELECT
      p.user_id,
      COALESCE(w.balance, 0) AS wallet_balance,
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
      k.upi_vpa,
      k.beneficiary_purpose
    FROM public.profiles p
    LEFT JOIN public.wallets w ON w.user_id = p.user_id
    LEFT JOIN public.women_kyc k ON k.user_id = p.user_id
    WHERE p.gender = 'female'
  LOOP
    v_kyc_ok := (v_rec.kyc_id IS NOT NULL AND v_rec.kyc_status = 'approved');
    v_bal := COALESCE(v_rec.wallet_balance, 0);

    -- KYC NOT approved AND there is money to pay → notify, skip from statement.
    IF NOT v_kyc_ok THEN
      IF v_bal > 0 THEN
        INSERT INTO public.notifications (user_id, title, message, type, action_url)
        VALUES (
          v_rec.user_id,
          'Complete your KYC to receive payout',
          'You have ₹' || ROUND(v_bal, 2)::text ||
            ' pending in your wallet. Please complete your bank KYC so we can process your payout in the next cycle.',
          'kyc_required',
          '/kyc'
        );
        v_skipped := v_skipped + 1;
      END IF;
      CONTINUE;
    END IF;

    -- KYC approved → snapshot. Lock wallet only when there's money to debit.
    IF v_bal > 0 THEN
      SELECT * INTO v_wallet FROM public.wallets WHERE user_id = v_rec.user_id FOR UPDATE;
      IF v_wallet.id IS NULL THEN v_bal := 0; END IF;
    END IF;

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
      v_rec.ifsc_code, v_rec.upi_vpa,
      v_bal, 0, v_bal, 0, v_bal,
      v_bal, CASE WHEN v_bal > 0 THEN 'pending' ELSE 'no_balance' END
    )
    ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    IF v_inserted > 0 AND v_bal > 0 THEN
      v_idem := 'payout|' || v_rec.user_id::text || '|' || v_snapshot_type;

      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, session_type,
        amount, balance_after, description, reference_id, idempotency_key, status
      ) VALUES (
        v_wallet.id, v_rec.user_id, 'debit', 'payout', 'payout',
        v_bal, 0,
        'Payout to bank account — admin generated on ' || TO_CHAR(v_ist_now, 'DD Mon YYYY HH24:MI IST'),
        'PAYOUT-' || v_snapshot_type, v_idem, 'completed'
      )
      ON CONFLICT (idempotency_key) DO NOTHING;

      UPDATE public.wallets
        SET balance = 0, updated_at = NOW()
        WHERE id = v_wallet.id;

      v_count := v_count + 1;
      v_total := v_total + v_bal;
    ELSIF v_inserted > 0 THEN
      v_zero_count := v_zero_count + 1;
    END IF;
  END LOOP;

  -- Hide pre-existing KYC-failed snapshot rows from the statement.
  DELETE FROM public.women_payout_snapshots
  WHERE payment_status = 'failed' AND skipped_reason = 'KYC not approved';

  RETURN jsonb_build_object(
    'success', true,
    'snapshot_type', v_snapshot_type,
    'women_processed', v_count,
    'women_zero_balance', v_zero_count,
    'women_notified_kyc_pending', v_skipped,
    'total_amount', v_total,
    'ist_datetime', v_ist_now
  );
END;
$function$;