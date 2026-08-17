-- Fix: signup fails with "users_wallet_user_id_fkey" FK violation.
-- During auth.users INSERT trigger, public.handle_new_user() inserts into public.wallets,
-- which fires trg_sync_wallets_to_users_wallet, which inserts into public.users_wallet.
-- The FK to auth.users(id) is checked immediately and the new auth user row is not yet
-- visible to FK checks at that point in the transaction, so it errors with SQLSTATE 23503.
-- Making the FK DEFERRABLE INITIALLY DEFERRED defers the check to end-of-transaction,
-- by which time auth.users(id) is visible.

ALTER TABLE public.users_wallet
  DROP CONSTRAINT users_wallet_user_id_fkey;

ALTER TABLE public.users_wallet
  ADD CONSTRAINT users_wallet_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id)
  ON DELETE CASCADE
  DEFERRABLE INITIALLY DEFERRED;