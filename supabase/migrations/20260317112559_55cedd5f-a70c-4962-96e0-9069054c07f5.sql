
-- Fix: Ensure users_wallet is a TABLE (not a VIEW) for trigger compatibility
-- Migration 20260314 created it as a VIEW; later migrations require a TABLE.
-- This is idempotent: if already a table, does nothing.

DO $$
BEGIN
  -- Check if users_wallet exists as a VIEW and convert to TABLE
  IF EXISTS (
    SELECT 1 FROM information_schema.views 
    WHERE table_schema = 'public' AND table_name = 'users_wallet'
  ) THEN
    -- Drop the view
    DROP VIEW IF EXISTS public.users_wallet CASCADE;
    
    -- Create as a proper table
    CREATE TABLE public.users_wallet (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL UNIQUE,
      gender text,
      balance numeric NOT NULL DEFAULT 0.00,
      currency text NOT NULL DEFAULT 'INR',
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    -- Enable RLS
    ALTER TABLE public.users_wallet ENABLE ROW LEVEL SECURITY;

    -- RLS: users can see own wallet
    CREATE POLICY "users_wallet_select_own" ON public.users_wallet
      FOR SELECT TO authenticated USING (auth.uid() = user_id);

    -- RLS: admin can see all
    CREATE POLICY "admin_users_wallet_select" ON public.users_wallet
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));

    -- RLS: service/system can insert and update
    CREATE POLICY "users_wallet_system_insert" ON public.users_wallet
      FOR INSERT WITH CHECK (true);
    CREATE POLICY "users_wallet_system_update" ON public.users_wallet
      FOR UPDATE USING (true);

    -- Populate from wallets table
    INSERT INTO public.users_wallet (user_id, balance, currency, gender, created_at, updated_at)
    SELECT user_id, balance, currency,
      CASE WHEN gender = 'male' THEN 'men' WHEN gender = 'female' THEN 'women' ELSE 'men' END,
      created_at, updated_at
    FROM public.wallets
    ON CONFLICT (user_id) DO NOTHING;

    RAISE NOTICE 'Converted users_wallet from VIEW to TABLE';
  ELSE
    RAISE NOTICE 'users_wallet is already a TABLE, no action needed';
  END IF;
END $$;
