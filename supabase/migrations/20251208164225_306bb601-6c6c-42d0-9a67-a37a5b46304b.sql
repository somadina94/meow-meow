-- Reset balance to 0 for all super users
-- Super users don't require balance to use the app (bypass already implemented)

UPDATE public.wallets
SET balance = 0, updated_at = now()
WHERE user_id IN (
  SELECT id FROM auth.users 
  WHERE public.is_super_user(email)
);

-- Also clear any pending wallet transactions for super users
UPDATE public.wallet_transactions
SET status = 'cancelled'
WHERE user_id IN (
  SELECT id FROM auth.users 
  WHERE public.is_super_user(email)
) AND status = 'pending';