-- Grant admins full management on wallet_transactions and wallet_transactions_archive.
-- Owners (men/women) keep SELECT on their own rows on both tables, plus INSERT on live table.
-- Writes by app code still go through canonical billing RPCs (SECURITY DEFINER); these
-- policies only widen admin reach for support/audit operations from /admin pages.

-- wallet_transactions: admin UPDATE
DROP POLICY IF EXISTS "wallet_transactions_admin_update" ON public.wallet_transactions;
CREATE POLICY "wallet_transactions_admin_update"
  ON public.wallet_transactions FOR UPDATE
  TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- wallet_transactions: admin DELETE
DROP POLICY IF EXISTS "wallet_transactions_admin_delete" ON public.wallet_transactions;
CREATE POLICY "wallet_transactions_admin_delete"
  ON public.wallet_transactions FOR DELETE
  TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role));

-- wallet_transactions: admin INSERT (support corrections)
DROP POLICY IF EXISTS "wallet_transactions_admin_insert" ON public.wallet_transactions;
CREATE POLICY "wallet_transactions_admin_insert"
  ON public.wallet_transactions FOR INSERT
  TO authenticated
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- wallet_transactions_archive: admin INSERT/UPDATE/DELETE
DROP POLICY IF EXISTS "wallet_transactions_archive_admin_insert" ON public.wallet_transactions_archive;
CREATE POLICY "wallet_transactions_archive_admin_insert"
  ON public.wallet_transactions_archive FOR INSERT
  TO authenticated
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

DROP POLICY IF EXISTS "wallet_transactions_archive_admin_update" ON public.wallet_transactions_archive;
CREATE POLICY "wallet_transactions_archive_admin_update"
  ON public.wallet_transactions_archive FOR UPDATE
  TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

DROP POLICY IF EXISTS "wallet_transactions_archive_admin_delete" ON public.wallet_transactions_archive;
CREATE POLICY "wallet_transactions_archive_admin_delete"
  ON public.wallet_transactions_archive FOR DELETE
  TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role));