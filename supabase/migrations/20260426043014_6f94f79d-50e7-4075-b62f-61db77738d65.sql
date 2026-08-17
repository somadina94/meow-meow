-- Fix safe_ledger_insert: 
-- 1) Map profile gender ('male'/'female') to platform_ledger constraint ('men'/'women')
-- 2) Map entry_type to the correct transaction_type for ledger_transactions (which has different allowed values than platform_ledger.entry_type)

CREATE OR REPLACE FUNCTION public.safe_ledger_insert(
  p_user_id uuid, p_session_id uuid, p_entry_type text,
  p_debit numeric, p_credit numeric, p_rate numeric,
  p_duration_seconds integer, p_counterparty_id uuid,
  p_ref_key text, p_description text, p_timestamp timestamp with time zone
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_gender_raw text;
  v_gender text;
  v_balance numeric;
  v_txn_type text;
BEGIN
  -- Idempotency guard
  IF p_ref_key IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.platform_ledger WHERE idempotency_key = p_ref_key
  ) THEN
    RETURN;
  END IF;

  SELECT p.gender INTO v_gender_raw FROM public.profiles p WHERE p.user_id = p_user_id;

  -- Map profile gender values to platform_ledger constraint values
  v_gender := CASE
    WHEN v_gender_raw IN ('male', 'men', 'm') THEN 'men'
    WHEN v_gender_raw IN ('female', 'women', 'woman', 'f') THEN 'women'
    ELSE 'men'  -- safe default
  END;

  SELECT COALESCE(w.balance, 0) INTO v_balance FROM public.wallets w WHERE w.user_id = p_user_id;

  -- Map entry_type to ledger_transactions.transaction_type (constraint allows different set)
  v_txn_type := CASE p_entry_type
    WHEN 'gift_debit'  THEN 'tip_charge'
    WHEN 'gift_credit' THEN 'tip_earning'
    WHEN 'chat_debit'  THEN 'chat_charge'
    WHEN 'chat_credit' THEN 'chat_earning'
    WHEN 'video_debit' THEN 'video_call_charge'
    WHEN 'video_credit' THEN 'video_call_earning'
    WHEN 'audio_debit' THEN 'audio_call_charge'
    WHEN 'audio_credit' THEN 'audio_call_earning'
    WHEN 'group_call_debit' THEN 'group_call_charge'
    WHEN 'group_call_credit' THEN 'group_call_earning'
    ELSE p_entry_type
  END;

  -- Insert into platform_ledger
  INSERT INTO public.platform_ledger (
    user_id, user_gender, entry_type, debit, credit, balance_after,
    session_id, counterparty_id, session_type, duration_minutes, rate_per_unit,
    idempotency_key, description, created_at_ist,
    ist_date, ist_month, ist_year
  ) VALUES (
    p_user_id, v_gender, p_entry_type, p_debit, p_credit, v_balance,
    p_session_id::text, p_counterparty_id, p_entry_type,
    CASE WHEN p_duration_seconds > 0 THEN p_duration_seconds / 60.0 ELSE NULL END,
    p_rate, p_ref_key, p_description, p_timestamp,
    (p_timestamp AT TIME ZONE 'Asia/Kolkata')::date,
    to_char(p_timestamp AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM'),
    EXTRACT(YEAR FROM p_timestamp AT TIME ZONE 'Asia/Kolkata')::integer
  );

  -- Also insert into ledger_transactions for statement visibility (skip if duplicate ref)
  IF NOT EXISTS (SELECT 1 FROM public.ledger_transactions WHERE reference_id = p_ref_key AND p_ref_key IS NOT NULL) THEN
    INSERT INTO public.ledger_transactions (
      user_id, session_id, transaction_type, debit, credit,
      rate_per_minute, duration_seconds, counterparty_id, reference_id, description
    ) VALUES (
      p_user_id, p_session_id, v_txn_type, p_debit, p_credit,
      p_rate, p_duration_seconds, p_counterparty_id, p_ref_key, p_description
    );
  END IF;

EXCEPTION WHEN unique_violation THEN
  NULL;
END;
$function$;