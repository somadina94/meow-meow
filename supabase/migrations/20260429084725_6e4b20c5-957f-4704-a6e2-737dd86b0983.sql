CREATE OR REPLACE FUNCTION public.audit_wallet_table_grants()
RETURNS TABLE (
  table_name   text,
  grantee      text,
  can_select   boolean,
  can_insert   boolean,
  can_update   boolean,
  can_delete   boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.has_role(auth.uid(), 'admin'::app_role) THEN
    RAISE EXCEPTION 'Access denied: admin role required';
  END IF;

  RETURN QUERY
  SELECT
    c.relname::text                                          AS table_name,
    r.rolname::text                                          AS grantee,
    has_table_privilege(r.rolname, c.oid, 'SELECT')          AS can_select,
    has_table_privilege(r.rolname, c.oid, 'INSERT')          AS can_insert,
    has_table_privilege(r.rolname, c.oid, 'UPDATE')          AS can_update,
    has_table_privilege(r.rolname, c.oid, 'DELETE')          AS can_delete
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  CROSS JOIN pg_roles r
  WHERE n.nspname = 'public'
    AND c.relname IN ('wallet_transactions', 'wallet_transactions_archive')
    AND r.rolname IN ('anon', 'authenticated', 'service_role')
  ORDER BY c.relname, r.rolname;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.audit_wallet_table_grants() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.audit_wallet_table_grants() TO authenticated, service_role;