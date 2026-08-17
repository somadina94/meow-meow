-- 1) Rewrite process_group_billing_v2 WITHOUT the women_earnings double-write
CREATE OR REPLACE FUNCTION public.process_group_billing_v2(
  p_group_id text,
  p_session_id text,
  p_host_id uuid,
  p_man_ids uuid[],
  p_minutes numeric,
  p_idempotency text DEFAULT NULL::text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_pricing record; v_rate_per_man numeric; v_earn_per_man numeric;
  v_man_id uuid; v_man_wallet_id uuid; v_man_balance numeric;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_total_earned numeric := 0; v_active_count int := 0;
  v_removed_men uuid[] := '{}'; v_idem text; v_idem_man text; v_idem_woman text;
  v_session_uuid uuid;
  v_host_indian boolean := false;
BEGIN
  IF p_idempotency IS NULL OR length(p_idempotency) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'idempotency_key_required');
  END IF;

  SELECT * INTO v_pricing FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  v_rate_per_man := ROUND(p_minutes * COALESCE(v_pricing.group_call_rate_per_minute, 4.00), 2);
  v_earn_per_man := ROUND(p_minutes * COALESCE(v_pricing.group_call_women_earning_rate, 0.50), 2);
  v_idem := p_idempotency;
  v_session_uuid := CASE WHEN p_session_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                         THEN p_session_id::uuid ELSE NULL END;

  SELECT COALESCE(
    (SELECT fp.is_indian FROM public.female_profiles fp WHERE fp.user_id = p_host_id LIMIT 1),
    (SELECT pr.is_indian FROM public.profiles pr WHERE pr.user_id = p_host_id LIMIT 1),
    false
  ) INTO v_host_indian;

  FOREACH v_man_id IN ARRAY p_man_ids LOOP
    v_idem_man := 'pgrp_m:' || v_idem || ':' || v_man_id::text;
    IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_man) THEN
      v_active_count := v_active_count + 1;
      IF v_host_indian THEN v_total_earned := v_total_earned + v_earn_per_man; END IF;
      CONTINUE;
    END IF;

    SELECT id, balance INTO v_man_wallet_id, v_man_balance
    FROM public.wallets WHERE user_id = v_man_id FOR UPDATE;

    IF v_man_wallet_id IS NULL OR COALESCE(v_man_balance, 0) < v_rate_per_man THEN
      v_removed_men := array_append(v_removed_men, v_man_id);
      CONTINUE;
    END IF;

    UPDATE public.wallets SET balance = balance - v_rate_per_man, updated_at = NOW()
     WHERE id = v_man_wallet_id RETURNING balance INTO v_man_balance;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, amount, description, session_id,
      balance_after, idempotency_key, status, duration_seconds, rate_per_minute
    ) VALUES (
      v_man_wallet_id, v_man_id, 'debit', 'private_group_call_charge', v_rate_per_man,
      'Private Group Call: ' || ROUND(p_minutes,2) || ' min @ ₹' || COALESCE(v_pricing.group_call_rate_per_minute,4.00) || '/min',
      v_session_uuid, v_man_balance, v_idem_man, 'completed',
      ROUND(p_minutes*60)::int, COALESCE(v_pricing.group_call_rate_per_minute,4.00)
    );

    v_active_count := v_active_count + 1;
    IF v_host_indian THEN v_total_earned := v_total_earned + v_earn_per_man; END IF;
  END LOOP;

  IF v_host_indian AND v_total_earned > 0 THEN
    v_idem_woman := 'pgrp_w:' || v_idem || ':' || p_host_id::text;
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
    FROM public.wallets WHERE user_id = p_host_id FOR UPDATE;

    IF v_woman_wallet_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_woman) THEN
      UPDATE public.wallets SET balance = balance + v_total_earned, updated_at = NOW()
       WHERE id = v_woman_wallet_id RETURNING balance INTO v_woman_balance;
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description, session_id,
        balance_after, idempotency_key, status, duration_seconds, rate_per_minute
      ) VALUES (
        v_woman_wallet_id, p_host_id, 'credit', 'private_group_call_earning', v_total_earned,
        'Private Group Call Earning: ' || ROUND(p_minutes,2) || ' min × ' || v_active_count || ' men',
        v_session_uuid, v_woman_balance, v_idem_woman, 'completed',
        ROUND(p_minutes*60)::int, COALESCE(v_pricing.group_call_women_earning_rate,0.50)
      );
      -- SoT: women_earnings double-write removed (canonical store is wallet_transactions only)
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'active_count', v_active_count,
    'host_earned', CASE WHEN v_host_indian THEN v_total_earned ELSE 0 END,
    'host_is_indian', v_host_indian,
    'removed_men', v_removed_men);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', true, 'duplicate_skipped', true);
WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;

-- 2) Drop the legacy non-canonical RPC so it can never be invoked again
DROP FUNCTION IF EXISTS public.ledger_bill_group_call(uuid, text, uuid, uuid[], numeric, text);
DROP FUNCTION IF EXISTS public.ledger_bill_group_call(text, text, uuid, uuid[], numeric, text);
DROP FUNCTION IF EXISTS public.ledger_bill_group_call CASCADE;

-- 3) Normalise the 1 legacy pair to canonical naming
UPDATE public.wallet_transactions
   SET transaction_type = 'private_group_call_charge'
 WHERE transaction_type = 'group_call_charge';

UPDATE public.wallet_transactions
   SET transaction_type = 'private_group_call_earning'
 WHERE transaction_type = 'group_call_earning';