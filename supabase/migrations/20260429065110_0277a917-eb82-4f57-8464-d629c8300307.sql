-- USER OVERRIDE: grant INSERT + UPDATE on own rows for all authenticated users
-- on wallet_transactions and wallet_transactions_archive. No DELETE.

-- wallet_transactions
DROP POLICY IF EXISTS "Users can insert own wallet_transactions" ON public.wallet_transactions;
CREATE POLICY "Users can insert own wallet_transactions"
  ON public.wallet_transactions
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own wallet_transactions" ON public.wallet_transactions;
CREATE POLICY "Users can update own wallet_transactions"
  ON public.wallet_transactions
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- wallet_transactions_archive
DROP POLICY IF EXISTS "Users can insert own wallet_transactions_archive" ON public.wallet_transactions_archive;
CREATE POLICY "Users can insert own wallet_transactions_archive"
  ON public.wallet_transactions_archive
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own wallet_transactions_archive" ON public.wallet_transactions_archive;
CREATE POLICY "Users can update own wallet_transactions_archive"
  ON public.wallet_transactions_archive
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());