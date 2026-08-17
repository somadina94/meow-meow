-- Ensure group-call billing uses the audited RPC path, not anonymous direct access.
REVOKE EXECUTE ON FUNCTION public.bill_session_minute(uuid, text, numeric, uuid, uuid, integer, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.bill_session_minute(uuid, text, numeric, uuid, uuid, integer, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.bill_session_minute(uuid, text, numeric, uuid, uuid, integer, integer) TO authenticated, service_role;

-- Ensure authenticated users have the base privileges required for existing RLS policies
-- while RLS continues to restrict rows to the owner/admin/service paths.
GRANT SELECT, INSERT, UPDATE ON public.wallet_transactions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.wallet_transactions_archive TO authenticated;

-- Ensure backend/admin service can manage active and archived wallet transaction rows.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wallet_transactions TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wallet_transactions_archive TO service_role;

NOTIFY pgrst, 'reload schema';