-- Ensure admin payout/monthly statement generation uses auth user ids and canonical ledger tables.

CREATE OR REPLACE FUNCTION public.generate_payout_snapshot_unified()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now timestamptz := now() AT TIME ZONE 'Asia/Kolkata';
  v_year int := EXTRACT(year FROM v_now)::int;
  v_month int := EXTRACT(month FROM v_now)::int;
  v_user RECORD;
  v_total_earned numeric(12,2); v_paid_out numeric(12,2); v_available numeric(12,2);
  v_chat numeric(12,2); v_audio numeric(12,2); v_video numeric(12,2);
  v_group numeric(12,2); v_gift numeric(12,2); v_tip numeric(12,2);
  v_count int := 0;
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  FOR v_user IN SELECT p.user_id FROM public.profiles p WHERE p.gender='female' AND p.user_id IS NOT NULL LOOP
    SELECT
      COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='chat' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='audio_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='video_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='private_group_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='gift' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='tip' THEN amount ELSE 0 END),0)
    INTO v_total_earned, v_chat, v_audio, v_video, v_group, v_gift, v_tip
    FROM (
      SELECT type, amount, session_type, status FROM public.wallet_transactions WHERE user_id=v_user.user_id
      UNION ALL
      SELECT type, amount, session_type, status FROM public.wallet_transactions_archive WHERE user_id=v_user.user_id
    ) t
    WHERE status='completed';

    SELECT COALESCE(SUM(payout_amount),0) INTO v_paid_out
    FROM public.monthly_statements
    WHERE public.resolve_wallet_user_id(user_id)=v_user.user_id
      AND gender='female'
      AND payout_status IN ('approved','paid');

    v_available := GREATEST(v_total_earned - v_paid_out, 0);
    IF v_available <= 0 THEN CONTINUE; END IF;

    INSERT INTO public.monthly_statements (
      user_id, gender, year, month, opening_balance, total_credit, total_debit, closing_balance,
      chat_amount, audio_call_amount, video_call_amount, group_call_amount,
      gift_amount, tip_amount, payout_amount, payout_status, generated_at
    ) VALUES (
      v_user.user_id, 'female', v_year, v_month, 0, v_available, 0, v_available,
      v_chat, v_audio, v_video, v_group, v_gift, v_tip, v_available, 'pending', now()
    ) ON CONFLICT (user_id, year, month) DO UPDATE SET
      total_credit=EXCLUDED.total_credit,
      closing_balance=EXCLUDED.closing_balance,
      chat_amount=EXCLUDED.chat_amount,
      audio_call_amount=EXCLUDED.audio_call_amount,
      video_call_amount=EXCLUDED.video_call_amount,
      group_call_amount=EXCLUDED.group_call_amount,
      gift_amount=EXCLUDED.gift_amount,
      tip_amount=EXCLUDED.tip_amount,
      payout_amount=EXCLUDED.payout_amount,
      payout_status=CASE WHEN public.monthly_statements.payout_status IN ('approved','paid')
                         THEN public.monthly_statements.payout_status ELSE 'pending' END,
      generated_at=now();
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'count', v_count, 'year', v_year, 'month', v_month);
END;
$$;

CREATE OR REPLACE FUNCTION public.process_monthly_payout()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ist_now timestamptz := NOW() AT TIME ZONE 'Asia/Kolkata';
  v_ist_date date := (NOW() AT TIME ZONE 'Asia/Kolkata')::date;
  v_prev_date timestamptz := (NOW() AT TIME ZONE 'Asia/Kolkata') - interval '1 day';
  v_prev_month_t text := TO_CHAR(v_prev_date, 'YYYY-MM');
  v_prev_year int := EXTRACT(YEAR FROM v_prev_date)::int;
  v_prev_month_n int := EXTRACT(MONTH FROM v_prev_date)::int;
  v_period_start timestamptz; v_period_end timestamptz;
  v_rec record; v_user record;
  v_balance numeric(12,2); v_credits numeric(12,2); v_debits numeric(12,2);
  v_opening numeric(12,2); v_closing numeric(12,2);
  v_chat numeric(12,2); v_audio numeric(12,2); v_video numeric(12,2);
  v_group numeric(12,2); v_gift numeric(12,2); v_tip numeric(12,2); v_recharge numeric(12,2);
  v_wallet RECORD; v_idem text;
  v_women_processed int := 0; v_women_skipped int := 0; v_men_processed int := 0;
BEGIN
  v_period_start := make_timestamptz(v_prev_year, v_prev_month_n, 1, 0, 0, 0, 'Asia/Kolkata');
  v_period_end := v_period_start + interval '1 month';

  FOR v_rec IN
    SELECT p.user_id, p.app_sno, k.id AS kyc_id, k.verification_status AS kyc_status,
      k.account_holder_name, k.full_name_as_per_bank, k.bank_name, k.account_number, k.ifsc_code,
      k.mobile_number, k.email_address, k.current_address, k.upi_id, k.upi_vpa, k.beneficiary_purpose
    FROM public.profiles p
    LEFT JOIN public.women_kyc k ON k.user_id = p.user_id
    WHERE p.gender='female' AND p.user_id IS NOT NULL
  LOOP
    v_balance := public.women_ledger_balance(v_rec.user_id);
    IF v_balance <= 0 THEN CONTINUE; END IF;

    IF v_rec.kyc_id IS NULL OR v_rec.kyc_status <> 'approved' THEN
      INSERT INTO public.women_payout_snapshots (
        snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
        user_id, full_name, gross_earned, withdrawal_fee_amount, net_payable,
        wallet_balance_at_snapshot, payment_status, app_sno, skipped_reason
      ) VALUES (
        'monthly', v_ist_now, v_ist_date, v_prev_month_t, v_prev_year,
        v_rec.user_id, COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name, 'Unknown'),
        v_balance, 0, 0, v_balance, 'failed', v_rec.app_sno, 'KYC not approved'
      ) ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;
      v_women_skipped := v_women_skipped + 1;
      CONTINUE;
    END IF;

    INSERT INTO public.women_payout_snapshots (
      snapshot_type, snapshot_ist_datetime, snapshot_ist_date, ist_month, ist_year,
      user_id, app_sno, beneficiary_purpose,
      full_name, account_holder_name, mobile_number, email_address, address,
      bank_name, bank_account_number, ifsc_code, upi_vpa,
      gross_earned, withdrawal_fee_amount, net_payable, already_paid, incremental_payable,
      wallet_balance_at_snapshot, payment_status
    ) VALUES (
      'monthly', v_ist_now, v_ist_date, v_prev_month_t, v_prev_year,
      v_rec.user_id, v_rec.app_sno, COALESCE(v_rec.beneficiary_purpose, 'others'),
      COALESCE(v_rec.full_name_as_per_bank, v_rec.account_holder_name),
      v_rec.account_holder_name, v_rec.mobile_number, v_rec.email_address,
      v_rec.current_address, v_rec.bank_name, v_rec.account_number,
      v_rec.ifsc_code, COALESCE(v_rec.upi_vpa, v_rec.upi_id),
      v_balance, 0, v_balance, 0, v_balance,
      v_balance, 'pending'
    ) ON CONFLICT (user_id, snapshot_type, ist_month) DO NOTHING;

    IF FOUND THEN
      SELECT * INTO v_wallet FROM public.wallets WHERE user_id=v_rec.user_id FOR UPDATE;
      IF NOT FOUND THEN
        INSERT INTO public.wallets(user_id, gender, balance, currency)
        VALUES (v_rec.user_id, 'female', 0, 'INR') RETURNING * INTO v_wallet;
      END IF;

      v_idem := 'payout|' || v_rec.user_id::text || '|' || v_prev_month_t;

      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, session_type,
        amount, balance_after, description, reference_id, idempotency_key, status
      ) VALUES (
        v_wallet.id, v_rec.user_id, 'debit', 'payout', 'payout',
        v_balance, 0, 'Monthly payout sweep ' || v_prev_month_t,
        'PAYOUT-' || v_prev_month_t, v_idem, 'completed'
      ) ON CONFLICT (idempotency_key) DO NOTHING;

      UPDATE public.wallets SET balance=0, updated_at=now() WHERE id=v_wallet.id;
      v_women_processed := v_women_processed + 1;
    END IF;

    SELECT
      COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit'  THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='chat' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='audio_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='video_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='private_group_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='gift' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND session_type='tip' THEN amount ELSE 0 END),0)
    INTO v_credits, v_debits, v_chat, v_audio, v_video, v_group, v_gift, v_tip
    FROM public.wallet_transactions
    WHERE user_id=v_rec.user_id AND status='completed'
      AND created_at>=v_period_start AND created_at<v_period_end;

    v_closing := GREATEST(v_credits - v_debits, 0);

    INSERT INTO public.monthly_statements (
      user_id, gender, year, month, opening_balance, total_credit, total_debit,
      closing_balance, chat_amount, audio_call_amount, video_call_amount,
      group_call_amount, gift_amount, tip_amount, payout_amount, payout_status, generated_at
    ) VALUES (
      v_rec.user_id, 'female', v_prev_year, v_prev_month_n,
      0, v_credits, v_debits, v_closing,
      v_chat, v_audio, v_video, v_group, v_gift, v_tip,
      v_balance, CASE WHEN v_balance>0 THEN 'pending' ELSE 'na' END, NOW()
    ) ON CONFLICT (user_id, year, month) DO UPDATE SET
      total_credit=EXCLUDED.total_credit, total_debit=EXCLUDED.total_debit,
      closing_balance=EXCLUDED.closing_balance,
      chat_amount=EXCLUDED.chat_amount, audio_call_amount=EXCLUDED.audio_call_amount,
      video_call_amount=EXCLUDED.video_call_amount, group_call_amount=EXCLUDED.group_call_amount,
      gift_amount=EXCLUDED.gift_amount, tip_amount=EXCLUDED.tip_amount,
      payout_amount=EXCLUDED.payout_amount,
      payout_status=CASE WHEN public.monthly_statements.payout_status IN ('approved','paid')
                         THEN public.monthly_statements.payout_status ELSE EXCLUDED.payout_status END,
      generated_at=NOW();
  END LOOP;

  FOR v_user IN SELECT p.user_id FROM public.profiles p WHERE p.gender='male' AND p.user_id IS NOT NULL LOOP
    SELECT COALESCE(closing_balance,0) INTO v_opening FROM public.monthly_statements
    WHERE public.resolve_wallet_user_id(user_id)=v_user.user_id AND ((year*12+month)=(v_prev_year*12+v_prev_month_n)-1);
    v_opening := COALESCE(v_opening,0);

    SELECT
      COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit'  THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='chat' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='audio_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='video_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='private_group_call' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='gift' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='debit' AND session_type='tip' THEN amount ELSE 0 END),0),
      COALESCE(SUM(CASE WHEN type='credit' AND transaction_type='recharge' THEN amount ELSE 0 END),0)
    INTO v_credits, v_debits, v_chat, v_audio, v_video, v_group, v_gift, v_tip, v_recharge
    FROM public.wallet_transactions
    WHERE user_id=v_user.user_id AND status='completed'
      AND created_at>=v_period_start AND created_at<v_period_end;

    v_closing := GREATEST(v_opening + v_credits - v_debits, 0);

    INSERT INTO public.monthly_statements (
      user_id, gender, year, month, opening_balance, total_credit, total_debit,
      closing_balance, chat_amount, audio_call_amount, video_call_amount,
      group_call_amount, gift_amount, tip_amount, recharge_amount,
      payout_amount, payout_status, generated_at
    ) VALUES (
      v_user.user_id, 'male', v_prev_year, v_prev_month_n,
      v_opening, v_credits, v_debits, v_closing,
      v_chat, v_audio, v_video, v_group, v_gift, v_tip, v_recharge,
      0, 'na', NOW()
    ) ON CONFLICT (user_id, year, month) DO UPDATE SET
      opening_balance=EXCLUDED.opening_balance, total_credit=EXCLUDED.total_credit,
      total_debit=EXCLUDED.total_debit, closing_balance=EXCLUDED.closing_balance,
      chat_amount=EXCLUDED.chat_amount, audio_call_amount=EXCLUDED.audio_call_amount,
      video_call_amount=EXCLUDED.video_call_amount, group_call_amount=EXCLUDED.group_call_amount,
      gift_amount=EXCLUDED.gift_amount, tip_amount=EXCLUDED.tip_amount,
      recharge_amount=EXCLUDED.recharge_amount, generated_at=NOW();

    v_men_processed := v_men_processed + 1;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'ist_datetime', v_ist_now, 'ist_date', v_ist_date,
    'period', v_prev_month_t, 'women_processed', v_women_processed,
    'women_skipped_no_kyc', v_women_skipped, 'men_processed', v_men_processed);
END;
$$;

REVOKE ALL ON FUNCTION public.generate_payout_snapshot_unified() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.process_monthly_payout() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_payout_snapshot_unified() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.process_monthly_payout() TO authenticated, service_role;