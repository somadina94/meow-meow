
-- Drop functions with conflicting signatures
DROP FUNCTION IF EXISTS public.ledger_bill_session(uuid,text,uuid,uuid,integer,numeric,numeric);
DROP FUNCTION IF EXISTS public.ledger_bill_group_call(uuid,uuid,uuid[],integer,numeric,numeric);

-- 1. Recreate ledger_bill_session — writes women credits to wallet_transactions too
CREATE OR REPLACE FUNCTION public.ledger_bill_session(
  p_session_id uuid,
  p_session_type text,
  p_man_id uuid,
  p_woman_id uuid,
  p_minute_number integer,
  p_man_charge numeric,
  p_woman_earn numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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

  INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status)
  VALUES (p_man_id, 'debit', 'debit', p_man_charge,
    initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_man_charge || '/min',
    p_session_id, (SELECT balance FROM public.wallets WHERE id = v_man_wallet_id), v_idem_key, 'completed');

  IF v_woman_indian AND p_woman_earn > 0 THEN
    SELECT id INTO v_woman_wallet FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
    IF v_woman_wallet IS NOT NULL THEN
      UPDATE public.wallets SET balance = balance + p_woman_earn, updated_at = now() WHERE id = v_woman_wallet;
    END IF;

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, created_at)
    VALUES (p_woman_id, p_woman_earn, p_session_type,
      initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min (½ of ₹' || p_man_charge || ')', now());

    v_idem_key_woman := p_session_type || ':' || p_session_id::text || ':earn:' || p_minute_number::text;
    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status)
    VALUES (p_woman_id, 'credit', p_session_type, p_woman_earn,
      initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min (½ of ₹' || p_man_charge || ')',
      p_session_id, (SELECT balance FROM public.wallets WHERE id = v_woman_wallet), v_idem_key_woman, 'completed');
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', p_man_charge,
    'earned', CASE WHEN v_woman_indian THEN p_woman_earn ELSE 0 END,
    'minute_number', p_minute_number, 'idempotency_key', v_idem_key);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 2. Recreate ledger_bill_group_call — uses wallets table, writes women credits to wallet_transactions
CREATE OR REPLACE FUNCTION public.ledger_bill_group_call(
  p_session_id uuid,
  p_woman_id uuid,
  p_man_ids uuid[],
  p_minute_number integer,
  p_charge_per_man numeric,
  p_earn_per_man numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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

    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status)
    VALUES (v_man_id, 'debit', 'group_call_charge', p_charge_per_man,
      'Group Call: min ' || p_minute_number || ' @ ₹' || p_charge_per_man || '/min',
      p_session_id, (SELECT balance FROM public.wallets WHERE user_id = v_man_id), v_ref_man, 'completed');

    PERFORM public.safe_ledger_insert(v_man_id, p_session_id, 'group_call_charge', p_charge_per_man, 0,
      p_charge_per_man, 60, p_woman_id, v_ref_man, 'Group call charge minute ' || p_minute_number, now());

    v_total_woman_earn := v_total_woman_earn + p_earn_per_man;

    PERFORM public.safe_ledger_insert(p_woman_id, p_session_id, 'earning', 0, p_earn_per_man,
      p_earn_per_man, 60, v_man_id, v_ref_woman, 'Group call earning from man minute ' || p_minute_number, now());

    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status)
    VALUES (p_woman_id, 'credit', 'group_call_earning', p_earn_per_man,
      'Group Call Earning: min ' || p_minute_number || ' @ ₹' || p_earn_per_man || '/man',
      p_session_id, NULL, v_ref_woman, 'completed');

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, group_id, man_user_id, created_at)
    VALUES (p_woman_id, p_earn_per_man, 'group_call', 'Group call earning min ' || p_minute_number || ' @ ₹' || p_earn_per_man || '/man',
      p_session_id, v_man_id, now());
  END LOOP;

  IF v_total_woman_earn > 0 THEN
    UPDATE public.wallets SET balance = balance + v_total_woman_earn, updated_at = now() WHERE user_id = p_woman_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'minute', p_minute_number, 'woman_earned', v_total_woman_earn);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 3. Unified statement summary — both genders use wallet_transactions
CREATE OR REPLACE FUNCTION public.get_my_statement_summary(p_year integer, p_month integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id         uuid := auth.uid();
  v_gender          text;
  v_period_start    timestamptz;
  v_period_end      timestamptz;
  v_opening_balance numeric(12,2) := 0;
  v_total_debit     numeric(12,2) := 0;
  v_total_credit    numeric(12,2) := 0;
  v_closing_balance numeric(12,2);
  v_prev_year       integer;
  v_prev_month      integer;
BEGIN
  IF v_user_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Not authenticated'); END IF;

  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = v_user_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Profile not found'); END IF;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1; END IF;

  SELECT closing_balance INTO v_opening_balance FROM public.monthly_statements
  WHERE user_id = v_user_id AND year = v_prev_year AND month = v_prev_month;

  IF v_opening_balance IS NULL THEN
    SELECT COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0)
           - COALESCE(SUM(CASE WHEN type = 'debit' THEN amount ELSE 0 END), 0)
    INTO v_opening_balance
    FROM public.wallet_transactions
    WHERE user_id = v_user_id AND created_at < v_period_start AND status = 'completed';
  END IF;

  SELECT COALESCE(SUM(CASE WHEN type = 'debit' THEN amount ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0)
  INTO v_total_debit, v_total_credit
  FROM public.wallet_transactions
  WHERE user_id = v_user_id AND created_at >= v_period_start AND created_at < v_period_end AND status = 'completed';

  v_closing_balance := v_opening_balance + v_total_credit - v_total_debit;

  RETURN jsonb_build_object('success', true, 'gender', v_gender, 'year', p_year, 'month', p_month,
    'opening_balance', v_opening_balance, 'total_debit', v_total_debit, 'total_credit', v_total_credit, 'closing_balance', v_closing_balance);
END;
$$;

-- 4. Unified statement detail — both genders use wallet_transactions
CREATE OR REPLACE FUNCTION public.get_my_statement_detail(p_year integer, p_month integer)
RETURNS TABLE(txn_date timestamptz, transaction_id text, session_id text, txn_type text, description text, duration_seconds integer, rate_per_minute numeric, debit numeric, credit numeric, running_balance numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id        uuid := auth.uid();
  v_period_start   timestamptz;
  v_period_end     timestamptz;
  v_opening        numeric(12,2) := 0;
  v_prev_year      integer;
  v_prev_month     integer;
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  IF p_month = 1 THEN v_prev_year := p_year - 1; v_prev_month := 12;
  ELSE v_prev_year := p_year; v_prev_month := p_month - 1; END IF;

  SELECT ms.closing_balance INTO v_opening FROM public.monthly_statements ms
  WHERE ms.user_id = v_user_id AND ms.year = v_prev_year AND ms.month = v_prev_month;

  IF v_opening IS NULL THEN
    SELECT COALESCE(SUM(CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END), 0)
           - COALESCE(SUM(CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END), 0)
    INTO v_opening
    FROM public.wallet_transactions wt
    WHERE wt.user_id = v_user_id AND wt.created_at < v_period_start AND wt.status = 'completed';
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS _stmt_rows (
    row_num serial, txn_date timestamptz, transaction_id text, session_id text,
    txn_type text, description text, duration_seconds integer, rate_per_minute numeric,
    debit numeric NOT NULL DEFAULT 0, credit numeric NOT NULL DEFAULT 0
  ) ON COMMIT DROP;
  TRUNCATE _stmt_rows;

  INSERT INTO _stmt_rows (txn_date, transaction_id, session_id, txn_type, description, duration_seconds, rate_per_minute, debit, credit)
  SELECT wt.created_at, wt.id::text, wt.session_id::text,
    COALESCE(wt.transaction_type, wt.type), wt.description, NULL::integer, NULL::numeric,
    CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END,
    CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END
  FROM public.wallet_transactions wt
  WHERE wt.user_id = v_user_id AND wt.created_at >= v_period_start AND wt.created_at < v_period_end AND wt.status = 'completed'
  ORDER BY wt.created_at, wt.id;

  RETURN QUERY
  SELECT sr.txn_date, sr.transaction_id, sr.session_id, sr.txn_type, sr.description,
    sr.duration_seconds, sr.rate_per_minute, sr.debit, sr.credit,
    (v_opening + SUM(sr.credit - sr.debit) OVER (ORDER BY sr.txn_date, sr.row_num))::numeric AS running_balance
  FROM _stmt_rows sr ORDER BY sr.txn_date, sr.row_num;
END;
$$;
