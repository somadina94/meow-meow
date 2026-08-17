
-- Add golden badge fields to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS has_golden_badge boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS golden_badge_expires_at timestamp with time zone;

-- Add golden badge fields to female_profiles table
ALTER TABLE public.female_profiles
ADD COLUMN IF NOT EXISTS has_golden_badge boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS golden_badge_expires_at timestamp with time zone;

-- Create golden badge subscriptions table
CREATE TABLE public.golden_badge_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  amount numeric NOT NULL DEFAULT 1000,
  currency text NOT NULL DEFAULT 'INR',
  status text NOT NULL DEFAULT 'active',
  purchased_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL DEFAULT (now() + interval '30 days'),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.golden_badge_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own subscriptions"
ON public.golden_badge_subscriptions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own subscriptions"
ON public.golden_badge_subscriptions FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Function to purchase golden badge
CREATE OR REPLACE FUNCTION public.purchase_golden_badge(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_wallet_id uuid;
  v_balance numeric;
  v_badge_price numeric := 1000;
  v_expires_at timestamp with time zone;
  v_is_indian boolean;
  v_gender text;
  v_existing_badge boolean;
BEGIN
  -- Verify user is an Indian woman
  SELECT gender, is_indian, has_golden_badge
  INTO v_gender, v_is_indian, v_existing_badge
  FROM profiles WHERE user_id = p_user_id;

  IF LOWER(COALESCE(v_gender, '')) != 'female' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Golden Badge is only available for women');
  END IF;

  IF NOT COALESCE(v_is_indian, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Golden Badge is only available for Indian women');
  END IF;

  -- Check if already has active badge
  IF COALESCE(v_existing_badge, false) THEN
    -- Check if it's still valid
    IF EXISTS (
      SELECT 1 FROM profiles 
      WHERE user_id = p_user_id 
      AND golden_badge_expires_at > now()
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'You already have an active Golden Badge');
    END IF;
  END IF;

  -- Lock wallet
  SELECT id, balance INTO v_wallet_id, v_balance
  FROM wallets WHERE user_id = p_user_id FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF v_balance < v_badge_price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance. You need ₹1000');
  END IF;

  -- Set expiry to 30 days from now
  v_expires_at := now() + interval '30 days';

  -- Debit wallet
  UPDATE wallets SET balance = balance - v_badge_price, updated_at = now() WHERE id = v_wallet_id;

  INSERT INTO wallet_transactions (wallet_id, user_id, type, amount, description, status)
  VALUES (v_wallet_id, p_user_id, 'debit', v_badge_price, 'Golden Badge Purchase (1 Month)', 'completed');

  -- Update profiles
  UPDATE profiles 
  SET has_golden_badge = true, golden_badge_expires_at = v_expires_at, updated_at = now()
  WHERE user_id = p_user_id;

  UPDATE female_profiles
  SET has_golden_badge = true, golden_badge_expires_at = v_expires_at, updated_at = now()
  WHERE user_id = p_user_id;

  -- Record subscription
  INSERT INTO golden_badge_subscriptions (user_id, amount, expires_at)
  VALUES (p_user_id, v_badge_price, v_expires_at);

  -- Log admin revenue
  INSERT INTO admin_revenue_transactions (transaction_type, amount, woman_user_id, description, currency)
  VALUES ('golden_badge', v_badge_price, p_user_id, 'Golden Badge purchase', 'INR');

  RETURN jsonb_build_object(
    'success', true,
    'expires_at', v_expires_at,
    'new_balance', v_balance - v_badge_price
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Update sync trigger to include golden badge fields
CREATE OR REPLACE FUNCTION public.sync_golden_badge_to_female()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.has_golden_badge IS DISTINCT FROM OLD.has_golden_badge 
     OR NEW.golden_badge_expires_at IS DISTINCT FROM OLD.golden_badge_expires_at THEN
    UPDATE female_profiles
    SET has_golden_badge = NEW.has_golden_badge,
        golden_badge_expires_at = NEW.golden_badge_expires_at,
        updated_at = now()
    WHERE user_id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER sync_golden_badge_trigger
AFTER UPDATE OF has_golden_badge, golden_badge_expires_at ON profiles
FOR EACH ROW
EXECUTE FUNCTION sync_golden_badge_to_female();
