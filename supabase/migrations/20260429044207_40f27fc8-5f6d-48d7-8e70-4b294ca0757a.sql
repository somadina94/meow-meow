-- =====================================================================
-- UNIFIED BILLING HARDENING
-- All chat / audio / video / group call / gift / tip events flow ONLY
-- through bill_session_minute and bill_gift_or_tip, writing to both
-- billing_ledger (men) and earnings_ledger (women) — the SoT for
-- monthly_statements and wallets.
-- =====================================================================

-- 1) Drop legacy/duplicate billing RPCs that bypass the unified ledger.
DROP FUNCTION IF EXISTS public.process_chat_billing(uuid, numeric) CASCADE;
DROP FUNCTION IF EXISTS public.process_audio_billing(text, uuid, uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.process_video_billing_v2(text, uuid, uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.process_group_billing_v2(text, text, uuid, uuid[], numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.process_gift_billing(uuid, uuid, numeric, text, text) CASCADE;

-- 2) Rewrite bill_session_minute with deterministic idempotency.
--    Key = session|type|man|minute_index → exactly one charge per
--    (session, session_type, man, minute_index). Heartbeat retries become
--    no-ops; minute boundary races no longer silently swallow a charge.
CREATE OR REPLACE FUNCTION public.bill_session_minute(
  p_session_id uuid,
  p_session_type text,
  p_minutes numeric,
  p_man_id uuid,
  p_woman_id uuid,
  p_man_count integer DEFAULT 1,
  p_minute_index integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pricing jsonb;
  v_wallet RECORD;
  v_man_rate numeric(10,2);
  v_woman_rate numeric(10,2);
  v_charge numeric(10,2);
  v_earn numeric(10,2);
  v_balance_after numeric(10,2);
  v_idem_key text;
  v_is_super boolean := false;
  v_minute_idx integer;
BEGIN
  IF p_session_type NOT IN ('chat','audio_call','video_call','private_group_call') THEN
    RETURN jsonb_build_object('success',false,'error','Invalid session_type');
  END IF;
  IF p_minutes <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','minutes must be > 0');
  END IF;

  -- Deterministic minute index: caller can pass it (preferred); else
  -- derive from current minute floor — still deterministic per minute,
  -- but caller-supplied is safer.
  v_minute_idx := COALESCE(p_minute_index,
    FLOOR(EXTRACT(EPOCH FROM date_trunc('minute', now())) / 60)::integer);

  v_idem_key := 'session|' || p_session_id::text || '|' || p_session_type
                || '|' || p_man_id::text || '|' || v_minute_idx::text;

  -- Atomic dedupe via UNIQUE(idempotency_key) on billing_ledger
  IF EXISTS (SELECT 1 FROM public.billing_ledger WHERE idempotency_key = v_idem_key) THEN
    RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
  END IF;

  v_pricing := public.get_unified_pricing();
  v_man_rate := CASE p_session_type
    WHEN 'chat'               THEN (v_pricing->>'chat_man_rate')::numeric
    WHEN 'audio_call'         THEN (v_pricing->>'audio_man_rate')::numeric
    WHEN 'video_call'         THEN (v_pricing->>'video_man_rate')::numeric
    WHEN 'private_group_call' THEN (v_pricing->>'group_man_rate')::numeric
  END;
  v_woman_rate := CASE p_session_type
    WHEN 'chat'               THEN (v_pricing->>'chat_woman_rate')::numeric
    WHEN 'audio_call'         THEN (v_pricing->>'audio_woman_rate')::numeric
    WHEN 'video_call'         THEN (v_pricing->>'video_woman_rate')::numeric
    WHEN 'private_group_call' THEN (v_pricing->>'group_woman_rate')::numeric
  END;

  v_charge := ROUND(v_man_rate * p_minutes, 2);
  v_earn   := ROUND(v_woman_rate * p_minutes * GREATEST(p_man_count,1), 2);

  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id IN (SELECT user_id FROM public.profiles WHERE id = p_man_id)
      AND role IN ('admin','super_user')
  ) INTO v_is_super;

  IF NOT v_is_super THEN
    SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success',false,'error','Wallet not found');
    END IF;
    IF v_wallet.balance < v_charge THEN
      RETURN jsonb_build_object('success',false,'error','Insufficient balance',
                                'balance',v_wallet.balance,'required',v_charge);
    END IF;
    v_balance_after := v_wallet.balance - v_charge;
    UPDATE public.wallets SET balance = v_balance_after, updated_at = now() WHERE id = v_wallet.id;

    INSERT INTO public.billing_ledger (
      man_id, woman_id, entry_type, amount, balance_after,
      session_type, session_id, duration_minutes, rate_applied,
      description, idempotency_key, status
    ) VALUES (
      p_man_id, p_woman_id, 'debit', v_charge, v_balance_after,
      p_session_type, p_session_id, p_minutes, v_man_rate,
      initcap(replace(p_session_type,'_',' ')) || ' — ' || p_minutes || ' min @ ₹' || v_man_rate || '/min',
      v_idem_key, 'completed'
    )
    ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  IF v_earn > 0 AND p_woman_id IS NOT NULL THEN
    INSERT INTO public.earnings_ledger (
      woman_id, man_id, amount, session_type, session_id,
      duration_minutes, rate_applied, description, entry_type
    ) VALUES (
      p_woman_id, p_man_id, v_earn, p_session_type, p_session_id,
      p_minutes, v_woman_rate,
      initcap(replace(p_session_type,'_',' ')) || ' earnings — ' || p_minutes || ' min @ ₹' || v_woman_rate || '/min',
      'credit'
    );
  END IF;

  RETURN jsonb_build_object(
    'success',true,'session_type',p_session_type,
    'charged',CASE WHEN v_is_super THEN 0 ELSE v_charge END,
    'earned',v_earn,'man_rate',v_man_rate,'woman_rate',v_woman_rate,
    'minutes',p_minutes,'super_user_skip',v_is_super,
    'minute_index',v_minute_idx
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.bill_session_minute(uuid, text, numeric, uuid, uuid, integer, integer)
  TO authenticated, service_role;

-- 3) Rewrite bill_gift_or_tip with deterministic idempotency.
--    Stable key = type|man|woman|reference_id. Caller MUST pass a stable
--    reference_id (gift txn id / message id / random uuid). Eliminates
--    double-charge from rapid double-clicks and webhook retries.
CREATE OR REPLACE FUNCTION public.bill_gift_or_tip(
  p_man_id uuid,
  p_woman_id uuid,
  p_amount numeric,
  p_type text,
  p_description text DEFAULT NULL,
  p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pricing jsonb; v_wallet RECORD;
  v_pct numeric(5,2); v_woman_credit numeric(10,2);
  v_balance_after numeric(10,2); v_is_super boolean := false;
  v_idem text;
  v_ref text;
BEGIN
  IF p_type NOT IN ('gift','tip') THEN
    RETURN jsonb_build_object('success',false,'error','type must be gift or tip');
  END IF;
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success',false,'error','amount must be > 0');
  END IF;

  v_ref := COALESCE(NULLIF(p_reference_id, ''),
                    gen_random_uuid()::text);
  v_idem := p_type || '|' || p_man_id::text || '|' || COALESCE(p_woman_id::text,'') || '|' || v_ref;

  IF EXISTS (SELECT 1 FROM public.billing_ledger WHERE idempotency_key = v_idem) THEN
    RETURN jsonb_build_object('success',true,'duplicate_skipped',true);
  END IF;

  v_pricing := public.get_unified_pricing();
  v_pct := CASE p_type
    WHEN 'gift' THEN (v_pricing->>'gift_woman_pct')::numeric
    ELSE (v_pricing->>'tip_woman_pct')::numeric
  END;
  v_woman_credit := ROUND(p_amount * v_pct / 100.0, 2);

  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id IN (SELECT user_id FROM public.profiles WHERE id = p_man_id)
      AND role IN ('admin','super_user')
  ) INTO v_is_super;

  IF NOT v_is_super THEN
    SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_man_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success',false,'error','Wallet not found');
    END IF;
    IF v_wallet.balance < p_amount THEN
      RETURN jsonb_build_object('success',false,'error','Insufficient balance',
                                'balance',v_wallet.balance,'required',p_amount);
    END IF;
    v_balance_after := v_wallet.balance - p_amount;
    UPDATE public.wallets SET balance = v_balance_after, updated_at = now() WHERE id = v_wallet.id;

    INSERT INTO public.billing_ledger (
      man_id, woman_id, entry_type, amount, balance_after,
      session_type, rate_applied, description, reference_id, status,
      idempotency_key
    ) VALUES (
      p_man_id, p_woman_id, 'debit', p_amount, v_balance_after,
      p_type, p_amount,
      COALESCE(p_description, initcap(p_type) || ' sent — ₹' || p_amount),
      v_ref, 'completed', v_idem
    )
    ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  IF v_woman_credit > 0 AND p_woman_id IS NOT NULL THEN
    INSERT INTO public.earnings_ledger (
      woman_id, man_id, amount, session_type, rate_applied, description, entry_type
    ) VALUES (
      p_woman_id, p_man_id, v_woman_credit, p_type, v_pct,
      COALESCE(p_description, initcap(p_type) || ' received — ' || v_pct || '% of ₹' || p_amount),
      'credit'
    );
  END IF;

  RETURN jsonb_build_object(
    'success',true,'type',p_type,
    'charged',CASE WHEN v_is_super THEN 0 ELSE p_amount END,
    'woman_credit',v_woman_credit,'woman_pct',v_pct,
    'idempotency_key',v_idem
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.bill_gift_or_tip(uuid, uuid, numeric, text, text, text)
  TO authenticated, service_role;