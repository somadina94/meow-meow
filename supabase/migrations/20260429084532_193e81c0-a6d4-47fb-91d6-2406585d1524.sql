-- Grant SELECT, INSERT, UPDATE on wallet_transactions and wallet_transactions_archive
-- to authenticated users so billing flows (group calls, chat, etc.) can write
-- ledger entries through RLS. service_role gets full access for backend tasks.
-- anon remains denied.

GRANT SELECT, INSERT, UPDATE ON public.wallet_transactions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.wallet_transactions_archive TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.wallet_transactions TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.wallet_transactions_archive TO service_role;

REVOKE ALL ON public.wallet_transactions FROM anon;
REVOKE ALL ON public.wallet_transactions_archive FROM anon;