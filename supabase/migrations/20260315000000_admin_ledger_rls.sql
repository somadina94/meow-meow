-- Fix: Allow admins to view all ledger transactions for revenue reporting.
-- Previously only "Users can view their own ledger transactions" existed,
-- which caused the AdminDashboard today's earnings query to always return 0
-- because RLS silently blocked cross-user reads.

CREATE POLICY "Admins can view all ledger transactions"
  ON public.ledger_transactions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );
