
-- Drop the old function first (return type changed)
DROP FUNCTION IF EXISTS public.get_ledger_statement(uuid, text, text);

-- Fix ledger_bill_session: remove redundant direct ledger_transactions inserts
CREATE OR REPLACE FUNCTION public.ledger_bill_session(
  p_session_id text,
  p_session_type text,
  p_man_id uuid,
  p_woman_id uuid,
  p_minute_number integer,
  p_man_charge numeric,
  p_woman_earn numeric,
  p_duration_seconds integer DEFAULT 60
)
RETURNS jsonb
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
BEGIN
  v_idem_key := p_session_type || ':' || p_session_id::text || ':min:' || p_minute_number::text;
  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'idempotency_key', v_idem_key);
  END IF;

  IF ROUND(p_woman_earn, 2) <> ROUND(p_man_charge / 2.0, 2) THEN
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
    COALESCE(p_duration_seconds, 60), p_man_charge);

  -- Single ledger insert for man (debit)
  PERFORM public.safe_ledger_insert(
    p_man_id, p_session_id, p_session_type || '_charge',
    p_man_charge, 0, p_man_charge, COALESCE(p_duration_seconds, 60), p_woman_id,
    v_idem_key, initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_man_charge || '/min', now()
  );

  IF p_woman_earn > 0 THEN
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
    VALUES (p_woman_id, 'credit', p_session_type || '_earning', p_woman_earn,
      initcap(replace(p_session_type,'_',' ')) || ': min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min (½ of ₹' || p_man_charge || ')',
      p_session_id, (SELECT balance FROM public.wallets WHERE id = v_woman_wallet), v_idem_key_woman, 'completed',
      COALESCE(p_duration_seconds, 60), p_woman_earn);

    -- Single ledger insert for woman (earning) with CORRECT specific type
    PERFORM public.safe_ledger_insert(
      p_woman_id, p_session_id, p_session_type || '_earning',
      0, p_woman_earn, p_woman_earn, COALESCE(p_duration_seconds, 60), p_man_id,
      v_idem_key_woman, initcap(replace(p_session_type,'_',' ')) || ' earning: min ' || p_minute_number || ' @ ₹' || p_woman_earn || '/min', now()
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'charged', p_man_charge,
    'earned', p_woman_earn,
    'minute_number', p_minute_number, 'idempotency_key', v_idem_key);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Recreate get_ledger_statement with proper running balance
CREATE OR REPLACE FUNCTION public.get_ledger_statement(
  p_user_id uuid,
  p_from_date text DEFAULT NULL,
  p_to_date text DEFAULT NULL
)
RETURNS TABLE(
  id uuid,
  session_id text,
  transaction_type text,
  debit numeric,
  credit numeric,
  description text,
  reference_id text,
  counterparty_id uuid,
  running_balance numeric,
  created_at timestamptz,
  duration_seconds integer,
  rate_per_minute numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH ordered AS (
    SELECT
      t.id,
      t.session_id,
      t.transaction_type,
      t.debit,
      t.credit,
      t.description,
      t.reference_id,
      t.counterparty_id,
      t.created_at,
      t.duration_seconds::INTEGER,
      t.rate_per_minute,
      SUM(t.credit - t.debit) OVER (ORDER BY t.created_at, t.id) AS running_balance
    FROM ledger_transactions t
    WHERE t.user_id = p_user_id
      AND (p_from_date IS NULL OR t.created_at >= p_from_date::DATE)
      AND (p_to_date IS NULL OR t.created_at < (p_to_date::DATE + INTERVAL '1 day'))
  )
  SELECT
    ordered.id,
    ordered.session_id,
    ordered.transaction_type,
    ordered.debit,
    ordered.credit,
    ordered.description,
    ordered.reference_id,
    ordered.counterparty_id,
    ordered.running_balance,
    ordered.created_at,
    ordered.duration_seconds,
    ordered.rate_per_minute
  FROM ordered
  ORDER BY ordered.created_at DESC, ordered.id DESC;
END;
$$;

-- Expand transaction type constraint
ALTER TABLE public.ledger_transactions DROP CONSTRAINT IF EXISTS ledger_transactions_transaction_type_check;

ALTER TABLE public.ledger_transactions ADD CONSTRAINT ledger_transactions_transaction_type_check
CHECK (transaction_type = ANY (ARRAY[
  'recharge', 'credit', 'refund',
  'chat_charge', 'chat_earning',
  'audio_call_charge', 'audio_call_earning',
  'video_call_charge', 'video_call_earning',
  'group_call_charge', 'group_call_earning',
  'private_group_call_charge', 'private_group_call_earning',
  'gift_charge', 'gift_earning',
  'tip_charge', 'tip_earning',
  'earning', 'debit', 'withdrawal',
  'opening_balance', 'monthly_closing'
]));
