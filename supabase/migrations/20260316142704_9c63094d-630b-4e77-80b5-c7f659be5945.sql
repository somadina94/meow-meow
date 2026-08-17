-- Fix: Sync wallets → users_wallet with gender mapping
-- wallets uses 'male'/'female', users_wallet requires 'men'/'women'

-- Step 1: One-time sync with gender mapping
INSERT INTO public.users_wallet (user_id, balance, currency, gender, created_at, updated_at)
SELECT w.user_id, w.balance, w.currency,
  CASE WHEN w.gender = 'male' THEN 'men' WHEN w.gender = 'female' THEN 'women' ELSE 'men' END,
  w.created_at, w.updated_at
FROM public.wallets w
ON CONFLICT (user_id) DO UPDATE SET
  balance = EXCLUDED.balance,
  currency = EXCLUDED.currency,
  gender = EXCLUDED.gender,
  updated_at = EXCLUDED.updated_at;

-- Step 2: Create trigger function wallets → users_wallet
CREATE OR REPLACE FUNCTION public.sync_wallets_to_users_wallet()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender text;
BEGIN
  v_gender := CASE WHEN NEW.gender = 'male' THEN 'men' WHEN NEW.gender = 'female' THEN 'women' ELSE 'men' END;
  INSERT INTO public.users_wallet (user_id, balance, currency, gender, created_at, updated_at)
  VALUES (NEW.user_id, NEW.balance, NEW.currency, v_gender, NEW.created_at, NEW.updated_at)
  ON CONFLICT (user_id) DO UPDATE SET
    balance = EXCLUDED.balance,
    currency = EXCLUDED.currency,
    gender = EXCLUDED.gender,
    updated_at = EXCLUDED.updated_at;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_wallets_to_users_wallet ON public.wallets;
CREATE TRIGGER trg_sync_wallets_to_users_wallet
  AFTER INSERT OR UPDATE ON public.wallets
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_wallets_to_users_wallet();

-- Step 3: Create reverse sync trigger users_wallet → wallets
CREATE OR REPLACE FUNCTION public.sync_users_wallet_to_wallets()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender text;
BEGIN
  v_gender := CASE WHEN NEW.gender = 'men' THEN 'male' WHEN NEW.gender = 'women' THEN 'female' ELSE NEW.gender END;
  INSERT INTO public.wallets (user_id, balance, currency, gender, created_at, updated_at)
  VALUES (NEW.user_id, NEW.balance, NEW.currency, v_gender, NEW.created_at, NEW.updated_at)
  ON CONFLICT (user_id) DO UPDATE SET
    balance = EXCLUDED.balance,
    currency = EXCLUDED.currency,
    gender = EXCLUDED.gender,
    updated_at = EXCLUDED.updated_at;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_users_wallet_to_wallets ON public.users_wallet;
CREATE TRIGGER trg_sync_users_wallet_to_wallets
  AFTER INSERT OR UPDATE ON public.users_wallet
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_users_wallet_to_wallets();