-- ============================================================
-- Migration: Fix error handling in RPC functions + add indexes
-- Date: 2026-03-12
-- Description:
--   1. Improve error messages in RPC functions to be user-friendly
--   2. Add missing performance indexes
--   3. Fix NULL handling in critical billing functions
--   4. Add missing constraint checks
-- ============================================================

-- ─── 1. Improve error messages in process_wallet_transaction ──────────────────
CREATE OR REPLACE FUNCTION public.process_wallet_transaction(
  p_user_id uuid,
  p_amount numeric,
  p_type text,
  p_description text DEFAULT NULL,
  p_reference_id uuid DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet RECORD;
  v_transaction_id uuid;
  v_new_balance numeric;
BEGIN
  -- Validate inputs
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User ID is required');
  END IF;

  IF p_amount IS NULL OR p_amount = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Transaction amount must be greater than zero');
  END IF;

  IF p_type IS NULL OR p_type NOT IN ('credit', 'debit', 'recharge', 'withdrawal', 'refund') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid transaction type');
  END IF;

  -- Idempotency check
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id
    FROM public.wallet_transactions
    WHERE idempotency_key = p_idempotency_key
    LIMIT 1;

    IF FOUND THEN
      SELECT balance INTO v_new_balance FROM public.wallets WHERE user_id = p_user_id;
      RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_transaction_id,
        'duplicate_skipped', true,
        'new_balance', v_new_balance
      );
    END IF;
  END IF;

  -- Lock wallet row
  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Wallet not found. Please contact support.');
  END IF;

  -- Balance check for debits
  IF p_type IN ('debit', 'withdrawal') AND v_wallet.balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Your wallet balance is too low for this transaction. Please top up and try again.',
      'error_code', 'insufficient_balance',
      'current_balance', v_wallet.balance,
      'required_amount', p_amount
    );
  END IF;

  -- Update balance
  IF p_type IN ('credit', 'recharge', 'refund') THEN
    v_new_balance := v_wallet.balance + p_amount;
  ELSE
    v_new_balance := v_wallet.balance - p_amount;
  END IF;

  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE user_id = p_user_id;

  -- Record transaction
  INSERT INTO public.wallet_transactions (
    user_id, amount, transaction_type, description, reference_id, idempotency_key,
    balance_after, created_at
  ) VALUES (
    p_user_id, p_amount, p_type,
    COALESCE(p_description, p_type || ' of ₹' || p_amount),
    p_reference_id, p_idempotency_key, v_new_balance, now()
  )
  RETURNING id INTO v_transaction_id;

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'new_balance', v_new_balance,
    'previous_balance', v_wallet.balance
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'An unexpected error occurred while processing your transaction. Please try again.',
      'error_code', SQLSTATE
    );
END;
$$;

-- ─── 2. Fix NULL handling in get_top_earner_today ─────────────────────────────
CREATE OR REPLACE FUNCTION public.get_top_earner_today()
RETURNS TABLE(user_id uuid, full_name text, total_amount numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
    SELECT
      we.user_id,
      COALESCE(p.full_name, 'Anonymous') AS full_name,
      COALESCE(SUM(we.amount), 0) AS total_amount
    FROM public.women_earnings we
    LEFT JOIN public.profiles p ON p.id = we.user_id
    WHERE we.created_at >= CURRENT_DATE
      AND we.earning_type IN ('chat', 'video', 'group_call', 'tip')
    GROUP BY we.user_id, p.full_name
    ORDER BY total_amount DESC
    LIMIT 1;
EXCEPTION
  WHEN OTHERS THEN
    -- Return empty result on error rather than crashing caller
    RETURN;
END;
$$;

-- ─── 3. Add missing performance indexes ───────────────────────────────────────

-- Profiles lookup by gender (used in matching, dashboard)
CREATE INDEX IF NOT EXISTS idx_profiles_gender
  ON public.profiles(gender)
  WHERE gender IS NOT NULL;

-- Profiles lookup by approval_status (admin, women dashboard)
CREATE INDEX IF NOT EXISTS idx_profiles_approval_status
  ON public.profiles(approval_status)
  WHERE approval_status IS NOT NULL;

-- Active chat sessions by user (chat screen loads)
CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_man_user
  ON public.active_chat_sessions(man_user_id)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_woman_user
  ON public.active_chat_sessions(woman_user_id)
  WHERE status = 'active';

-- User status for online/offline checks (matching, dashboard)
CREATE INDEX IF NOT EXISTS idx_user_status_user_id_online
  ON public.user_status(user_id, is_online);

-- Wallet transactions user+type lookup (wallet history screen)
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_type
  ON public.wallet_transactions(user_id, transaction_type, created_at DESC);

-- Women earnings by date (leaderboard, stats)
CREATE INDEX IF NOT EXISTS idx_women_earnings_created_at
  ON public.women_earnings(created_at DESC);

-- KYC submissions status (admin KYC review)
CREATE INDEX IF NOT EXISTS idx_kyc_submissions_status
  ON public.kyc_submissions(status)
  WHERE status IS NOT NULL;

-- User roles lookup (auth checks)
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id_role
  ON public.user_roles(user_id, role);

-- Notifications by user (inbox)
CREATE INDEX IF NOT EXISTS idx_notifications_user_id_read
  ON public.notifications(user_id, is_read, created_at DESC)
  WHERE is_read = false;

-- ─── 4. Fix check_session_balance to return friendly error messages ────────────
CREATE OR REPLACE FUNCTION public.check_session_balance(
  p_session_id uuid,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet RECORD;
  v_pricing RECORD;
  v_min_balance numeric;
BEGIN
  IF p_user_id IS NULL OR p_session_id IS NULL THEN
    RETURN jsonb_build_object('has_balance', false, 'error', 'Invalid session parameters');
  END IF;

  SELECT balance INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'has_balance', false,
      'balance', 0,
      'error', 'Wallet not found. Please contact support.'
    );
  END IF;

  -- Get active pricing for minimum balance check
  SELECT * INTO v_pricing
  FROM public.chat_pricing
  WHERE is_active = true
  ORDER BY updated_at DESC
  LIMIT 1;

  v_min_balance := CASE WHEN v_pricing IS NOT NULL THEN v_pricing.men_rate_per_min ELSE 2 END;

  RETURN jsonb_build_object(
    'has_balance', v_wallet.balance >= v_min_balance,
    'balance', v_wallet.balance,
    'min_required', v_min_balance
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'has_balance', false,
      'error', 'Unable to check balance. Please refresh and try again.'
    );
END;
$$;

-- ─── 5. Ensure wallets row always exists when profiles row exists ──────────────
CREATE OR REPLACE FUNCTION public.ensure_wallet_exists()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.wallets (user_id, balance)
  VALUES (NEW.id, 0)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_ensure_wallet_exists ON public.profiles;
CREATE TRIGGER trigger_ensure_wallet_exists
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_wallet_exists();

-- ─── 6. Grant execute permissions on new/updated functions ────────────────────
GRANT EXECUTE ON FUNCTION public.get_top_earner_today() TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_session_balance(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_wallet_transaction(uuid, numeric, text, text, uuid, text) TO authenticated;

