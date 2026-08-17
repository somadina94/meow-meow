CREATE OR REPLACE FUNCTION public.get_ledger_statement(
  p_user_id uuid,
  p_from_date text DEFAULT NULL::text,
  p_to_date text DEFAULT NULL::text
)
RETURNS TABLE(
  id uuid, session_id text, transaction_type text, debit numeric, credit numeric,
  description text, reference_id text, counterparty_id text, running_balance numeric,
  created_at timestamp with time zone, duration_seconds integer, rate_per_minute numeric
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_from timestamptz;
  v_to timestamptz;
  v_opening_balance numeric := 0;
  v_archive_cutoff timestamptz := now() - interval '3 months';
  v_need_archive boolean;
BEGIN
  IF p_user_id IS NULL THEN RETURN; END IF;

  IF auth.role() <> 'service_role' AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Not allowed to view this statement';
  END IF;

  IF p_from_date IS NOT NULL THEN
    v_from := (p_from_date::date::timestamp AT TIME ZONE 'Asia/Kolkata');
  END IF;
  IF p_to_date IS NOT NULL THEN
    v_to := ((p_to_date::date + 1)::timestamp AT TIME ZONE 'Asia/Kolkata');
  END IF;

  -- Pull from archive only if the requested window dips below the 3-month live cutoff
  v_need_archive := (v_from IS NULL) OR (v_from < v_archive_cutoff);

  -- Opening balance (sum of everything BEFORE v_from across both tables)
  IF v_from IS NOT NULL THEN
    SELECT GREATEST(COALESCE(SUM(CASE WHEN type='credit' THEN amount WHEN type='debit' THEN -amount ELSE 0 END), 0), 0)
    INTO v_opening_balance
    FROM (
      SELECT type, amount FROM public.wallet_transactions
        WHERE user_id = p_user_id AND status='completed' AND created_at < v_from
      UNION ALL
      SELECT type, amount FROM public.wallet_transactions_archive
        WHERE user_id = p_user_id AND status='completed' AND created_at < v_from
    ) prev;
  END IF;

  RETURN QUERY
  WITH unified AS (
    SELECT wt.id, wt.session_id, wt.type, wt.transaction_type, wt.amount,
           wt.description, wt.reference_id, wt.idempotency_key, wt.created_at,
           wt.duration_seconds, wt.rate_per_minute
    FROM public.wallet_transactions wt
    WHERE wt.user_id = p_user_id AND wt.status='completed'
      AND (v_from IS NULL OR wt.created_at >= v_from)
      AND (v_to IS NULL OR wt.created_at < v_to)
    UNION ALL
    SELECT wa.id, wa.session_id, wa.type, wa.transaction_type, wa.amount,
           wa.description, wa.reference_id, wa.idempotency_key, wa.created_at,
           wa.duration_seconds, wa.rate_per_minute
    FROM public.wallet_transactions_archive wa
    WHERE v_need_archive AND wa.user_id = p_user_id AND wa.status='completed'
      AND (v_from IS NULL OR wa.created_at >= v_from)
      AND (v_to IS NULL OR wa.created_at < v_to)
  ), filtered AS (
    SELECT u.id,
      u.session_id::text AS session_id,
      COALESCE(u.transaction_type, u.type)::text AS transaction_type,
      CASE WHEN u.type='debit' THEN u.amount ELSE 0::numeric END AS debit,
      CASE WHEN u.type='credit' THEN u.amount ELSE 0::numeric END AS credit,
      u.description,
      COALESCE(u.reference_id, u.idempotency_key)::text AS reference_id,
      NULL::text AS counterparty_id,
      u.created_at,
      COALESCE(u.duration_seconds,
        CASE WHEN u.rate_per_minute IS NOT NULL AND u.rate_per_minute > 0 AND u.amount > 0
             THEN ROUND((u.amount / u.rate_per_minute) * 60)::integer
             ELSE NULL END
      ) AS duration_seconds,
      u.rate_per_minute
    FROM unified u
  ), ordered AS (
    SELECT f.*,
      GREATEST(
        v_opening_balance + SUM(f.credit - f.debit) OVER (ORDER BY f.created_at, f.id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
        0
      )::numeric AS running_balance
    FROM filtered f
  )
  SELECT o.id, o.session_id, o.transaction_type, o.debit, o.credit,
         o.description, o.reference_id, o.counterparty_id, o.running_balance,
         o.created_at, o.duration_seconds, o.rate_per_minute
  FROM ordered o
  ORDER BY o.created_at DESC, o.id DESC;
END;
$function$;