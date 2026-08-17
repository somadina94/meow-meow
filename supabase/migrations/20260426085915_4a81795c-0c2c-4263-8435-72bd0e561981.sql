-- Drop the problematic FK that's blocking signup
ALTER TABLE public.users_wallet DROP CONSTRAINT IF EXISTS users_wallet_user_id_fkey;

-- Ensure cleanup of users_wallet when wallets row is deleted
CREATE OR REPLACE FUNCTION public.cleanup_users_wallet_on_wallet_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  DELETE FROM public.users_wallet WHERE user_id = OLD.user_id;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_cleanup_users_wallet_on_wallet_delete ON public.wallets;
CREATE TRIGGER trg_cleanup_users_wallet_on_wallet_delete
AFTER DELETE ON public.wallets
FOR EACH ROW
EXECUTE FUNCTION public.cleanup_users_wallet_on_wallet_delete();