-- Allow signup to create a 0-balance wallet without writing public.wallets from the browser.
GRANT EXECUTE ON FUNCTION public.ensure_canonical_wallet(uuid, text) TO authenticated, service_role;
