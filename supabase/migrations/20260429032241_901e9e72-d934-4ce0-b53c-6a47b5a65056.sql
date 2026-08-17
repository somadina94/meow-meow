-- Enforce wallet_transactions as the single source of truth for statements and balances.
-- Statements include all completed wallet transactions: chat, audio, video, private group calls,
-- gifts, tips, recharges, and withdrawals. Running balances carry forward from prior periods.

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
DECLARE
  v_from timestamptz;
  v_to timestamptz;
  v_opening_balance numeric := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  IF auth.role() <> 'service_role' AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Not allowed to view this statement';
  END IF;

  IF p_from_date IS NOT NULL THEN
    v_from := (p_from_date::date::timestamp AT TIME ZONE 'Asia/Kolkata');
  END IF;

  IF p_to_date IS NOT NULL THEN
    v_to := ((p_to_date::date + 1)::timestamp AT TIME ZONE 'Asia/Kolkata');
  END IF;

  SELECT GREATEST(
    COALESCE(SUM(CASE
      WHEN wt.type = 'credit' THEN wt.amount
      WHEN wt.type = 'debit' THEN -wt.amount
      ELSE 0
    END), 0),
    0
  )
  INTO v_opening_balance
  FROM public.wallet_transactions wt
  WHERE wt.user_id = p_user_id
    AND wt.status = 'completed'
    AND (v_from IS NOT NULL AND wt.created_at < v_from);

  IF v_from IS NULL THEN
    v_opening_balance := 0;
  END IF;

  RETURN QUERY
  WITH filtered AS (
    SELECT
      wt.id,
      wt.session_id::text AS session_id,
      COALESCE(wt.transaction_type, wt.type)::text AS transaction_type,
      CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0::numeric END AS debit,
      CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0::numeric END AS credit,
      wt.description,
      COALESCE(wt.reference_id, wt.idempotency_key)::text AS reference_id,
      NULL::text AS counterparty_id,
      wt.created_at,
      COALESCE(
        wt.duration_seconds,
        CASE
          WHEN wt.rate_per_minute IS NOT NULL AND wt.rate_per_minute > 0 AND wt.amount > 0
          THEN ROUND((wt.amount / wt.rate_per_minute) * 60)::integer
          ELSE NULL
        END
      ) AS duration_seconds,
      wt.rate_per_minute
    FROM public.wallet_transactions wt
    WHERE wt.user_id = p_user_id
      AND wt.status = 'completed'
      AND (v_from IS NULL OR wt.created_at >= v_from)
      AND (v_to IS NULL OR wt.created_at < v_to)
  ), ordered AS (
    SELECT
      f.*,
      GREATEST(
        v_opening_balance + SUM(f.credit - f.debit) OVER (ORDER BY f.created_at, f.id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
        0
      )::numeric AS running_balance
    FROM filtered f
  )
  SELECT
    o.id,
    o.session_id,
    o.transaction_type,
    o.debit,
    o.credit,
    o.description,
    o.reference_id,
    o.counterparty_id,
    o.running_balance,
    o.created_at,
    o.duration_seconds,
    o.rate_per_minute
  FROM ordered o
  ORDER BY o.created_at DESC, o.id DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_men_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance numeric := 0;
  v_currency text := 'INR';
  v_recharges numeric := 0;
  v_spending numeric := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('balance', 0, 'currency', 'INR', 'total_recharges', 0, 'total_spending', 0);
  END IF;

  IF auth.role() <> 'service_role' AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Not allowed to view this wallet';
  END IF;

  SELECT COALESCE(w.currency, 'INR') INTO v_currency
  FROM public.wallets w
  WHERE w.user_id = p_user_id;

  SELECT
    COALESCE(SUM(CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END), 0),
    GREATEST(COALESCE(SUM(CASE WHEN wt.type = 'credit' THEN wt.amount WHEN wt.type = 'debit' THEN -wt.amount ELSE 0 END), 0), 0)
  INTO v_recharges, v_spending, v_balance
  FROM public.wallet_transactions wt
  WHERE wt.user_id = p_user_id
    AND wt.status = 'completed';

  RETURN jsonb_build_object(
    'balance', v_balance,
    'currency', COALESCE(v_currency, 'INR'),
    'total_recharges', v_recharges,
    'total_spending', v_spending
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_women_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance numeric := 0;
  v_earnings numeric := 0;
  v_debits numeric := 0;
  v_pending numeric := 0;
  v_today numeric := 0;
  v_today_start timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('total_earnings', 0, 'total_debits', 0, 'pending_withdrawals', 0, 'today_earnings', 0, 'available_balance', 0);
  END IF;

  IF auth.role() <> 'service_role' AND auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Not allowed to view this wallet';
  END IF;

  v_today_start := date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata';

  SELECT
    COALESCE(SUM(CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0 END), 0),
    GREATEST(COALESCE(SUM(CASE WHEN wt.type = 'credit' THEN wt.amount WHEN wt.type = 'debit' THEN -wt.amount ELSE 0 END), 0), 0),
    COALESCE(SUM(CASE WHEN wt.type = 'credit' AND wt.created_at >= v_today_start THEN wt.amount ELSE 0 END), 0)
  INTO v_earnings, v_debits, v_balance, v_today
  FROM public.wallet_transactions wt
  WHERE wt.user_id = p_user_id
    AND wt.status = 'completed';

  SELECT COALESCE(SUM(wr.amount), 0)
  INTO v_pending
  FROM public.withdrawal_requests wr
  WHERE wr.user_id = p_user_id
    AND wr.status = 'pending';

  RETURN jsonb_build_object(
    'total_earnings', v_earnings,
    'total_debits', v_debits,
    'pending_withdrawals', v_pending,
    'today_earnings', v_today,
    'available_balance', v_balance
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.reconcile_wallet_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_balance numeric := 0;
  v_computed_balance numeric := 0;
  v_diff numeric := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Missing user_id');
  END IF;

  SELECT COALESCE(w.balance, 0)
  INTO v_current_balance
  FROM public.wallets w
  WHERE w.user_id = p_user_id;

  SELECT GREATEST(COALESCE(SUM(CASE
    WHEN wt.status = 'completed' AND wt.type = 'credit' THEN wt.amount
    WHEN wt.status = 'completed' AND wt.type = 'debit' THEN -wt.amount
    ELSE 0
  END), 0), 0)
  INTO v_computed_balance
  FROM public.wallet_transactions wt
  WHERE wt.user_id = p_user_id;

  UPDATE public.wallets
  SET balance = v_computed_balance,
      updated_at = now()
  WHERE user_id = p_user_id;

  v_diff := v_current_balance - v_computed_balance;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', p_user_id,
    'previous_balance', v_current_balance,
    'computed_balance', v_computed_balance,
    'difference', v_diff,
    'wallet_balance', v_computed_balance,
    'in_sync', true
  );
END;
$$;

-- Keep stored wallet balances equal to the canonical transaction sum for every user.
UPDATE public.wallets w
SET balance = d.computed_balance,
    updated_at = now()
FROM (
  SELECT
    all_users.user_id,
    GREATEST(COALESCE(SUM(CASE
      WHEN wt.status = 'completed' AND wt.type = 'credit' THEN wt.amount
      WHEN wt.status = 'completed' AND wt.type = 'debit' THEN -wt.amount
      ELSE 0
    END), 0), 0) AS computed_balance
  FROM (
    SELECT user_id FROM public.wallets
    UNION
    SELECT user_id FROM public.wallet_transactions
  ) all_users
  LEFT JOIN public.wallet_transactions wt ON wt.user_id = all_users.user_id
  GROUP BY all_users.user_id
) d
WHERE w.user_id = d.user_id
  AND ABS(COALESCE(w.balance, 0) - d.computed_balance) > 0.01;

GRANT EXECUTE ON FUNCTION public.get_ledger_statement(uuid, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_men_wallet_balance(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_women_wallet_balance(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reconcile_wallet_balance(uuid) TO authenticated, service_role;
