-- Bulk canonical balance lookup for men, derived from wallet_transactions (Single SoT).
-- Returns one row per requested user_id with their current balance (0 if no transactions / row missing).
CREATE OR REPLACE FUNCTION public.get_men_wallet_balances_bulk(p_user_ids uuid[])
RETURNS TABLE(user_id uuid, balance numeric)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    u AS user_id,
    COALESCE((
      SELECT SUM(wt.amount)::numeric
      FROM public.wallet_transactions wt
      WHERE wt.user_id = u
    ), 0) AS balance
  FROM unnest(p_user_ids) AS u
$$;

GRANT EXECUTE ON FUNCTION public.get_men_wallet_balances_bulk(uuid[]) TO authenticated;