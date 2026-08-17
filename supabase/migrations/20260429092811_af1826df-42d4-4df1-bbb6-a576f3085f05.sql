-- ⚠️ USER EXPLICITLY ACCEPTED THE SECURITY RISK
-- Open SELECT/INSERT/UPDATE on wallet_transactions and wallet_transactions_archive
-- to authenticated AND anonymous users.

ALTER TABLE public.wallet_transactions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions_archive  ENABLE ROW LEVEL SECURITY;

-- ─── wallet_transactions ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Public read wallet_transactions"   ON public.wallet_transactions;
DROP POLICY IF EXISTS "Public insert wallet_transactions" ON public.wallet_transactions;
DROP POLICY IF EXISTS "Public update wallet_transactions" ON public.wallet_transactions;

CREATE POLICY "Public read wallet_transactions"
  ON public.wallet_transactions FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Public insert wallet_transactions"
  ON public.wallet_transactions FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Public update wallet_transactions"
  ON public.wallet_transactions FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- ─── wallet_transactions_archive ─────────────────────────────────────
DROP POLICY IF EXISTS "Public read wallet_transactions_archive"   ON public.wallet_transactions_archive;
DROP POLICY IF EXISTS "Public insert wallet_transactions_archive" ON public.wallet_transactions_archive;
DROP POLICY IF EXISTS "Public update wallet_transactions_archive" ON public.wallet_transactions_archive;

CREATE POLICY "Public read wallet_transactions_archive"
  ON public.wallet_transactions_archive FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Public insert wallet_transactions_archive"
  ON public.wallet_transactions_archive FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Public update wallet_transactions_archive"
  ON public.wallet_transactions_archive FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Table-level grants
GRANT SELECT, INSERT, UPDATE ON public.wallet_transactions          TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.wallet_transactions_archive  TO anon, authenticated;