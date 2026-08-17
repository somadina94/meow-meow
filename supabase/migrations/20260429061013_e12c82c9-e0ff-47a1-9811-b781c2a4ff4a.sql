-- ============================================================
-- Enforce Section 7 RLS matrix from billing/wallet spec
-- Men/women: NO direct access to ledger tables.
-- Admin + service_role: FULL access. Users read via SECURITY DEFINER RPCs.
-- ============================================================

-- wallet_transactions: drop all user-facing policies
DROP POLICY IF EXISTS "Users can view their own transactions" ON public.wallet_transactions;
DROP POLICY IF EXISTS "Users can insert their own transactions" ON public.wallet_transactions;

-- Consolidate admin policies (idempotent)
DROP POLICY IF EXISTS "admin_wallet_transactions_select" ON public.wallet_transactions;
DROP POLICY IF EXISTS "wallet_transactions_admin_or_service" ON public.wallet_transactions;
DROP POLICY IF EXISTS "wallet_transactions_admin_select" ON public.wallet_transactions;
CREATE POLICY "wallet_transactions_admin_select"
  ON public.wallet_transactions FOR SELECT
  TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role));

-- Service role full access
DROP POLICY IF EXISTS "wallet_transactions_service_all" ON public.wallet_transactions;
CREATE POLICY "wallet_transactions_service_all"
  ON public.wallet_transactions FOR ALL
  TO public
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- (admin INSERT/UPDATE/DELETE policies created earlier remain in place)

-- ------------------------------------------------------------
-- wallet_transactions_archive: drop user-facing SELECT
DROP POLICY IF EXISTS "Users view own archived transactions" ON public.wallet_transactions_archive;

DROP POLICY IF EXISTS "wallet_transactions_archive_admin_select" ON public.wallet_transactions_archive;
CREATE POLICY "wallet_transactions_archive_admin_select"
  ON public.wallet_transactions_archive FOR SELECT
  TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role));

-- Service role policy already exists ("Service role manages archive")

-- ------------------------------------------------------------
-- women_payout_snapshots: drop women-facing SELECT (admin-only per spec)
DROP POLICY IF EXISTS "Women view own snapshots" ON public.women_payout_snapshots;
-- "Admin manages snapshots" remains