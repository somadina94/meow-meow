CREATE OR REPLACE FUNCTION public.get_user_group_call_history(p_user_id uuid, p_is_male boolean, p_limit integer DEFAULT 50)
 RETURNS TABLE(id uuid, amount numeric, description text, duration_seconds integer, rate_per_minute numeric, created_at timestamp with time zone, transaction_type text, type text, session_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT id, amount, description, duration_seconds, rate_per_minute,
         created_at, transaction_type, type, session_id
  FROM (
    SELECT id, amount, description, duration_seconds, rate_per_minute,
           created_at, transaction_type, type, session_id, session_type, user_id
    FROM public.wallet_transactions
    UNION ALL
    SELECT id, amount, description, duration_seconds, rate_per_minute,
           created_at, transaction_type, type, session_id, session_type, user_id
    FROM public.wallet_transactions_archive
  ) u
  WHERE u.user_id = p_user_id
    AND (
      u.session_type = 'private_group_call'
      OR u.transaction_type IN ('group_charge','group_call_charge','private_group_call','private_group_call_charge','group_call_earning','private_group_call_earning')
      OR (u.transaction_type IN ('gift_charge','gift_earning') AND u.description ILIKE 'Group gift%')
    )
    AND (
      (p_is_male AND u.type = 'debit')
      OR (NOT p_is_male AND u.type = 'credit')
    )
  ORDER BY created_at DESC
  LIMIT p_limit;
$function$;