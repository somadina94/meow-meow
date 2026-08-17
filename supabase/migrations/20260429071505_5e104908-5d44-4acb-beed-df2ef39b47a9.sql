-- 1) Allow private_group_call as a session_type label
ALTER TABLE public.wallet_transactions
  DROP CONSTRAINT IF EXISTS wallet_transactions_session_type_check;

ALTER TABLE public.wallet_transactions
  ADD CONSTRAINT wallet_transactions_session_type_check
  CHECK (
    session_type IS NULL OR session_type = ANY (ARRAY[
      'chat','audio_call','video_call','private_group_call',
      'group_call','private_call','group','gift','tip',
      'wallet','video','admin','withdrawal','payout'
    ]::text[])
  );

-- 2) bill_session_minute — use guard-allowed transaction_type values
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
SET search_path TO 'public'
AS $function$
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
  v_is_admin boolean := false;
  v_minute_idx integer;
  v_label text;
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

  IF auth.uid() IS NOT NULL
     AND auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_man_id
     AND NOT public.has_role(auth.uid(), 'admin') THEN
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
  v_label  := initcap(replace(p_session_type,'_',' '));

  SELECT public.has_role(v_man_id, 'admin') INTO v_is_admin;

  IF NOT v_is_admin THEN
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

  RETURN jsonb_build_object('success',true,'session_type',p_session_type,'charged',CASE WHEN v_is_admin THEN 0 ELSE v_charge END,'earned',v_earn,'man_rate',v_man_rate,'woman_rate',v_woman_rate,'minutes',p_minutes,'admin_skip',v_is_admin,'minute_index',v_minute_idx);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
END;
$function$;

-- 3) bill_gift_or_tip — use guard-allowed transaction_type values
CREATE OR REPLACE FUNCTION public.bill_gift_or_tip(
  p_man_id uuid,
  p_woman_id uuid,
  p_amount numeric,
  p_type text,
  p_description text DEFAULT NULL::text,
  p_reference_id text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_pricing jsonb;
  v_man_wallet RECORD;
  v_woman_wallet RECORD;
  v_man_id uuid := public.resolve_wallet_user_id(p_man_id);
  v_woman_id uuid := public.resolve_wallet_user_id(p_woman_id);
  v_pct numeric(5,2);
  v_woman_credit numeric(10,2);
  v_man_balance_after numeric(10,2);
  v_woman_balance_after numeric(10,2);
  v_is_admin boolean := false;
  v_idem_man text;
  v_idem_woman text;
  v_ref text;
  v_charge_type text;
  v_earning_type text;
BEGIN
  IF p_type NOT IN ('gift','tip') THEN
    RETURN jsonb_build_object('success',false,'error','type must be gift or tip');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','amount must be > 0');
  END IF;
  IF v_man_id IS NULL OR v_woman_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','Missing billing user');
  END IF;

  IF auth.uid() IS NOT NULL
     AND auth.role() <> 'service_role'
     AND auth.uid() IS DISTINCT FROM v_man_id
     AND NOT public.has_role(auth.uid(), 'admin') THEN
    RETURN jsonb_build_object('success',false,'error','Not allowed to bill for this user');
  END IF;

  v_ref := COALESCE(NULLIF(p_reference_id, ''), gen_random_uuid()::text);
  v_idem_man   := p_type || '|' || v_man_id::text || '|' || v_woman_id::text || '|' || v_ref;
  v_idem_woman := p_type || '_earn|' || v_woman_id::text || '|' || v_man_id::text || '|' || v_ref;
  v_charge_type  := p_type || '_charge';
  v_earning_type := p_type || '_earning';

  IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_man)
     OR EXISTS (SELECT 1 FROM public.wallet_transactions_archive WHERE idempotency_key = v_idem_man) THEN
    RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
  END IF;

  v_pricing := public.get_unified_pricing();
  v_pct := CASE p_type WHEN 'gift' THEN (v_pricing->>'gift_woman_pct')::numeric ELSE (v_pricing->>'tip_woman_pct')::numeric END;
  v_woman_credit := ROUND(p_amount * v_pct / 100.0, 2);

  SELECT public.has_role(v_man_id, 'admin') INTO v_is_admin;

  IF NOT v_is_admin THEN
    SELECT * INTO v_man_wallet FROM public.wallets WHERE user_id = v_man_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success',false,'error','Wallet not found');
    END IF;
    IF v_man_wallet.balance < p_amount THEN
      RETURN jsonb_build_object('success',false,'error','Insufficient balance','balance',v_man_wallet.balance,'required',p_amount);
    END IF;
    v_man_balance_after := v_man_wallet.balance - p_amount;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type,
      amount, balance_after, description, reference_id, idempotency_key, status
    ) VALUES (
      v_man_wallet.id, v_man_id, 'debit', v_charge_type, p_type,
      p_amount, v_man_balance_after,
      COALESCE(p_description, initcap(p_type) || ' sent — ₹' || p_amount),
      v_ref, v_idem_man, 'completed'
    );

    UPDATE public.wallets SET balance = v_man_balance_after, updated_at = now() WHERE id = v_man_wallet.id;
  END IF;

  IF v_woman_credit > 0 THEN
    SELECT * INTO v_woman_wallet FROM public.wallets WHERE user_id = v_woman_id FOR UPDATE;
    IF NOT FOUND THEN
      INSERT INTO public.wallets (user_id, gender, balance, currency)
      VALUES (v_woman_id, 'female', 0, 'INR')
      RETURNING * INTO v_woman_wallet;
    END IF;
    v_woman_balance_after := v_woman_wallet.balance + v_woman_credit;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, session_type,
      amount, balance_after, description, reference_id, idempotency_key, status
    ) VALUES (
      v_woman_wallet.id, v_woman_id, 'credit', v_earning_type, p_type,
      v_woman_credit, v_woman_balance_after,
      COALESCE(p_description, initcap(p_type) || ' received — ' || v_pct || '% of ₹' || p_amount),
      v_ref, v_idem_woman, 'completed'
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    UPDATE public.wallets SET balance = v_woman_balance_after, updated_at = now() WHERE id = v_woman_wallet.id;
  END IF;

  RETURN jsonb_build_object('success',true,'type',p_type,'charged',CASE WHEN v_is_admin THEN 0 ELSE p_amount END,'woman_credit',v_woman_credit,'woman_pct',v_pct,'idempotency_key',v_idem_man);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.bill_session_minute(uuid, text, numeric, uuid, uuid, integer, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bill_gift_or_tip(uuid, uuid, numeric, text, text, text) TO authenticated, service_role;

-- 4) Chat-end safety net: if no minute heartbeat ran, post final bill on session end
CREATE OR REPLACE FUNCTION public.trg_chat_session_ended()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_minutes numeric;
  v_result jsonb;
BEGIN
  IF NEW.status IN ('ended','declined') AND OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM public.revert_busy_to_online(NEW.man_user_id);
    PERFORM public.revert_busy_to_online(NEW.woman_user_id);

    IF NEW.status = 'ended'
       AND NOT EXISTS (
         SELECT 1 FROM public.wallet_transactions wt
         WHERE wt.session_id = NEW.id AND wt.session_type = 'chat'
       )
       AND NEW.started_at IS NOT NULL
       AND COALESCE(NEW.ended_at, now()) > NEW.started_at
    THEN
      v_minutes := ROUND(EXTRACT(EPOCH FROM (COALESCE(NEW.ended_at, now()) - NEW.started_at)) / 60.0, 4);
      v_result := public.bill_session_minute(
        p_session_id   => NEW.id,
        p_session_type => 'chat',
        p_minutes      => v_minutes,
        p_man_id       => NEW.man_user_id,
        p_woman_id     => NEW.woman_user_id,
        p_man_count    => 1,
        p_minute_index => NULL
      );

      IF (v_result->>'success')::boolean IS TRUE THEN
        UPDATE public.active_chat_sessions
           SET total_minutes = v_minutes,
               total_earned  = COALESCE((v_result->>'earned')::numeric, 0)
         WHERE id = NEW.id;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 5) Backfill missing wallet_transactions for already-completed audio/video calls
DO $$
DECLARE
  r RECORD;
  v_minutes numeric;
  v_session_type text;
  v_result jsonb;
BEGIN
  FOR r IN
    SELECT vcs.*
    FROM public.video_call_sessions vcs
    WHERE vcs.status IN ('ended','completed')
      AND vcs.started_at IS NOT NULL
      AND vcs.ended_at IS NOT NULL
      AND vcs.ended_at > vcs.started_at
      AND NOT EXISTS (
        SELECT 1 FROM public.wallet_transactions wt
        WHERE wt.session_id = vcs.id
      )
    ORDER BY vcs.created_at
  LOOP
    v_minutes := ROUND(EXTRACT(EPOCH FROM (r.ended_at - r.started_at)) / 60.0, 4);
    v_session_type := CASE COALESCE(r.call_type, 'video')
      WHEN 'audio' THEN 'audio_call'
      WHEN 'video' THEN 'video_call'
      ELSE 'video_call'
    END;

    v_result := public.bill_session_minute(
      p_session_id   => r.id,
      p_session_type => v_session_type,
      p_minutes      => v_minutes,
      p_man_id       => r.man_user_id,
      p_woman_id     => r.woman_user_id,
      p_man_count    => 1,
      p_minute_index => floor(extract(epoch from r.created_at) / 60)::integer
    );

    IF (v_result->>'success')::boolean IS TRUE THEN
      UPDATE public.video_call_sessions
         SET total_minutes = v_minutes,
             total_earned  = COALESCE((v_result->>'earned')::numeric, 0)
       WHERE id = r.id;
    END IF;
  END LOOP;
END $$;