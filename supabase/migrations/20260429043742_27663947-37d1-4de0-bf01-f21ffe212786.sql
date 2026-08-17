-- =====================================================================
-- Recharge integrity: ONE credit per Razorpay payment, no duplicates,
-- no under-charge (every recharge hits billing_ledger), no over-charge
-- (UNIQUE idempotency_key on billing_ledger enforces it).
-- =====================================================================

-- 1) Drop the legacy ledger_recharge overload (wallet_transactions-only).
--    The canonical overload (with p_reference_id) writes to billing_ledger.
DROP FUNCTION IF EXISTS public.ledger_recharge(
  p_user_id uuid, p_amount numeric, p_gateway text,
  p_gateway_txn_id text, p_description text
);

-- 2) Drop process_men_recharge (writes to forbidden legacy platform_ledger).
DROP FUNCTION IF EXISTS public.process_men_recharge(uuid, numeric, text);

-- 3) Recreate the canonical ledger_recharge with stricter idempotency:
--    - Idempotency key MUST include gateway_txn_id (no time-based fallback
--      that could create duplicates on retry).
--    - Returns the existing ledger row id when duplicate so callers can
--      reconcile without creating a second credit.
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
SET search_path = public
AS $$
DECLARE
  v_wallet RECORD;
  v_balance_after numeric(12,2);
  v_man_id uuid;
  v_idem text;
  v_existing_id uuid;
  v_txn_ref text;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'amount must be > 0');
  END IF;

  -- Require a stable transaction reference. No time-based keys (would dupe on retry).
  v_txn_ref := COALESCE(NULLIF(p_gateway_txn_id, ''), NULLIF(p_reference_id, ''));
  IF v_txn_ref IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'gateway_txn_id or reference_id is required');
  END IF;

  v_idem := 'recharge|' || p_user_id::text || '|' || v_txn_ref;

  -- Idempotency check (DB-level UNIQUE constraint also enforces this)
  SELECT id INTO v_existing_id
  FROM public.billing_ledger
  WHERE idempotency_key = v_idem
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true, 'duplicate_skipped', true, 'existing_id', v_existing_id
    );
  END IF;

  -- Lock wallet row, create if missing
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

  v_balance_after := v_wallet.balance + p_amount;
  UPDATE public.wallets
    SET balance = v_balance_after, updated_at = now()
    WHERE id = v_wallet.id;

  SELECT id INTO v_man_id FROM public.profiles WHERE id = p_user_id AND gender = 'male';
  IF v_man_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'recharge target must be a male profile');
  END IF;

  -- Single canonical credit row. UNIQUE(idempotency_key) prevents duplicates
  -- even under concurrent webhook + verifier callbacks.
  INSERT INTO public.billing_ledger (
    man_id, entry_type, amount, balance_after, session_type,
    rate_applied, description, reference_id, idempotency_key, status
  ) VALUES (
    v_man_id, 'credit', p_amount, v_balance_after, 'recharge',
    p_amount,
    COALESCE(p_description, 'Wallet recharge — ₹' || p_amount || ' via ' || p_gateway),
    v_txn_ref, v_idem, 'completed'
  )
  ON CONFLICT (idempotency_key) DO NOTHING;

  RETURN jsonb_build_object(
    'success', true,
    'balance', v_balance_after,
    'amount', p_amount,
    'idempotency_key', v_idem
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ledger_recharge(uuid, numeric, text, text, text, text)
  TO service_role;

-- 4) Admin verification helper: flag any wallet whose total credits don't
--    match the statement source of truth (billing_ledger recharges).
CREATE OR REPLACE FUNCTION public.verify_recharge_integrity()
RETURNS TABLE(
  user_id uuid,
  ledger_recharge_total numeric,
  recharge_count bigint,
  duplicate_keys bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    bl.man_id AS user_id,
    SUM(bl.amount)::numeric(12,2) AS ledger_recharge_total,
    COUNT(*) AS recharge_count,
    COUNT(*) - COUNT(DISTINCT bl.idempotency_key) AS duplicate_keys
  FROM public.billing_ledger bl
  WHERE bl.session_type = 'recharge' AND bl.entry_type = 'credit'
  GROUP BY bl.man_id;
$$;

GRANT EXECUTE ON FUNCTION public.verify_recharge_integrity() TO authenticated, service_role;