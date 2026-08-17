
DROP FUNCTION IF EXISTS public.get_ledger_statement(UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.get_ledger_statement(
  p_user_id UUID,
  p_from_date TEXT DEFAULT NULL,
  p_to_date TEXT DEFAULT NULL
)
RETURNS TABLE(
  id UUID,
  session_id UUID,
  transaction_type TEXT,
  debit NUMERIC,
  credit NUMERIC,
  description TEXT,
  reference_id TEXT,
  counterparty_id UUID,
  running_balance NUMERIC,
  created_at TIMESTAMPTZ,
  duration_seconds INTEGER,
  rate_per_minute NUMERIC
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    t.id,
    t.session_id,
    t.transaction_type,
    t.debit,
    t.credit,
    t.description,
    t.reference_id,
    t.counterparty_id,
    SUM(t.credit - t.debit) OVER (ORDER BY t.created_at, t.id) AS running_balance,
    t.created_at,
    t.duration_seconds::INTEGER,
    t.rate_per_minute
  FROM ledger_transactions t
  WHERE t.user_id = p_user_id
    AND (p_from_date IS NULL OR t.created_at >= p_from_date::DATE)
    AND (p_to_date IS NULL OR t.created_at < (p_to_date::DATE + INTERVAL '1 day'))
  ORDER BY t.created_at DESC, t.id DESC;
$$;
