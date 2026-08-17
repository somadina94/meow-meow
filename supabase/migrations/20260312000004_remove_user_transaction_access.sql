-- ============================================================
-- Migration: remove_user_transaction_access
-- Applied: 2026-03-12
-- Purpose:
--   Ensure men and women have NO direct access to their
--   transaction history or statements via RLS.
--   All transaction data remains stored internally.
--   Only admins can access statements via admin_search_statements.
--
-- User-facing wallet pages now show:
--   Men   → balance + recharge only
--   Women → earned balance + withdraw only
-- ============================================================

-- Revoke direct SELECT on wallet_transactions from regular users
-- (keep insert/update for billing engine running as service_role)
DROP POLICY IF EXISTS wallet_transactions_user_select ON public.wallet_transactions;

-- Users can only see their OWN wallet balance via RPC, not raw rows
-- wallet_transactions rows are internal ledger — admin/service_role only for SELECT
DROP POLICY IF EXISTS "Users can view own transactions" ON public.wallet_transactions;
DROP POLICY IF EXISTS "users_view_own_wallet_transactions" ON public.wallet_transactions;

-- Create a strict policy: only service_role and admins can SELECT wallet_transactions
CREATE POLICY wallet_transactions_admin_or_service ON public.wallet_transactions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- women_earnings: same — no direct user SELECT
DROP POLICY IF EXISTS "Users can view own earnings" ON public.women_earnings;
DROP POLICY IF EXISTS "users_view_own_earnings" ON public.women_earnings;
DROP POLICY IF EXISTS women_earnings_user_select ON public.women_earnings;

CREATE POLICY women_earnings_admin_or_service ON public.women_earnings
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- monthly_statements: admin only (already set, re-confirm)
DROP POLICY IF EXISTS monthly_statements_admin_only ON public.monthly_statements;
CREATE POLICY monthly_statements_admin_only ON public.monthly_statements
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- NOTE: get_men_wallet_balance and get_women_wallet_balance RPCs use
-- SECURITY DEFINER so they can still read transaction data to compute
-- the balance totals without exposing raw rows to users.
