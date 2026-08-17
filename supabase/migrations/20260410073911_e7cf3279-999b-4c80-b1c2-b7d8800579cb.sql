
DROP FUNCTION IF EXISTS public.safe_ledger_insert(uuid, uuid, text, numeric, numeric, numeric, integer, uuid, text, text, timestamptz);

CREATE OR REPLACE FUNCTION public.safe_ledger_insert(
  p_user_id uuid,
  p_session_id uuid,
  p_entry_type text,
  p_debit numeric,
  p_credit numeric,
  p_rate numeric,
  p_duration_seconds integer,
  p_counterparty_id uuid,
  p_ref_key text,
  p_description text,
  p_timestamp timestamptz
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender text;
  v_balance numeric;
BEGIN
  -- Idempotency guard
  IF p_ref_key IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.platform_ledger WHERE idempotency_key = p_ref_key
  ) THEN
    RETURN;
  END IF;

  SELECT COALESCE(p.gender, 'male') INTO v_gender FROM public.profiles p WHERE p.user_id = p_user_id;
  SELECT COALESCE(w.balance, 0) INTO v_balance FROM public.wallets w WHERE w.user_id = p_user_id;

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
      p_user_id, p_session_id, p_entry_type, p_debit, p_credit,
      p_rate, p_duration_seconds, p_counterparty_id, p_ref_key, p_description
    );
  END IF;

EXCEPTION WHEN unique_violation THEN
  NULL;
END;
$$;

-- Backfill existing platform_ledger records into ledger_transactions
INSERT INTO public.ledger_transactions (user_id, session_id, transaction_type, debit, credit, rate_per_minute, duration_seconds, counterparty_id, reference_id, description, created_at)
SELECT 
  pl.user_id,
  CASE WHEN pl.session_id ~ '^[0-9a-f]{8}-' THEN pl.session_id::uuid ELSE NULL END,
  pl.entry_type,
  pl.debit,
  pl.credit,
  pl.rate_per_unit,
  CASE WHEN pl.duration_minutes IS NOT NULL THEN ROUND(pl.duration_minutes * 60)::integer ELSE NULL END,
  pl.counterparty_id,
  pl.idempotency_key,
  pl.description,
  pl.created_at_ist
FROM public.platform_ledger pl
WHERE pl.idempotency_key IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.ledger_transactions lt WHERE lt.reference_id = pl.idempotency_key
  );
