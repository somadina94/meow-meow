
-- 1) Fix existing women_earnings: set rate_per_minute based on earning_type
UPDATE public.women_earnings SET rate_per_minute = 
  CASE earning_type
    WHEN 'chat' THEN 2.00
    WHEN 'video_call' THEN 4.00
    WHEN 'audio_call' THEN 3.00
    WHEN 'group_call' THEN 0.50
    ELSE NULL
  END
WHERE rate_per_minute IS NULL;

-- 2) Fix minutes_billed: calculate from amount/rate
UPDATE public.women_earnings SET minutes_billed = 
  CASE WHEN rate_per_minute IS NOT NULL AND rate_per_minute > 0 THEN amount / rate_per_minute
       ELSE minutes_billed END
WHERE rate_per_minute IS NOT NULL AND rate_per_minute > 0;

-- 3) Update ledger_bill_session to set rate_per_minute and minutes_billed in women_earnings
CREATE OR REPLACE FUNCTION public.ledger_bill_session(
  p_session_id uuid, p_session_type text, p_man_id uuid, p_woman_id uuid,
  p_minute_number integer, p_man_charge numeric, p_woman_earn numeric
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_idem_key text;
  v_idem_key_woman text;
  v_man_wallet_id uuid;
  v_man_balance numeric;
  v_woman_wallet uuid;
  v_woman_indian boolean := false;
BEGIN
  v_idem_key := p_session_type || ':' || p_session_id::text || ':min:' || p_minute_number::text;
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'idempotency_key', v_idem_key);
  END IF;

  SELECT COALESCE(fp.is_indian, pr.is_indian, false) INTO v_woman_indian
  FROM public.profiles pr LEFT JOIN public.female_profiles fp ON fp.user_id = pr.user_id
  WHERE pr.user_id = p_woman_id;

  IF v_woman_indian AND ROUND(p_woman_earn, 2) <> ROUND(p_man_charge / 2.0, 2) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Half-rule violation');
  END IF;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
  IF v_man_balance IS NULL OR v_man_balance < p_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'balance', COALESCE(v_man_balance, 0), 'required', p_man_charge);
  END IF;

  UPDATE public.wallets SET balance = balance - p_man_charge, updated_at = now() WHERE id = v_man_wallet_id;

  INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
  VALUES (p_man_id, 'debit', p_session_type || '_charge', p_man_charge,
    initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_man_charge || '/min',
    p_session_id, (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id), v_idem_key, 'completed',
    60, p_man_charge);

  IF v_woman_indian AND p_woman_earn > 0 THEN
    SELECT id INTO v_woman_wallet FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF v_woman_wallet IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + p_woman_earn, updated_at = now() WHERE id = v_woman_wallet;
    END IF;

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, rate_per_minute, minutes_billed, created_at)
    VALUES (p_woman_id, p_woman_earn, p_session_type,
      initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min (½ of ₹' || p_man_charge || ')',
      p_woman_earn, 1, now());

    v_idem_key_woman := p_session_type || ':' || p_session_id::text || ':earn:' || p_minute_number::text;
    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
    VALUES (p_woman_id, 'credit', p_session_type, p_woman_earn,
      initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min (½ of ₹' || p_man_charge || ')',
      p_session_id, (SELECT balance FROM public.wallets WHERE id = v_woman_wallet), v_idem_key_woman, 'completed',
      60, p_woman_earn);
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', p_man_charge,
    'earned', CASE WHEN v_woman_indian THEN p_woman_earn ELSE 0 END,
    'minute_number', p_minute_number, 'idempotency_key', v_idem_key);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- 4) Update ledger_bill_group_call to set rate_per_minute and minutes_billed in women_earnings
CREATE OR REPLACE FUNCTION public.ledger_bill_group_call(
  p_session_id uuid, p_woman_id uuid, p_man_ids uuid[], p_minute_number integer,
  p_charge_per_man numeric, p_earn_per_man numeric
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_man_id uuid;
  v_ref_man text;
  v_ref_woman text;
  v_total_woman_earn numeric := 0;
  v_man_balance numeric;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE user_id = p_woman_id) THEN
    INSERT INTO public.wallets (user_id, balance, currency, gender) VALUES (p_woman_id, 0, 'INR', 'female') ON CONFLICT (user_id) DO NOTHING;
  END IF;

  FOREACH v_man_id IN ARRAY p_man_ids LOOP
    v_ref_man   := p_session_id::text || '_' || v_man_id::text || '_grp' || p_minute_number::text;
    v_ref_woman := p_session_id::text || '_' || p_woman_id::text || '_grpearn_' || v_man_id::text || '_' || p_minute_number::text;

    CONTINUE WHEN EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_ref_man);

    SELECT balance INTO v_man_balance FROM public.wallets WHERE user_id = v_man_id FOR UPDATE;
    CONTINUE WHEN v_man_balance IS NULL OR v_man_balance < p_charge_per_man;

    UPDATE public.wallets SET balance = balance - p_charge_per_man, updated_at = now() WHERE user_id = v_man_id;

    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
    VALUES (v_man_id, 'debit', 'group_call_charge', p_charge_per_man,
      'Group Call: min ' || p_minute_number || ' @ ₹' || p_charge_per_man || '/min',
      p_session_id, (SELECT balance FROM public.wallets WHERE user_id = v_man_id), v_ref_man, 'completed',
      60, p_charge_per_man);

    PERFORM public.safe_ledger_insert(v_man_id, p_session_id, 'group_call_charge', p_charge_per_man, 0,
      p_charge_per_man, 60, p_woman_id, v_ref_man, 'Group call charge minute ' || p_minute_number, now());

    v_total_woman_earn := v_total_woman_earn + p_earn_per_man;

    PERFORM public.safe_ledger_insert(p_woman_id, p_session_id, 'earning', 0, p_earn_per_man,
      p_earn_per_man, 60, v_man_id, v_ref_woman, 'Group call earning from man minute ' || p_minute_number, now());

    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
    VALUES (p_woman_id, 'credit', 'group_call_earning', p_earn_per_man,
      'Group Call Earning: min ' || p_minute_number || ' @ ₹' || p_earn_per_man || '/man',
      p_session_id, NULL, v_ref_woman, 'completed',
      60, p_earn_per_man);

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, group_id, man_user_id, rate_per_minute, minutes_billed, created_at)
    VALUES (p_woman_id, p_earn_per_man, 'group_call', 'Group call earning min ' || p_minute_number || ' @ ₹' || p_earn_per_man || '/man',
      p_session_id, v_man_id, p_earn_per_man, 1, now());
  END LOOP;

  IF v_total_woman_earn > 0 THEN
    UPDATE public.wallets SET balance = balance + v_total_woman_earn, updated_at = now() WHERE user_id = p_woman_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'minute', p_minute_number, 'woman_earned', v_total_woman_earn);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- 5) Update get_my_statement_detail to infer duration from amount/rate when metadata is unreliable
CREATE OR REPLACE FUNCTION public.get_my_statement_detail(p_year integer, p_month integer)
RETURNS TABLE(
  txn_date timestamptz, transaction_id text, session_id text, txn_type text,
  description text, duration_seconds integer, rate_per_minute numeric,
  debit numeric, credit numeric, running_balance numeric,
  start_time timestamptz, end_time timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
#variable_conflict use_column
DECLARE
  v_user_id        uuid := auth.uid();
  v_gender         text;
  v_period_start   timestamptz;
  v_period_end     timestamptz;
  v_opening        numeric(12,2) := 0;
  v_six_months_ago timestamptz;
  v_wallet_balance numeric(12,2);
  v_total_credit   numeric(12,2);
  v_total_debit    numeric(12,2);
  v_is_current_month boolean;
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  SELECT p.gender INTO v_gender FROM public.profiles p WHERE p.user_id = v_user_id;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'Asia/Kolkata');
  v_period_end   := v_period_start + interval '1 month';
  v_is_current_month := (date_trunc('month', now() AT TIME ZONE 'Asia/Kolkata') = date_trunc('month', v_period_start AT TIME ZONE 'Asia/Kolkata'));

  v_six_months_ago := date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata') - interval '5 months');
  IF (v_period_start AT TIME ZONE 'Asia/Kolkata') < v_six_months_ago THEN RETURN; END IF;

  CREATE TEMP TABLE IF NOT EXISTS _stmt_rows (
    row_num serial, txn_date timestamptz, transaction_id text, session_id text,
    txn_type text, description text, duration_seconds integer, rate_per_minute numeric,
    debit numeric NOT NULL DEFAULT 0, credit numeric NOT NULL DEFAULT 0,
    start_time timestamptz, end_time timestamptz
  ) ON COMMIT DROP;
  TRUNCATE _stmt_rows;

  -- 1) Ledger transactions
  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit, start_time, end_time)
  SELECT lt.created_at, lt.id::text, lt.session_id::text,
    lt.transaction_type, lt.description,
    CASE 
      WHEN lt.duration_seconds IS NOT NULL AND lt.duration_seconds > 0 THEN lt.duration_seconds
      WHEN lt.rate_per_minute IS NOT NULL AND lt.rate_per_minute > 0 AND (lt.debit + lt.credit) > 0
        THEN ((lt.debit + lt.credit) / lt.rate_per_minute * 60)::integer
      ELSE NULL
    END,
    lt.rate_per_minute,
    lt.debit, lt.credit,
    CASE WHEN lt.duration_seconds IS NOT NULL AND lt.duration_seconds > 0
      THEN lt.created_at - (lt.duration_seconds * interval '1 second')
      WHEN lt.rate_per_minute IS NOT NULL AND lt.rate_per_minute > 0 AND (lt.debit + lt.credit) > 0
        THEN lt.created_at - (((lt.debit + lt.credit) / lt.rate_per_minute) * interval '1 minute')
      ELSE NULL END,
    CASE WHEN lt.duration_seconds IS NOT NULL AND lt.duration_seconds > 0 THEN lt.created_at
      WHEN lt.rate_per_minute IS NOT NULL AND lt.rate_per_minute > 0 THEN lt.created_at
      ELSE NULL END
  FROM public.ledger_transactions lt
  WHERE lt.user_id = v_user_id AND lt.created_at >= v_period_start AND lt.created_at < v_period_end
  ORDER BY lt.created_at, lt.id;

  -- 2) Wallet transactions (deduplicated)
  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit, start_time, end_time)
  SELECT wt.created_at, wt.id::text, wt.session_id::text,
    COALESCE(wt.transaction_type, wt.type), wt.description,
    CASE 
      WHEN wt.duration_seconds IS NOT NULL AND wt.duration_seconds > 0 THEN wt.duration_seconds
      WHEN wt.rate_per_minute IS NOT NULL AND wt.rate_per_minute > 0 AND wt.amount > 0
        THEN (wt.amount / wt.rate_per_minute * 60)::integer
      ELSE NULL
    END,
    wt.rate_per_minute,
    CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END,
    CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END,
    CASE WHEN wt.duration_seconds IS NOT NULL AND wt.duration_seconds > 0
      THEN wt.created_at - (wt.duration_seconds * interval '1 second')
      WHEN wt.rate_per_minute IS NOT NULL AND wt.rate_per_minute > 0 AND wt.amount > 0
        THEN wt.created_at - ((wt.amount / wt.rate_per_minute) * interval '1 minute')
      ELSE NULL END,
    CASE WHEN wt.duration_seconds IS NOT NULL AND wt.duration_seconds > 0 THEN wt.created_at
      WHEN wt.rate_per_minute IS NOT NULL AND wt.rate_per_minute > 0 THEN wt.created_at
      ELSE NULL END
  FROM public.wallet_transactions wt
  WHERE wt.user_id = v_user_id AND wt.created_at >= v_period_start AND wt.created_at < v_period_end AND wt.status = 'completed'
    AND NOT EXISTS (
      SELECT 1 FROM public.ledger_transactions lt
      WHERE lt.user_id = v_user_id AND lt.reference_id = wt.idempotency_key AND wt.idempotency_key IS NOT NULL
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.ledger_transactions lt
      WHERE lt.user_id = v_user_id AND wt.session_id IS NOT NULL AND lt.session_id IS NOT NULL
        AND lt.session_id::text = wt.session_id::text
        AND lt.debit = (CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END)
        AND lt.credit = (CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END)
        AND ABS(EXTRACT(EPOCH FROM (lt.created_at - wt.created_at))) < 120
    )
  ORDER BY wt.created_at, wt.id;

  -- 3) Platform ledger (deduplicated)
  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit, start_time, end_time)
  SELECT pl.created_at_ist, pl.id::text, pl.session_id::text,
    pl.entry_type, pl.description,
    CASE 
      WHEN pl.duration_minutes IS NOT NULL AND pl.duration_minutes > 0 THEN (pl.duration_minutes * 60)::integer
      WHEN pl.rate_per_unit IS NOT NULL AND pl.rate_per_unit > 0 AND (pl.debit + pl.credit) > 0
        THEN ((pl.debit + pl.credit) / pl.rate_per_unit * 60)::integer
      ELSE NULL
    END,
    pl.rate_per_unit,
    pl.debit, pl.credit,
    CASE WHEN pl.duration_minutes IS NOT NULL AND pl.duration_minutes > 0
      THEN pl.created_at_ist - (pl.duration_minutes * interval '1 minute')
      WHEN pl.rate_per_unit IS NOT NULL AND pl.rate_per_unit > 0 AND (pl.debit + pl.credit) > 0
        THEN pl.created_at_ist - (((pl.debit + pl.credit) / pl.rate_per_unit) * interval '1 minute')
      ELSE NULL END,
    CASE WHEN pl.duration_minutes IS NOT NULL AND pl.duration_minutes > 0 THEN pl.created_at_ist
      WHEN pl.rate_per_unit IS NOT NULL AND pl.rate_per_unit > 0 THEN pl.created_at_ist
      ELSE NULL END
  FROM public.platform_ledger pl
  WHERE pl.user_id = v_user_id AND pl.created_at_ist >= v_period_start AND pl.created_at_ist < v_period_end
    AND NOT EXISTS (
      SELECT 1 FROM public.wallet_transactions wt
      WHERE wt.user_id = v_user_id AND wt.idempotency_key = pl.idempotency_key AND pl.idempotency_key IS NOT NULL
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.ledger_transactions lt
      WHERE lt.user_id = v_user_id AND lt.reference_id = pl.idempotency_key AND pl.idempotency_key IS NOT NULL
    )
  ORDER BY pl.created_at_ist, pl.id;

  -- 4) Women earnings
  IF v_gender = 'female' THEN
    INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit, start_time, end_time)
    SELECT we.created_at, we.id::text,
      COALESCE(we.chat_session_id, we.video_session_id, we.group_id, we.private_call_id)::text,
      we.earning_type, we.description,
      CASE 
        WHEN we.minutes_billed IS NOT NULL AND we.minutes_billed > 0 THEN (we.minutes_billed * 60)::integer
        WHEN we.rate_per_minute IS NOT NULL AND we.rate_per_minute > 0 AND we.amount > 0
          THEN (we.amount / we.rate_per_minute * 60)::integer
        ELSE NULL
      END,
      we.rate_per_minute,
      0, we.amount,
      CASE WHEN we.minutes_billed IS NOT NULL AND we.minutes_billed > 0
        THEN we.created_at - (we.minutes_billed * interval '1 minute')
        WHEN we.rate_per_minute IS NOT NULL AND we.rate_per_minute > 0 AND we.amount > 0
          THEN we.created_at - ((we.amount / we.rate_per_minute) * interval '1 minute')
        ELSE NULL END,
      CASE WHEN we.minutes_billed IS NOT NULL AND we.minutes_billed > 0 THEN we.created_at
        WHEN we.rate_per_minute IS NOT NULL AND we.rate_per_minute > 0 THEN we.created_at
        ELSE NULL END
    FROM public.women_earnings we
    WHERE we.user_id = v_user_id AND we.created_at >= v_period_start AND we.created_at < v_period_end
      AND NOT EXISTS (
        SELECT 1 FROM public.wallet_transactions wt
        WHERE wt.user_id = v_user_id AND wt.idempotency_key = we.idempotency_key AND we.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.platform_ledger pl
        WHERE pl.user_id = v_user_id AND pl.idempotency_key = we.idempotency_key AND we.idempotency_key IS NOT NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.ledger_transactions lt
        WHERE lt.user_id = v_user_id AND lt.transaction_type = 'earning' AND lt.credit = we.amount
          AND COALESCE(we.chat_session_id, we.video_session_id, we.group_id, we.private_call_id) IS NOT NULL
          AND lt.session_id IS NOT NULL
          AND lt.session_id::text = COALESCE(we.chat_session_id, we.video_session_id, we.group_id, we.private_call_id)::text
          AND ABS(EXTRACT(EPOCH FROM (lt.created_at - we.created_at))) < 120
      )
    ORDER BY we.created_at, we.id;
  END IF;

  -- Calculate opening balance
  IF v_is_current_month THEN
    SELECT COALESCE(SUM(sr.credit), 0), COALESCE(SUM(sr.debit), 0)
    INTO v_total_credit, v_total_debit FROM _stmt_rows sr;
    
    SELECT COALESCE(w.balance, 0) INTO v_wallet_balance FROM public.wallets w WHERE w.user_id = v_user_id;
    IF v_wallet_balance IS NULL THEN v_wallet_balance := 0; END IF;
    v_opening := v_wallet_balance - v_total_credit + v_total_debit;
  ELSE
    SELECT COALESCE(SUM(cr - dr), 0) INTO v_opening
    FROM (
      SELECT lt2.credit as cr, lt2.debit as dr FROM public.ledger_transactions lt2
      WHERE lt2.user_id = v_user_id AND lt2.created_at < v_period_start
      UNION ALL
      SELECT
        CASE WHEN wt2.type = 'credit' THEN wt2.amount ELSE 0 END,
        CASE WHEN wt2.type = 'debit' THEN wt2.amount ELSE 0 END
      FROM public.wallet_transactions wt2
      WHERE wt2.user_id = v_user_id AND wt2.created_at < v_period_start AND wt2.status = 'completed'
        AND NOT EXISTS (
          SELECT 1 FROM public.ledger_transactions lt3
          WHERE lt3.user_id = v_user_id AND lt3.reference_id = wt2.idempotency_key AND wt2.idempotency_key IS NOT NULL
        )
      UNION ALL
      SELECT pl2.credit, pl2.debit FROM public.platform_ledger pl2
      WHERE pl2.user_id = v_user_id AND pl2.created_at_ist < v_period_start
        AND NOT EXISTS (
          SELECT 1 FROM public.ledger_transactions lt4
          WHERE lt4.user_id = v_user_id AND lt4.reference_id = pl2.idempotency_key AND pl2.idempotency_key IS NOT NULL
        )
      UNION ALL
      SELECT we2.amount, 0 FROM public.women_earnings we2
      WHERE we2.user_id = v_user_id AND we2.created_at < v_period_start
        AND v_gender = 'female'
        AND NOT EXISTS (
          SELECT 1 FROM public.ledger_transactions lt5
          WHERE lt5.user_id = v_user_id AND lt5.transaction_type = 'earning' AND lt5.credit = we2.amount
            AND COALESCE(we2.chat_session_id, we2.video_session_id, we2.group_id, we2.private_call_id) IS NOT NULL
            AND lt5.session_id IS NOT NULL
            AND lt5.session_id::text = COALESCE(we2.chat_session_id, we2.video_session_id, we2.group_id, we2.private_call_id)::text
            AND ABS(EXTRACT(EPOCH FROM (lt5.created_at - we2.created_at))) < 120
        )
    ) combined;
    IF v_gender = 'male' AND v_opening < 0 THEN v_opening := 0; END IF;
  END IF;

  RETURN QUERY
  SELECT sr.txn_date, sr.transaction_id, sr.session_id, sr.txn_type, sr.description,
    sr.duration_seconds, sr.rate_per_minute, sr.debit, sr.credit,
    (v_opening + SUM(sr.credit - sr.debit) OVER (ORDER BY sr.txn_date, sr.row_num))::numeric AS running_balance,
    sr.start_time, sr.end_time
  FROM _stmt_rows sr ORDER BY sr.txn_date, sr.row_num;
END;
$function$;
