-- Drop old function with incompatible return type
DROP FUNCTION IF EXISTS public.admin_get_statement_detail(uuid, integer, integer);

-- Recreate with correct return type and logic
CREATE OR REPLACE FUNCTION public.admin_get_statement_detail(
  p_user_id uuid,
  p_year integer,
  p_month integer
)
RETURNS TABLE(
  txn_date timestamptz,
  transaction_id text,
  session_id text,
  txn_type text,
  duration_minutes integer,
  rate_per_minute numeric,
  debit numeric,
  credit numeric,
  balance_after numeric,
  description text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender text;
  v_period_start timestamptz;
  v_period_end timestamptz;
BEGIN
  SELECT gender INTO v_gender FROM public.profiles WHERE user_id = p_user_id;
  v_period_start := make_timestamptz(p_year, p_month, 1, 0, 0, 0, 'UTC');
  v_period_end   := v_period_start + interval '1 month';

  IF v_gender = 'male' THEN
    RETURN QUERY
      SELECT
        wt.created_at AS txn_date,
        wt.id::text AS transaction_id,
        wt.session_id::text AS session_id,
        wt.transaction_type AS txn_type,
        NULL::integer AS duration_minutes,
        NULL::numeric AS rate_per_minute,
        CASE WHEN wt.type = 'debit' THEN wt.amount ELSE 0::numeric END AS debit,
        CASE WHEN wt.type = 'credit' THEN wt.amount ELSE 0::numeric END AS credit,
        wt.balance_after,
        wt.description
      FROM public.wallet_transactions wt
      WHERE wt.user_id = p_user_id
        AND wt.created_at >= v_period_start
        AND wt.created_at < v_period_end
      ORDER BY wt.created_at;
  ELSE
    RETURN QUERY
      SELECT
        we.created_at AS txn_date,
        we.id::text AS transaction_id,
        COALESCE(we.chat_session_id, we.video_session_id, we.group_id, we.private_call_id)::text AS session_id,
        we.earning_type AS txn_type,
        CASE WHEN we.minutes_billed IS NOT NULL THEN we.minutes_billed::integer ELSE NULL END AS duration_minutes,
        we.rate_per_minute,
        0::numeric AS debit,
        we.amount AS credit,
        NULL::numeric AS balance_after,
        we.description
      FROM public.women_earnings we
      WHERE we.user_id = p_user_id
        AND we.created_at >= v_period_start
        AND we.created_at < v_period_end
      ORDER BY we.created_at;
  END IF;
END;
$$;