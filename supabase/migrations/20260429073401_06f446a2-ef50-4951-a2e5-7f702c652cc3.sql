-- 1) Archive job: keep only 2 months in live table
CREATE OR REPLACE FUNCTION public.archive_old_wallet_transactions()
 RETURNS TABLE(archived_count integer, cutoff_date timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_cutoff timestamptz := now() - interval '2 months';
  v_count integer := 0;
BEGIN
  WITH moved AS (
    DELETE FROM public.wallet_transactions
    WHERE created_at < v_cutoff
    RETURNING *
  )
  INSERT INTO public.wallet_transactions_archive (
    id, wallet_id, user_id, type, amount, description, reference_id,
    status, created_at, idempotency_key, session_id, session_type,
    transaction_type, balance_after, duration_seconds, rate_per_minute,
    billing_metadata
  )
  SELECT
    id, wallet_id, user_id, type, amount, description, reference_id,
    status, created_at, idempotency_key, session_id, session_type,
    transaction_type, balance_after, duration_seconds, rate_per_minute,
    billing_metadata
  FROM moved
  ON CONFLICT (id) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN QUERY SELECT v_count, v_cutoff;
END;
$function$;

-- 2) Statement RPC: archive cutoff = 2 months; hard 6-month visibility cap for non-admin users
CREATE OR REPLACE FUNCTION public.get_ledger_statement(p_user_id uuid, p_from_date text DEFAULT NULL::text, p_to_date text DEFAULT NULL::text)
 RETURNS TABLE(id uuid, session_id text, transaction_type text, debit numeric, credit numeric, description text, reference_id text, counterparty_id text, running_balance numeric, created_at timestamp with time zone, duration_seconds integer, rate_per_minute numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := public.resolve_wallet_user_id(p_user_id);
  v_from timestamptz;
  v_to timestamptz;
  v_opening_balance numeric := 0;
  v_archive_cutoff timestamptz := now() - interval '2 months';
  v_visibility_floor timestamptz := now() - interval '6 months';
  v_is_admin boolean := false;
  v_need_archive boolean;
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  IF auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_user_id
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Not allowed to view this statement';
  END IF;

  v_is_admin := public.has_role(auth.uid(), 'admin') OR auth.role() = 'service_role';

  IF p_from_date IS NOT NULL THEN
    v_from := (p_from_date::date::timestamp AT TIME ZONE 'Asia/Kolkata');
  END IF;
  IF p_to_date IS NOT NULL THEN
    v_to := ((p_to_date::date + 1)::timestamp AT TIME ZONE 'Asia/Kolkata');
  END IF;

  -- Enforce 6-month visibility floor for non-admin users
  IF NOT v_is_admin THEN
    IF v_from IS NULL OR v_from < v_visibility_floor THEN
      v_from := v_visibility_floor;
    END IF;
  END IF;

  v_need_archive := (v_from IS NULL) OR (v_from < v_archive_cutoff);

  IF v_from IS NOT NULL THEN
    SELECT GREATEST(
             COALESCE(SUM(CASE WHEN prev.type='credit' THEN prev.amount
                               WHEN prev.type='debit'  THEN -prev.amount
                               ELSE 0 END), 0), 0)
    INTO v_opening_balance
    FROM (
      SELECT wt.type, wt.amount
      FROM public.wallet_transactions wt
      WHERE wt.user_id = v_user_id
        AND wt.status='completed'
        AND wt.created_at < v_from
      UNION ALL
      SELECT wa.type, wa.amount
      FROM public.wallet_transactions_archive wa
      WHERE wa.user_id = v_user_id
        AND wa.status='completed'
        AND wa.created_at < v_from
    ) prev;
  END IF;

  RETURN QUERY
  WITH unified AS (
    SELECT wt.id, wt.session_id, wt.type, wt.transaction_type, wt.amount,
           wt.description, wt.reference_id, wt.idempotency_key, wt.created_at,
           wt.duration_seconds, wt.rate_per_minute
    FROM public.wallet_transactions wt
    WHERE wt.user_id = v_user_id AND wt.status='completed'
      AND (v_from IS NULL OR wt.created_at >= v_from)
      AND (v_to   IS NULL OR wt.created_at <  v_to)
    UNION ALL
    SELECT wa.id, wa.session_id, wa.type, wa.transaction_type, wa.amount,
           wa.description, wa.reference_id, wa.idempotency_key, wa.created_at,
           wa.duration_seconds, wa.rate_per_minute
    FROM public.wallet_transactions_archive wa
    WHERE v_need_archive AND wa.user_id = v_user_id AND wa.status='completed'
      AND (v_from IS NULL OR wa.created_at >= v_from)
      AND (v_to   IS NULL OR wa.created_at <  v_to)
  ), filtered AS (
    SELECT u.id,
           u.session_id::text AS session_id,
           COALESCE(u.transaction_type, u.type)::text AS transaction_type,
           CASE WHEN u.type='debit'  THEN u.amount ELSE 0::numeric END AS debit,
           CASE WHEN u.type='credit' THEN u.amount ELSE 0::numeric END AS credit,
           u.description,
           COALESCE(u.reference_id, u.idempotency_key)::text AS reference_id,
           NULL::text AS counterparty_id,
           u.created_at,
           u.duration_seconds,
           u.rate_per_minute,
           u.type AS _type,
           u.amount AS _amount
    FROM unified u
  )
  SELECT
    f.id, f.session_id, f.transaction_type, f.debit, f.credit,
    f.description, f.reference_id, f.counterparty_id,
    GREATEST(v_opening_balance + SUM(CASE WHEN f._type='credit' THEN f._amount
                                          WHEN f._type='debit'  THEN -f._amount
                                          ELSE 0 END)
              OVER (ORDER BY f.created_at, f.id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0) AS running_balance,
    f.created_at, f.duration_seconds, f.rate_per_minute
  FROM filtered f
  ORDER BY f.created_at, f.id;
END;
$function$;