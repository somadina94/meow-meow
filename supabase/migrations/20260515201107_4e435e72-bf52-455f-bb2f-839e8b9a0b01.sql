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
  v_count_paid int := 0;
  v_count_kyc_pending int := 0;
  v_count_kyc_rejected int := 0;
  v_count_zero int := 0;
  v_total numeric := 0;
  v_wallet_id uuid;
  v_idem text;
  v_bal numeric;
  v_kyc_state text;
  v_status text;
  v_inserted int;
BEGIN
  FOR v_rec IN
    SELECT
      p.user_id, p.app_sno, p.full_name AS profile_name,
      COALESCE(w.balance, 0) AS wallet_balance,
      k.id AS kyc_id, k.verification_status AS kyc_status,
      k.account_holder_name, k.full_name_as_per_bank,
      k.bank_name, k.account_number, k.ifsc_code,
      k.mobile_number, k.email_address, k.current_address,
      k.upi_vpa, k.beneficiary_purpose
    FROM public.profiles p
    LEFT JOIN public.wallets w ON w.user_id = p.user_id
    LEFT JOIN public.women_kyc k ON k.user_id = p.user_id
    WHERE p.gender = 'female'
  LOOP
    v_bal := COALESCE(v_rec.wallet_balance, 0);
    v_wallet_id := NULL;

    IF v_rec.kyc_id IS NULL THEN v_kyc_state := 'kyc_pending';
    ELSIF v_rec.kyc_status = 'approved' THEN v_kyc_state := 'approved';
    ELSIF v_rec.kyc_status = 'rejected' THEN v_kyc_state := 'kyc_rejected';
    ELSE v_kyc_state := 'kyc_pending'; END IF;

    IF v_kyc_state = 'approved' THEN
      v_status := CASE WHEN v_bal > 0 THEN 'pending' ELSE 'no_balance' END;
    ELSIF v_bal = 0 THEN
      v_status := 'no_balance';
    ELSE
      v_status := v_kyc_state;
    END IF;

    IF v_bal > 0 THEN
      SELECT id INTO v_wallet_id FROM public.wallets WHERE user_id = v_rec.user_id FOR UPDATE;
      IF v_wallet_id IS NULL THEN v_bal := 0; v_status := 'no_balance'; END IF;
    END IF;

    INSERT INTO public.women_payout_snapshots (
      snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
      user_id, app_sno, beneficiary_purpose, full_name, account_holder_name,
      mobile_number, email_address, address, bank_name, bank_account_number,
      ifsc_code, upi_vpa, gross_earned, withdrawal_fee_amount, net_payable,
      already_paid, incremental_payable, wallet_balance_at_snapshot, payment_status,
      skipped_reason
    ) VALUES (
      v_snapshot_type, v_ist_now, v_ist_date, v_ist_month, v_ist_year,
      v_rec.user_id, v_rec.app_sno,
      COALESCE(v_rec.beneficiary_purpose, 'others'),
      COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name, v_rec.profile_name, 'Unknown'),
      v_rec.account_holder_name, v_rec.mobile_number, v_rec.email_address,
      v_rec.current_address, v_rec.bank_name, v_rec.account_number,
      v_rec.ifsc_code, v_rec.upi_vpa,
      v_bal, 0, v_bal, 0, v_bal, v_bal, v_status,
      CASE
        WHEN v_kyc_state = 'kyc_pending'  THEN 'KYC not submitted/approved — held by admin'
        WHEN v_kyc_state = 'kyc_rejected' THEN 'KYC rejected — held by admin'
        ELSE NULL
      END
    )
    ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    IF v_inserted > 0 AND v_bal > 0 AND v_wallet_id IS NOT NULL THEN
      v_idem := 'payout|' || v_rec.user_id::text || '|' || v_snapshot_type;

      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, session_type,
        amount, balance_after, description, reference_id, idempotency_key, status
      ) VALUES (
        v_wallet_id, v_rec.user_id, 'debit', 'payout', 'payout',
        v_bal, 0,
        'Payout snapshot — admin generated on ' || TO_CHAR(v_ist_now, 'DD Mon YYYY HH24:MI IST') ||
          CASE WHEN v_kyc_state <> 'approved' THEN ' (held: ' || v_kyc_state || ')' ELSE '' END,
        'PAYOUT-' || v_snapshot_type, v_idem, 'completed'
      )
      ON CONFLICT (idempotency_key) DO NOTHING;

      UPDATE public.wallets SET balance = 0, updated_at = NOW() WHERE id = v_wallet_id;

      IF v_kyc_state = 'approved' THEN v_count_paid := v_count_paid + 1;
      ELSIF v_kyc_state = 'kyc_pending' THEN v_count_kyc_pending := v_count_kyc_pending + 1;
      ELSIF v_kyc_state = 'kyc_rejected' THEN v_count_kyc_rejected := v_count_kyc_rejected + 1;
      END IF;
      v_total := v_total + v_bal;
    ELSE
      v_count_zero := v_count_zero + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'snapshot_type', v_snapshot_type,
    'women_paid', v_count_paid,
    'women_kyc_pending', v_count_kyc_pending,
    'women_kyc_rejected', v_count_kyc_rejected,
    'women_zero_balance', v_count_zero,
    'total_amount', v_total,
    'ist_datetime', v_ist_now
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.capture_payout_snapshot(p_snapshot_type text)
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
  v_rec record;
  v_count_paid int := 0;
  v_count_kyc_pending int := 0;
  v_count_kyc_rejected int := 0;
  v_count_zero int := 0;
  v_total numeric := 0;
  v_wallet_id uuid;
  v_idem text;
  v_bal numeric;
  v_kyc_state text;
  v_status text;
BEGIN
  FOR v_rec IN
    SELECT
      p.user_id, p.app_sno, p.full_name AS profile_name,
      COALESCE(w.balance, 0) AS wallet_balance,
      k.id AS kyc_id, k.verification_status AS kyc_status,
      k.account_holder_name, k.full_name_as_per_bank,
      k.bank_name, k.account_number, k.ifsc_code,
      k.mobile_number, k.email_address, k.current_address,
      k.upi_vpa, k.beneficiary_purpose
    FROM public.profiles p
    LEFT JOIN public.wallets w ON w.user_id = p.user_id
    LEFT JOIN public.women_kyc k ON k.user_id = p.user_id
    WHERE p.gender = 'female'
  LOOP
    v_bal := COALESCE(v_rec.wallet_balance, 0);
    v_wallet_id := NULL;

    IF v_rec.kyc_id IS NULL THEN v_kyc_state := 'kyc_pending';
    ELSIF v_rec.kyc_status = 'approved' THEN v_kyc_state := 'approved';
    ELSIF v_rec.kyc_status = 'rejected' THEN v_kyc_state := 'kyc_rejected';
    ELSE v_kyc_state := 'kyc_pending'; END IF;

    IF v_kyc_state = 'approved' THEN
      v_status := CASE WHEN v_bal > 0 THEN 'pending' ELSE 'no_balance' END;
    ELSIF v_bal = 0 THEN
      v_status := 'no_balance';
    ELSE
      v_status := v_kyc_state;
    END IF;

    IF v_bal > 0 THEN
      SELECT id INTO v_wallet_id FROM public.wallets WHERE user_id = v_rec.user_id FOR UPDATE;
      IF v_wallet_id IS NULL THEN v_bal := 0; v_status := 'no_balance'; END IF;
    END IF;

    INSERT INTO public.women_payout_snapshots (
      snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
      user_id, app_sno, beneficiary_purpose, full_name, account_holder_name,
      mobile_number, email_address, address, bank_name, bank_account_number,
      ifsc_code, upi_vpa, gross_earned, withdrawal_fee_amount, net_payable,
      already_paid, incremental_payable, wallet_balance_at_snapshot, payment_status,
      skipped_reason
    ) VALUES (
      p_snapshot_type, v_ist_now, v_ist_date, v_ist_month, v_ist_year,
      v_rec.user_id, v_rec.app_sno,
      COALESCE(v_rec.beneficiary_purpose, 'others'),
      COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name, v_rec.profile_name, 'Unknown'),
      v_rec.account_holder_name, v_rec.mobile_number, v_rec.email_address,
      v_rec.current_address, v_rec.bank_name, v_rec.account_number,
      v_rec.ifsc_code, v_rec.upi_vpa,
      v_bal, 0, v_bal, 0, v_bal, v_bal, v_status,
      CASE
        WHEN v_kyc_state = 'kyc_pending'  THEN 'KYC not submitted/approved — held by admin'
        WHEN v_kyc_state = 'kyc_rejected' THEN 'KYC rejected — held by admin'
        ELSE NULL
      END
    )
    ON CONFLICT (user_id, snapshot_type, ist_month) DO UPDATE SET
      wallet_balance_at_snapshot = EXCLUDED.wallet_balance_at_snapshot,
      gross_earned               = EXCLUDED.gross_earned,
      net_payable                = EXCLUDED.net_payable,
      incremental_payable        = EXCLUDED.incremental_payable,
      payment_status             = EXCLUDED.payment_status,
      skipped_reason             = EXCLUDED.skipped_reason;

    IF v_bal > 0 AND v_wallet_id IS NOT NULL THEN
      v_idem := 'payout|' || v_rec.user_id::text || '|' || p_snapshot_type || '|' || v_ist_month;

      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, session_type,
        amount, balance_after, description, reference_id, idempotency_key, status
      ) VALUES (
        v_wallet_id, v_rec.user_id, 'debit', 'payout', 'payout',
        v_bal, 0,
        'Payout snapshot — ' || p_snapshot_type || ' on ' || TO_CHAR(v_ist_now, 'DD Mon YYYY HH24:MI IST') ||
          CASE WHEN v_kyc_state <> 'approved' THEN ' (held: ' || v_kyc_state || ')' ELSE '' END,
        'PAYOUT-' || p_snapshot_type || '-' || v_ist_month, v_idem, 'completed'
      )
      ON CONFLICT (idempotency_key) DO NOTHING;

      UPDATE public.wallets SET balance = 0, updated_at = NOW() WHERE id = v_wallet_id;

      IF v_kyc_state = 'approved' THEN v_count_paid := v_count_paid + 1;
      ELSIF v_kyc_state = 'kyc_pending' THEN v_count_kyc_pending := v_count_kyc_pending + 1;
      ELSIF v_kyc_state = 'kyc_rejected' THEN v_count_kyc_rejected := v_count_kyc_rejected + 1;
      END IF;
      v_total := v_total + v_bal;
    ELSE
      v_count_zero := v_count_zero + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'snapshot_type', p_snapshot_type,
    'women_paid', v_count_paid,
    'women_kyc_pending', v_count_kyc_pending,
    'women_kyc_rejected', v_count_kyc_rejected,
    'women_zero_balance', v_count_zero,
    'total_amount', v_total,
    'ist_datetime', v_ist_now
  );
END;
$function$;