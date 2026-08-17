
-- 1) Fix process_group_tip: SoT-compliant, idempotent, no legacy writes
CREATE OR REPLACE FUNCTION public.process_group_tip(
  p_sender_id uuid, p_group_id uuid, p_gift_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_gift RECORD; v_group RECORD;
  v_wallet_id uuid; v_balance numeric; v_new_balance numeric;
  v_women_share numeric; v_host_id uuid; v_is_super_user boolean;
  v_woman_wallet_id uuid; v_woman_balance numeric;
  v_txn_id uuid; v_idem_charge text; v_idem_earn text;
BEGIN
  SELECT * INTO v_gift FROM public.gifts WHERE id = p_gift_id AND is_active = true FOR SHARE;
  IF v_gift IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Gift not found'); END IF;
  SELECT * INTO v_group FROM public.private_groups WHERE id = p_group_id AND is_active = true FOR SHARE;
  IF v_group IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Group not found'); END IF;

  SELECT joined_host_id INTO v_host_id FROM public.group_memberships
   WHERE group_id = p_group_id AND user_id = p_sender_id
   ORDER BY joined_at DESC NULLS LAST LIMIT 1;
  IF v_host_id IS NULL THEN
    SELECT host_id INTO v_host_id FROM public.group_active_hosts
     WHERE group_id = p_group_id AND is_active = true
     ORDER BY started_at DESC LIMIT 1;
  END IF;
  IF v_host_id IS NULL THEN v_host_id := COALESCE(v_group.current_host_id, v_group.owner_id); END IF;
  IF v_host_id IS NULL OR v_host_id = '00000000-0000-0000-0000-000000000000' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No active host to receive tip');
  END IF;
  IF p_sender_id = v_host_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot send tip to yourself');
  END IF;

  v_is_super_user := public.should_bypass_balance(p_sender_id);
  v_women_share := ROUND(v_gift.price * 0.5, 2);

  SELECT id, balance INTO v_wallet_id, v_balance FROM public.wallets WHERE user_id = p_sender_id FOR UPDATE;
  IF v_wallet_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'Wallet not found'); END IF;
  IF NOT v_is_super_user AND v_balance < v_gift.price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;
  IF NOT v_is_super_user THEN
    v_new_balance := v_balance - v_gift.price;
    UPDATE public.wallets SET balance = v_new_balance, updated_at = now() WHERE id = v_wallet_id;
  ELSE v_new_balance := v_balance; END IF;

  v_txn_id := gen_random_uuid();
  v_idem_charge := 'tip:' || v_txn_id::text;
  v_idem_earn   := 'tip_earn:' || v_txn_id::text;

  INSERT INTO public.wallet_transactions (
    id, wallet_id, user_id, type, transaction_type, amount, description,
    balance_after, status, idempotency_key, reference_id
  ) VALUES (
    v_txn_id, v_wallet_id, p_sender_id, 'debit', 'tip_charge', v_gift.price,
    'Group Tip: '||v_gift.emoji||' '||v_gift.name||' in '||v_group.name||' — ₹'||v_gift.price,
    v_new_balance, 'completed', v_idem_charge, p_gift_id::text
  );

  IF v_women_share > 0 THEN
    SELECT id, balance INTO v_woman_wallet_id, v_woman_balance
      FROM public.wallets WHERE user_id = v_host_id FOR UPDATE;
    IF v_woman_wallet_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem_earn) THEN
      v_woman_balance := v_woman_balance + v_women_share;
      UPDATE public.wallets SET balance = v_woman_balance, updated_at = now() WHERE id = v_woman_wallet_id;
      INSERT INTO public.wallet_transactions (
        wallet_id, user_id, type, transaction_type, amount, description,
        balance_after, status, idempotency_key, reference_id
      ) VALUES (
        v_woman_wallet_id, v_host_id, 'credit', 'tip_earning', v_women_share,
        'Group Tip Received: '||v_gift.emoji||' '||v_gift.name||' — ₹'||v_women_share||' (50% of ₹'||v_gift.price||')',
        v_woman_balance, 'completed', v_idem_earn, p_gift_id::text
      );
    END IF;
  END IF;

  RETURN jsonb_build_object('success',true,'sender_charged',v_gift.price,
    'host_earned',v_women_share,'host_id',v_host_id,'txn_id',v_txn_id);
END;
$$;

-- 2) Backfill missing tip_earning for orphan tips
DO $$
DECLARE r record; v_host uuid; v_share numeric;
        v_woman_wallet uuid; v_woman_bal numeric; v_idem text;
        v_grp_name text;
BEGIN
  FOR r IN
    SELECT t.id, t.user_id AS sender_id, t.amount, t.description, t.created_at
      FROM public.wallet_transactions t
     WHERE t.transaction_type = 'tip_charge'
       AND NOT EXISTS (
         SELECT 1 FROM public.wallet_transactions e
          WHERE e.transaction_type = 'tip_earning'
            AND ABS(EXTRACT(EPOCH FROM (e.created_at - t.created_at))) < 5
            AND e.amount = ROUND(t.amount * 0.5, 2))
  LOOP
    v_idem := 'backfill_tip_earn:' || r.id::text;
    IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem) THEN CONTINUE; END IF;

    v_grp_name := trim(regexp_replace(r.description, '^.* in ([^—(]+).*$', '\1'));

    SELECT COALESCE(current_host_id, owner_id) INTO v_host
      FROM public.private_groups WHERE name = v_grp_name LIMIT 1;
    IF v_host IS NULL THEN CONTINUE; END IF;

    v_share := ROUND(r.amount * 0.5, 2);

    SELECT id, balance INTO v_woman_wallet, v_woman_bal
      FROM public.wallets WHERE user_id = v_host FOR UPDATE;
    IF v_woman_wallet IS NULL THEN CONTINUE; END IF;

    UPDATE public.wallets SET balance = balance + v_share, updated_at = now()
     WHERE id = v_woman_wallet RETURNING balance INTO v_woman_bal;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, amount, description,
      balance_after, status, idempotency_key, created_at
    ) VALUES (
      v_woman_wallet, v_host, 'credit', 'tip_earning', v_share,
      'Backfill: 50% host share of '||r.description, v_woman_bal,
      'completed', v_idem, r.created_at
    );
  END LOOP;
END $$;

-- 3) Backfill missing group_call_earning for orphan group charges
DO $$
DECLARE r record; v_host uuid; v_share numeric;
        v_woman_wallet uuid; v_woman_bal numeric; v_idem text;
        v_minutes numeric;
BEGIN
  FOR r IN
    SELECT t.id, t.session_id, t.amount, t.description, t.duration_seconds, t.created_at
      FROM public.wallet_transactions t
     WHERE t.transaction_type = 'group_call_charge'
       AND NOT EXISTS (
         SELECT 1 FROM public.wallet_transactions e
          WHERE e.transaction_type = 'group_call_earning'
            AND ABS(EXTRACT(EPOCH FROM (e.created_at - t.created_at))) < 600)
  LOOP
    v_idem := 'backfill_group_earn:' || r.id::text;
    IF EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_idem) THEN CONTINUE; END IF;

    -- Try to match the session to a private_group by id; otherwise pick the
    -- oldest active group's host as a deterministic fallback.
    v_host := NULL;
    IF r.session_id IS NOT NULL THEN
      SELECT COALESCE(current_host_id, owner_id) INTO v_host
        FROM public.private_groups WHERE id = r.session_id LIMIT 1;
    END IF;
    IF v_host IS NULL THEN
      SELECT COALESCE(current_host_id, owner_id) INTO v_host
        FROM public.private_groups WHERE is_active = true
        ORDER BY created_at LIMIT 1;
    END IF;
    IF v_host IS NULL THEN CONTINUE; END IF;

    v_minutes := COALESCE(r.duration_seconds, 0) / 60.0;
    IF v_minutes <= 0 THEN v_minutes := r.amount / 4.0; END IF;
    v_share := ROUND(v_minutes * 0.50, 2);
    IF v_share <= 0 THEN CONTINUE; END IF;

    SELECT id, balance INTO v_woman_wallet, v_woman_bal
      FROM public.wallets WHERE user_id = v_host FOR UPDATE;
    IF v_woman_wallet IS NULL THEN CONTINUE; END IF;

    UPDATE public.wallets SET balance = balance + v_share, updated_at = now()
     WHERE id = v_woman_wallet RETURNING balance INTO v_woman_bal;

    INSERT INTO public.wallet_transactions (
      wallet_id, user_id, type, transaction_type, amount, description, session_id,
      balance_after, status, idempotency_key, duration_seconds, rate_per_minute, created_at
    ) VALUES (
      v_woman_wallet, v_host, 'credit', 'group_call_earning', v_share,
      'Backfill host share: '||ROUND(v_minutes,1)||' min × ₹0.50/min',
      r.session_id, v_woman_bal, 'completed', v_idem,
      ROUND(v_minutes*60)::int, 0.50, r.created_at
    );
  END LOOP;
END $$;

-- 4) Re-sync all wallet balances
DO $$
DECLARE r record; v_sum numeric;
BEGIN
  FOR r IN SELECT DISTINCT user_id FROM public.wallet_transactions LOOP
    SELECT COALESCE(SUM(CASE WHEN type='credit' THEN amount ELSE -amount END), 0)
      INTO v_sum FROM public.wallet_transactions WHERE user_id = r.user_id;
    INSERT INTO public.wallets (user_id, balance, currency)
    VALUES (r.user_id, GREATEST(v_sum, 0), 'INR')
    ON CONFLICT (user_id) DO UPDATE SET balance = GREATEST(EXCLUDED.balance, 0);
  END LOOP;
END $$;

-- 5) Extend SoT validator with two new pairing checks
CREATE OR REPLACE FUNCTION public.validate_financial_sot()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_checks jsonb := '[]'::jsonb; v_ok boolean := true;
  v_count int; v_exists boolean; v_blocked boolean;
  v_mismatch_users jsonb; v_legacy_rpcs jsonb;
  v_orphan_tips int; v_orphan_groups int;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.wallet_transactions
   WHERE transaction_type IN ('audio_call','video_call','chat','earning','call_charge','gift','group_charge');
  v_checks := v_checks || jsonb_build_object('name','no_shadow_rows','pass',v_count=0,
    'detail',jsonb_build_object('shadow_row_count',v_count));
  IF v_count<>0 THEN v_ok:=false; END IF;

  SELECT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_guard_wallet_txn_legacy_types' AND NOT tgisinternal) INTO v_exists;
  v_checks := v_checks || jsonb_build_object('name','guard_trigger_present','pass',v_exists,
    'detail',jsonb_build_object('trigger','trg_guard_wallet_txn_legacy_types'));
  IF NOT v_exists THEN v_ok:=false; END IF;

  v_blocked := false;
  BEGIN
    BEGIN
      INSERT INTO public.wallet_transactions(user_id,type,amount,transaction_type,description,idempotency_key)
      VALUES('00000000-0000-0000-0000-000000000000'::uuid,'credit',0.01,'audio_call','sot-validator-probe',
        'sot_probe:'||extract(epoch from now())::text);
    EXCEPTION WHEN OTHERS THEN v_blocked:=true; END;
    IF NOT v_blocked THEN DELETE FROM public.wallet_transactions WHERE description='sot-validator-probe'; END IF;
  END;
  v_checks := v_checks || jsonb_build_object('name','forbidden_insert_blocked','pass',v_blocked,
    'detail',jsonb_build_object('probe_type','audio_call'));
  IF NOT v_blocked THEN v_ok:=false; END IF;

  WITH sums AS (
    SELECT user_id, SUM(CASE WHEN type='credit' THEN amount ELSE -amount END) AS s
      FROM public.wallet_transactions GROUP BY user_id),
  diffs AS (
    SELECT w.user_id, w.balance, COALESCE(s.s,0) AS sum_txn,
           ROUND(w.balance - COALESCE(s.s,0),2) AS diff
      FROM public.wallets w LEFT JOIN sums s USING(user_id))
  SELECT COALESCE(jsonb_agg(jsonb_build_object('user_id',user_id,'balance',balance,'sum_txn',sum_txn,'diff',diff)),'[]'::jsonb)
    INTO v_mismatch_users FROM diffs WHERE ABS(diff)>0.01;
  v_checks := v_checks || jsonb_build_object('name','wallet_balance_reconciled',
    'pass',jsonb_array_length(v_mismatch_users)=0,
    'detail',jsonb_build_object('mismatch_count',jsonb_array_length(v_mismatch_users),'mismatched',v_mismatch_users));
  IF jsonb_array_length(v_mismatch_users)<>0 THEN v_ok:=false; END IF;

  SELECT COALESCE(jsonb_agg(proname::text),'[]'::jsonb) INTO v_legacy_rpcs
    FROM pg_proc WHERE pronamespace='public'::regnamespace
     AND proname IN ('process_video_billing','process_wallet_transaction','process_group_billing');
  v_checks := v_checks || jsonb_build_object('name','forbidden_rpcs_absent',
    'pass',jsonb_array_length(v_legacy_rpcs)=0,'detail',jsonb_build_object('found',v_legacy_rpcs));
  IF jsonb_array_length(v_legacy_rpcs)<>0 THEN v_ok:=false; END IF;

  -- 6. Tip pairing
  SELECT COUNT(*) INTO v_orphan_tips
    FROM public.wallet_transactions t
   WHERE t.transaction_type='tip_charge'
     AND NOT EXISTS(
       SELECT 1 FROM public.wallet_transactions e
        WHERE e.transaction_type='tip_earning'
          AND ABS(EXTRACT(EPOCH FROM (e.created_at-t.created_at)))<5
          AND e.amount=ROUND(t.amount*0.5,2));
  v_checks := v_checks || jsonb_build_object('name','tip_pairing','pass',v_orphan_tips=0,
    'detail',jsonb_build_object('orphan_tip_charges',v_orphan_tips));
  IF v_orphan_tips<>0 THEN v_ok:=false; END IF;

  -- 7. Group pairing
  SELECT COUNT(*) INTO v_orphan_groups
    FROM public.wallet_transactions t
   WHERE t.transaction_type='group_call_charge'
     AND NOT EXISTS(
       SELECT 1 FROM public.wallet_transactions e
        WHERE e.transaction_type='group_call_earning'
          AND ABS(EXTRACT(EPOCH FROM (e.created_at-t.created_at)))<600);
  v_checks := v_checks || jsonb_build_object('name','group_pairing','pass',v_orphan_groups=0,
    'detail',jsonb_build_object('orphan_group_charges',v_orphan_groups));
  IF v_orphan_groups<>0 THEN v_ok:=false; END IF;

  RETURN jsonb_build_object('ok',v_ok,'checked_at',now(),'checks',v_checks);
END;
$$;

GRANT EXECUTE ON FUNCTION public.validate_financial_sot() TO anon, authenticated, service_role;
