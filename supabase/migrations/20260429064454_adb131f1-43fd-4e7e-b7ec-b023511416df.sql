-- Allow each authenticated user to SELECT their own rows in wallet_transactions and wallet_transactions_archive.
-- Writes remain restricted to SECURITY DEFINER billing RPCs / service_role / admins.

-- wallet_transactions: read own rows
DROP POLICY IF EXISTS "Users can read own wallet_transactions" ON public.wallet_transactions;
CREATE POLICY "Users can read own wallet_transactions"
  ON public.wallet_transactions
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- wallet_transactions_archive: read own rows
DROP POLICY IF EXISTS "Users can read own wallet_transactions_archive" ON public.wallet_transactions_archive;
CREATE POLICY "Users can read own wallet_transactions_archive"
  ON public.wallet_transactions_archive
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());