-- Ensure live wallet_transactions can use ON CONFLICT(idempotency_key)
CREATE UNIQUE INDEX IF NOT EXISTS ux_wallet_transactions_idempotency_key
ON public.wallet_transactions(idempotency_key);

-- Archive idempotency lookup for old recharge records
CREATE UNIQUE INDEX IF NOT EXISTS ux_wallet_transactions_archive_idempotency_key
ON public.wallet_transactions_archive(idempotency_key);

-- Atomic canonical recharge writer: insert statement row + wallet balance update together.
CREATE OR REPLACE FUNCTION public.ledger_recharge(
  p_user_id uuid,
  p_amount numeric,
  p_gateway text,
  p_gateway_txn_id text DEFAULT NULL::text,
  p_reference_id text DEFAULT NULL::text,
  p_description text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_wallet RECORD;
  v_balance_after numeric(12,2);
  v_idem text;
  v_existing_id uuid;
  v_existing_balance numeric;
  v_txn_ref text;
  v_desc text;
  v_tx_id uuid;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'user_id is required');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'amount must be > 0');
  END IF;

  v_txn_ref := COALESCE(NULLIF(p_gateway_txn_id, ''), NULLIF(p_reference_id, ''));
  IF v_txn_ref IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'gateway_txn_id or reference_id is required');
  END IF;

  v_idem := 'recharge|' || p_user_id::text || '|' || v_txn_ref;

  -- Idempotency across both live and archive.
  SELECT id, balance_after INTO v_existing_id, v_existing_balance
  FROM public.wallet_transactions
  WHERE idempotency_key = v_idem
  LIMIT 1;

  IF v_existing_id IS NULL THEN
    SELECT id, balance_after INTO v_existing_id, v_existing_balance
    FROM public.wallet_transactions_archive
    WHERE idempotency_key = v_idem
    LIMIT 1;
  END IF;

  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'duplicate_skipped', true,
      'existing_id', v_existing_id,
      'balance', COALESCE(v_existing_balance, 0),
      'amount', p_amount,
      'idempotency_key', v_idem
    );
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.wallets (user_id, gender, balance, currency)
    VALUES (
      p_user_id,
      COALESCE((SELECT gender FROM public.profiles WHERE user_id = p_user_id LIMIT 1), 'male'),
      0,
      'INR'
    )
    RETURNING * INTO v_wallet;
  END IF;

  v_balance_after := (COALESCE(v_wallet.balance, 0) + p_amount)::numeric(12,2);
  v_desc := COALESCE(p_description, 'Wallet recharge ₹' || p_amount || ' via ' || COALESCE(p_gateway, 'gateway'));

  -- Insert the statement row first. If this fails, wallet balance is not changed.
  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, session_type,
    amount, balance_after, description, reference_id, idempotency_key, status
  ) VALUES (
    v_wallet.id, p_user_id, 'credit', 'recharge', 'wallet',
    p_amount, v_balance_after, v_desc, v_txn_ref, v_idem, 'completed'
  )
  RETURNING id INTO v_tx_id;

  UPDATE public.wallets
  SET balance = v_balance_after, updated_at = now()
  WHERE id = v_wallet.id;

  RETURN jsonb_build_object(
    'success', true,
    'balance', v_balance_after,
    'amount', p_amount,
    'transaction_id', v_tx_id,
    'idempotency_key', v_idem
  );
EXCEPTION WHEN unique_violation THEN
  -- Race-safe duplicate handling.
  SELECT id, balance_after INTO v_existing_id, v_existing_balance
  FROM public.wallet_transactions
  WHERE idempotency_key = v_idem
  LIMIT 1;

  RETURN jsonb_build_object(
    'success', true,
    'duplicate_skipped', true,
    'existing_id', v_existing_id,
    'balance', COALESCE(v_existing_balance, 0),
    'amount', p_amount,
    'idempotency_key', v_idem
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.ledger_recharge(uuid,numeric,text,text,text,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.ledger_recharge(uuid,numeric,text,text,text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_ledger_statement(uuid,text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_men_wallet_balance(uuid) TO authenticated, service_role;