-- ============================================================================
-- ⚠️  RISK-ACCEPTED CHANGE
-- Open wallet_transactions + _archive to ALL authenticated users (any row).
-- Anonymous users remain fully blocked.
-- ============================================================================

-- 1. Drop every existing policy on both tables (clean slate)
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('wallet_transactions', 'wallet_transactions_archive')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
                   pol.policyname, pol.schemaname, pol.tablename);
  END LOOP;
END $$;

-- 2. Keep RLS enabled (required to block anon) and add open policies for authenticated
ALTER TABLE public.wallet_transactions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions_archive  ENABLE ROW LEVEL SECURITY;

-- wallet_transactions: any authenticated user, all rows
CREATE POLICY "auth_open_select_wt"
  ON public.wallet_transactions FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "auth_open_insert_wt"
  ON public.wallet_transactions FOR INSERT
  TO authenticated WITH CHECK (true);

CREATE POLICY "auth_open_update_wt"
  ON public.wallet_transactions FOR UPDATE
  TO authenticated USING (true) WITH CHECK (true);

-- wallet_transactions_archive: any authenticated user, all rows
CREATE POLICY "auth_open_select_wta"
  ON public.wallet_transactions_archive FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "auth_open_insert_wta"
  ON public.wallet_transactions_archive FOR INSERT
  TO authenticated WITH CHECK (true);

CREATE POLICY "auth_open_update_wta"
  ON public.wallet_transactions_archive FOR UPDATE
  TO authenticated USING (true) WITH CHECK (true);

-- 3. Re-affirm table grants (idempotent)
GRANT SELECT, INSERT, UPDATE ON public.wallet_transactions          TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.wallet_transactions_archive  TO authenticated;
REVOKE ALL ON public.wallet_transactions          FROM anon;
REVOKE ALL ON public.wallet_transactions_archive  FROM anon;