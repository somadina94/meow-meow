DROP FUNCTION IF EXISTS public.get_ledger_statement(uuid, text, text);

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
  counterparty_id text,
  running_balance numeric,
  created_at timestamptz,
  duration_seconds integer,
  rate_per_minute numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH ordered AS (
    SELECT
      t.id,
      t.session_id::text AS session_id,
      t.transaction_type,
      t.debit,
      t.credit,
      t.description,
      t.reference_id,
      t.counterparty_id::text AS counterparty_id,
      t.created_at,
      t.duration_seconds::integer AS duration_seconds,
      t.rate_per_minute,
      SUM(t.credit - t.debit) OVER (ORDER BY t.created_at, t.id) AS running_balance
    FROM public.ledger_transactions t
    WHERE t.user_id = p_user_id
      AND (p_from_date IS NULL OR t.created_at >= p_from_date::date)
      AND (p_to_date IS NULL OR t.created_at < (p_to_date::date + INTERVAL '1 day'))
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

GRANT EXECUTE ON FUNCTION public.get_ledger_statement(uuid, text, text) TO authenticated;