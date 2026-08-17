CREATE OR REPLACE FUNCTION public.get_men_with_balance(p_user_ids uuid[])
RETURNS TABLE(user_id uuid, balance numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT w.user_id, COALESCE(w.balance, 0)::numeric
  FROM wallets w
  WHERE w.user_id = ANY(p_user_ids)
    AND w.balance > 0;
END;
$$;