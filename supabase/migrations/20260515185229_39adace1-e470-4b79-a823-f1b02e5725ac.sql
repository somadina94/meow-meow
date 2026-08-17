
-- 1) Fix trigger function to use the auth user id
CREATE OR REPLACE FUNCTION public.ensure_wallet_exists()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.user_id IS NULL THEN
    RETURN NEW;
  END IF;
  INSERT INTO public.wallets (user_id, balance)
  VALUES (NEW.user_id, 0)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$function$;

-- 2) Backfill: ensure every profile has a wallet keyed by auth user_id
INSERT INTO public.wallets (user_id, balance)
SELECT DISTINCT p.user_id, 0
FROM public.profiles p
WHERE p.user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.wallets w WHERE w.user_id = p.user_id)
ON CONFLICT (user_id) DO NOTHING;

-- 3) Remove orphan wallets that were keyed by profiles.id (the old bug)
--    Only delete if the wallet has no transactions and a correct wallet exists for that profile.
DELETE FROM public.wallets w
USING public.profiles p
WHERE w.user_id = p.id
  AND p.id <> p.user_id
  AND EXISTS (SELECT 1 FROM public.wallets w2 WHERE w2.user_id = p.user_id)
  AND NOT EXISTS (SELECT 1 FROM public.wallet_transactions t WHERE t.wallet_id = w.id)
  AND w.balance = 0;
