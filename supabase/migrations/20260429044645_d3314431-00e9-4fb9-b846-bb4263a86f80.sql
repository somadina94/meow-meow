-- Fix: Razorpay (and any) recharges must land in wallet_transactions (canonical SoT)
-- so they appear in men's wallet balance and statement views.

CREATE OR REPLACE FUNCTION public.ledger_recharge(
  p_user_id uuid,
  p_amount numeric,
  p_reference_id text DEFAULT NULL,
  p_gateway text DEFAULT 'razorpay',
  p_gateway_txn_id text DEFAULT NULL,
  p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_wallet RECORD;
  v_balance_after numeric(12,2);
  v_man_id uuid;
  v_idem text;
  v_existing_id uuid;
  v_txn_ref text;
  v_desc text;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'amount must be > 0');
  END IF;

  v_txn_ref := COALESCE(NULLIF(p_gateway_txn_id, ''), NULLIF(p_reference_id, ''));
  IF v_txn_ref IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'gateway_txn_id or reference_id is required');
  END IF;

  v_idem := 'recharge|' || p_user_id::text || '|' || v_txn_ref;

  -- Idempotency check across BOTH ledgers
  SELECT id INTO v_existing_id FROM public.wallet_transactions
   WHERE idempotency_key = v_idem LIMIT 1;
  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'duplicate_skipped', true, 'existing_id', v_existing_id);
  END IF;

  SELECT id INTO v_existing_id FROM public.billing_ledger
   WHERE idempotency_key = v_idem LIMIT 1;

  -- Lock wallet, create if missing
  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO public.wallets (user_id, gender, balance, currency)
    VALUES (
      p_user_id,
      (SELECT gender FROM public.profiles WHERE id = p_user_id),
      0, 'INR'
    )
    RETURNING * INTO v_wallet;
  END IF;

  SELECT id INTO v_man_id FROM public.profiles WHERE id = p_user_id AND gender = 'male';
  IF v_man_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'recharge target must be a male profile');
  END IF;

  -- Only credit balance if billing_ledger row didn't already apply it
  IF v_existing_id IS NULL THEN
    v_balance_after := v_wallet.balance + p_amount;
    UPDATE public.wallets
       SET balance = v_balance_after, updated_at = now()
     WHERE id = v_wallet.id;
  ELSE
    v_balance_after := v_wallet.balance;
  END IF;

  v_desc := COALESCE(p_description, 'Wallet recharge — ₹' || p_amount || ' via ' || p_gateway);

  -- Canonical billing_ledger entry (idempotent)
  INSERT INTO public.billing_ledger (
    man_id, entry_type, amount, balance_after, session_type,
    rate_applied, description, reference_id, idempotency_key, status
  ) VALUES (
    v_man_id, 'credit', p_amount, v_balance_after, 'recharge',
    p_amount, v_desc, v_txn_ref, v_idem, 'completed'
  )
  ON CONFLICT (idempotency_key) DO NOTHING;

  -- Canonical SoT entry — drives wallet balance & statement UI
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, session_type,
    amount, balance_after, description, reference_id, idempotency_key, status
  ) VALUES (
    v_wallet.id, p_user_id, 'credit', 'recharge', 'wallet',
    p_amount, v_balance_after, v_desc, v_txn_ref, v_idem, 'completed'
  )
  ON CONFLICT (idempotency_key) DO NOTHING;

  RETURN jsonb_build_object(
    'success', true,
    'balance', v_balance_after,
    'amount', p_amount,
    'idempotency_key', v_idem
  );
END;
$function$;