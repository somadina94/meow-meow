
-- Fix: Add recursion guards to bidirectional wallet sync triggers
-- Prevents infinite loop: wallets → users_wallet → wallets → ...

CREATE OR REPLACE FUNCTION public.sync_wallets_to_users_wallet()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender text;
BEGIN
  -- Recursion guard: skip if already syncing from the other direction
  IF current_setting('app.syncing_wallet', true) = 'true' THEN
    RETURN NEW;
  END IF;

  PERFORM set_config('app.syncing_wallet', 'true', true);

  v_gender := CASE WHEN NEW.gender = 'male' THEN 'men' WHEN NEW.gender = 'female' THEN 'women' ELSE 'men' END;
  INSERT INTO public.users_wallet (user_id, balance, currency, gender, created_at, updated_at)
  VALUES (NEW.user_id, NEW.balance, NEW.currency, v_gender, NEW.created_at, NEW.updated_at)
  ON CONFLICT (user_id) DO UPDATE SET
    balance = EXCLUDED.balance,
    currency = EXCLUDED.currency,
    gender = EXCLUDED.gender,
    updated_at = EXCLUDED.updated_at;

  PERFORM set_config('app.syncing_wallet', 'false', true);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_users_wallet_to_wallets()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender text;
BEGIN
  -- Recursion guard: skip if already syncing from the other direction
  IF current_setting('app.syncing_wallet', true) = 'true' THEN
    RETURN NEW;
  END IF;

  PERFORM set_config('app.syncing_wallet', 'true', true);

  v_gender := CASE WHEN NEW.gender = 'men' THEN 'male' WHEN NEW.gender = 'women' THEN 'female' ELSE NEW.gender END;
  INSERT INTO public.wallets (user_id, balance, currency, gender, created_at, updated_at)
  VALUES (NEW.user_id, NEW.balance, NEW.currency, v_gender, NEW.created_at, NEW.updated_at)
  ON CONFLICT (user_id) DO UPDATE SET
    balance = EXCLUDED.balance,
    currency = EXCLUDED.currency,
    gender = EXCLUDED.gender,
    updated_at = EXCLUDED.updated_at;

  PERFORM set_config('app.syncing_wallet', 'false', true);
  RETURN NEW;
END;
$$;
