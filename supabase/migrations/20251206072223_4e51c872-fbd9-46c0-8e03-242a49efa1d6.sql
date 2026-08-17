-- Allow admins to view all wallets and transactions for finance dashboard
CREATE POLICY "Admins can view all wallets"
ON public.wallets
FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can view all wallet transactions"
ON public.wallet_transactions
FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON public.wallet_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gift_transactions_created_at ON public.gift_transactions(created_at DESC);