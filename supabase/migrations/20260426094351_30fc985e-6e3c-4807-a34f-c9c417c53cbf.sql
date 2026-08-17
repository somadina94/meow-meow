-- Rewrite process_video_billing_v2 to canonical SoT (wallet_transactions)
CREATE OR REPLACE FUNCTION public.process_video_billing_v2(
  p_session_id text, p_man_id uuid, p_woman_id uuid, p_minutes numeric, p_idempotency text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_pricing record; v_man_charge numeric; v_woman_earn numeric;
  v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_idem text; v_idem_w text; v_session_uuid uuid;
BEGIN
  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_man_charge := ROUND(p_minutes * COALESCE(v_pricing.video_rate_per_minute, 8.00), 2);
  v_woman_earn := ROUND(p_minutes * COALESCE(v_pricing.video_women_earning_rate, 4.00), 2);
  v_idem   := COALESCE(p_idempotency, 'video:' || p_session_id || ':' || ROUND(p_minutes,4)::text);
  v_idem_w := v_idem || ':earn';
  v_session_uuid := CASE WHEN p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN p_session_id::uuid ELSE NULL END;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success', false, 'error', 'duplicate_skipped'); END IF;

  SELECT id, balance INTO v_man_wallet_id, v_man_balance FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
  IF COALESCE(v_man_balance, 0) < v_man_charge THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance', 'session_ended', true); END IF;

  UPDATE public.wallets SET balance = balance - v_man_charge, updated_at = NOW()
  WHERE id = v_man_wallet_id RETURNING balance INTO v_man_balance;

  INSERT INTO public.wallet_transactions (
    wallet_id, user_id, type, transaction_type, amount, description, session_id,
    balance_after, idempotency_key, status, duration_seconds, rate_per_minute
  ) VALUES (
    v_man_wallet_id, p_man_id, 'debit', 'video_call_charge', v_man_charge,
    'Video Call: ' || ROUND(p_minutes,1) || ' min @ ₹' || COALESCE(v_pricing.video_rate_per_minute,8.00) || '/min',
    v_session_uuid, v_man_balance, v_idem, 'completed',
    ROUND(p_minutes*60)::int, COALESCE(v_pricing.video_rate_per_minute,8.00)
  );

  SELECT id, balance INTO v_woman_wallet_id, v_woman_balance FROM public.wallets WHERE user_id = p_woman_id FOR UPDATE;
  IF v_woman_wallet_id IS NOT NULL AND v_woman_earn > 0 THEN
    UPDATE public.wallets SET balance = balance + v_woman_earn, updated_at = NOW()
    WHERE id = v_woman_wallet_id RETURNING balance INTO v_woman_balance;
    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, amount, description, session_id,
      balance_after, idempotency_key, status, duration_seconds, rate_per_minute
    ) VALUES (
      v_woman_wallet_id, p_woman_id, 'credit', 'video_call_earning', v_woman_earn,
      'Video Call Earning: ' || ROUND(p_minutes,1) || ' min @ ₹' || COALESCE(v_pricing.video_women_earning_rate,4.00) || '/min',
      v_session_uuid, v_woman_balance, v_idem_w, 'completed',
      ROUND(p_minutes*60)::int, COALESCE(v_pricing.video_women_earning_rate,4.00)
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'man_charged', v_man_charge, 'woman_earned', v_woman_earn);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END; $function$;

-- Final reconcile after this rewrite
UPDATE public.wallets w
SET balance = COALESCE(c.computed, 0), updated_at = now()
FROM (
  SELECT user_id,
         SUM(CASE WHEN type='credit' THEN amount ELSE -amount END) AS computed
  FROM public.wallet_transactions
  WHERE status = 'completed'
  GROUP BY user_id
) c
WHERE w.user_id = c.user_id;