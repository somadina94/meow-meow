CREATE OR REPLACE FUNCTION public.bill_session_minute(
  p_session_id uuid,
  p_session_type text,
  p_minutes numeric,
  p_man_id uuid,
  p_woman_id uuid,
  p_man_count integer DEFAULT 1,
  p_minute_index integer DEFAULT NULL::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pricing jsonb;
  v_man_wallet RECORD;
  v_woman_wallet RECORD;
  v_man_id uuid := public.resolve_wallet_user_id(p_man_id);
  v_woman_id uuid := public.resolve_wallet_user_id(p_woman_id);
  v_man_rate numeric(10,2);
  v_woman_rate numeric(10,2);
  v_charge numeric(10,2);
  v_earn numeric(10,2);
  v_man_balance_after numeric(10,2);
  v_woman_balance_after numeric(10,2);
  v_idem_key text;
  v_idem_earn text;
  v_is_super boolean := false;
  v_minute_idx integer;
  v_label text;
  v_caller uuid := auth.uid();
  v_is_live_group_host boolean := false;
BEGIN
  IF p_session_type NOT IN ('chat','audio_call','video_call','private_group_call') THEN
    RETURN jsonb_build_object('success',false,'error','Invalid session_type');
  END IF;

  IF p_minutes <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','minutes must be > 0');
  END IF;

  IF v_man_id IS NULL OR v_woman_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','Missing billing user');
  END IF;

  IF p_session_type = 'private_group_call' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.group_active_hosts gah
      WHERE gah.host_id = v_woman_id
        AND gah.stream_id = p_session_id::text
        AND gah.is_active = true
        AND gah.last_heartbeat_at > now() - interval '2 minutes'
    ) INTO v_is_live_group_host;
  END IF;

  IF auth.role() <> 'service_role'
     AND v_caller IS DISTINCT FROM v_man_id
     AND NOT (p_session_type = 'private_group_call' AND v_caller IS NOT DISTINCT FROM v_woman_id AND v_is_live_group_host)
     AND NOT public.has_role(v_caller, 'admin') THEN
    RETURN jsonb_build_object('success',false,'error','Not allowed to bill for this user');
  END IF;

  v_minute_idx := COALESCE(p_minute_index, FLOOR(EXTRACT(EPOCH FROM date_trunc('minute', now())) / 60)::integer);
  v_idem_key  := 'session|' || p_session_id::text || '|' || p_session_type || '|' || v_man_id::text || '|' || v_minute_idx::text;
  v_idem_earn := 'session_earn|' || p_session_id::text || '|' || p_session_type || '|' || v_woman_id::text || '|' || v_man_id::text || '|' || v_minute_idx::text;

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_key)
     OR EXISTS (SELECT 1 FROM public.wallet_transactions_archive WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
  END IF;

  v_pricing := public.get_unified_pricing();
  v_man_rate := CASE p_session_type
    WHEN 'chat' THEN (v_pricing->>'chat_man_rate')::numeric
    WHEN 'audio_call' THEN (v_pricing->>'audio_man_rate')::numeric
    WHEN 'video_call' THEN (v_pricing->>'video_man_rate')::numeric
    WHEN 'private_group_call' THEN (v_pricing->>'group_man_rate')::numeric
  END;
  v_woman_rate := CASE p_session_type
    WHEN 'chat' THEN (v_pricing->>'chat_woman_rate')::numeric
    WHEN 'audio_call' THEN (v_pricing->>'audio_woman_rate')::numeric
    WHEN 'video_call' THEN (v_pricing->>'video_woman_rate')::numeric
    WHEN 'private_group_call' THEN (v_pricing->>'group_woman_rate')::numeric
  END;

  v_charge := ROUND(v_man_rate * p_minutes, 2);
  v_earn   := ROUND(v_woman_rate * p_minutes * GREATEST(p_man_count,1), 2);
  v_label  := CASE p_session_type
    WHEN 'chat' THEN 'Chat'
    WHEN 'audio_call' THEN 'Audio Call'
    WHEN 'video_call' THEN 'Video Call'
    WHEN 'private_group_call' THEN 'Group Call'
  END;

  SELECT public.has_role(v_man_id, 'admin') INTO v_is_super;

  IF NOT v_is_super THEN
    SELECT * INTO v_man_wallet FROM public.wallets WHERE user_id = v_man_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success',false,'error','Wallet not found');
    END IF;

    IF v_man_wallet.balance < v_charge THEN
      RETURN jsonb_build_object('success',false,'error','Insufficient balance','balance',v_man_wallet.balance,'required',v_charge);
    END IF;

    v_man_balance_after := v_man_wallet.balance - v_charge;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type, session_id,
      amount, balance_after, duration_seconds, rate_per_minute,
      description, idempotency_key, status
    ) VALUES (
      v_man_wallet.id, v_man_id, 'debit', 'session_charge', p_session_type, p_session_id,
      v_charge, v_man_balance_after, ROUND(p_minutes * 60)::int, v_man_rate,
      v_label || ' — ' || p_minutes || ' min @ ₹' || v_man_rate || '/min',
      v_idem_key, 'completed'
    );

    UPDATE public.wallets SET balance = v_man_balance_after, updated_at = now() WHERE id = v_man_wallet.id;
  END IF;

  IF v_earn > 0 THEN
    SELECT * INTO v_woman_wallet FROM public.wallets WHERE user_id = v_woman_id FOR UPDATE;
    IF NOT FOUND THEN
      INSERT INTO public.wallets (user_id, gender, balance, currency)
      VALUES (v_woman_id, 'female', 0, 'INR')
      RETURNING * INTO v_woman_wallet;
    END IF;

    v_woman_balance_after := v_woman_wallet.balance + v_earn;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type, session_id,
      amount, balance_after, duration_seconds, rate_per_minute,
      description, idempotency_key, status
    ) VALUES (
      v_woman_wallet.id, v_woman_id, 'credit', 'session_earning', p_session_type, p_session_id,
      v_earn, v_woman_balance_after, ROUND(p_minutes * 60)::int, v_woman_rate,
      v_label || ' earnings — ' || p_minutes || ' min @ ₹' || v_woman_rate || '/min',
      v_idem_earn, 'completed'
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    UPDATE public.wallets SET balance = v_woman_balance_after, updated_at = now() WHERE id = v_woman_wallet.id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'session_type', p_session_type,
    'charged', CASE WHEN v_is_super THEN 0 ELSE v_charge END,
    'earned', v_earn,
    'man_rate', v_man_rate,
    'woman_rate', v_woman_rate,
    'minutes', p_minutes,
    'super_user_skip', v_is_super,
    'minute_index', v_minute_idx
  );
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.bill_session_minute(uuid, text, numeric, uuid, uuid, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bill_session_minute(uuid, text, numeric, uuid, uuid, integer, integer) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';