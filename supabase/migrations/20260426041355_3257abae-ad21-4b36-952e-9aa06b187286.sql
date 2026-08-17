-- 1) Insert 30 additional flower-themed private groups
DO $$
DECLARE
  v_owner uuid;
  v_names text[] := ARRAY[
    'Hibiscus','Magnolia','Peony','Camellia','Iris','Poppy','Bluebell','Carnation',
    'Chrysanthemum','Dahlia','Freesia','Gardenia','Geranium','Hyacinth','Petunia',
    'Primrose','Rhododendron','Snowdrop','Verbena','Violet','Zinnia','Anemone',
    'Azalea','Begonia','Buttercup','Clematis','Cosmos','Dandelion','Foxglove','Heather'
  ];
  v_name text;
BEGIN
  -- Use the owner of an existing seeded group to keep ownership consistent
  SELECT owner_id INTO v_owner
  FROM public.private_groups
  WHERE name = 'Rose'
  LIMIT 1;

  IF v_owner IS NULL THEN
    SELECT owner_id INTO v_owner FROM public.private_groups LIMIT 1;
  END IF;

  IF v_owner IS NULL THEN
    RAISE NOTICE 'No existing private_groups owner found — skipping seed.';
    RETURN;
  END IF;

  FOREACH v_name IN ARRAY v_names LOOP
    INSERT INTO public.private_groups (
      owner_id, name, description, min_gift_amount, access_type, is_active, is_live, participant_count
    )
    SELECT v_owner, v_name, v_name || ' room', 0, 'both', true, false, 0
    WHERE NOT EXISTS (SELECT 1 FROM public.private_groups WHERE name = v_name);
  END LOOP;
END $$;

-- 2) Update group-call billing to prefix the group's name in every description
CREATE OR REPLACE FUNCTION public.ledger_bill_group_call(
  p_session_id uuid, p_woman_id uuid, p_man_ids uuid[],
  p_minute_number integer, p_charge_per_man numeric, p_earn_per_man numeric,
  p_duration_seconds integer DEFAULT 60
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_man_id uuid;
  v_ref_man text;
  v_ref_woman text;
  v_total_woman_earn numeric := 0;
  v_man_balance numeric;
  v_fraction numeric;
  v_actual_charge numeric;
  v_actual_earn numeric;
  v_group_name text;
  v_label text;
  v_prefix text;
BEGIN
  v_fraction := GREATEST(p_duration_seconds, 0)::numeric / 60.0;
  v_actual_charge := ROUND(p_charge_per_man * v_fraction, 2);
  v_actual_earn := ROUND(p_earn_per_man * v_fraction, 2);

  -- p_session_id is the private_groups.id (room id) per usePrivateGroupCall
  SELECT name INTO v_group_name FROM public.private_groups WHERE id = p_session_id;
  v_prefix := CASE WHEN v_group_name IS NOT NULL AND length(v_group_name) > 0
                   THEN '[' || v_group_name || '] ' ELSE '' END;
  v_label := floor(p_duration_seconds/60) || 'm ' || mod(p_duration_seconds,60) || 's';

  IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE user_id = p_woman_id) THEN
    INSERT INTO public.wallets (user_id, balance, currency, gender)
    VALUES (p_woman_id, 0, 'INR', 'female') ON CONFLICT (user_id) DO NOTHING;
  END IF;

  FOREACH v_man_id IN ARRAY p_man_ids LOOP
    v_ref_man   := p_session_id::text || '_' || v_man_id::text || '_grp' || p_minute_number::text;
    v_ref_woman := p_session_id::text || '_' || p_woman_id::text || '_grpearn_' || v_man_id::text || '_' || p_minute_number::text;

    CONTINUE WHEN EXISTS (SELECT 1 FROM public.wallet_transactions WHERE idempotency_key = v_ref_man);

    SELECT balance INTO v_man_balance FROM public.wallets WHERE user_id = v_man_id FOR UPDATE;
    CONTINUE WHEN v_man_balance IS NULL OR v_man_balance < v_actual_charge;

    UPDATE public.wallets SET balance = balance - v_actual_charge, updated_at = now() WHERE user_id = v_man_id;

    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
    VALUES (v_man_id, 'debit', 'group_call_charge', v_actual_charge,
      v_prefix || 'Group Call: ' || v_label || ' @ ₹' || p_charge_per_man || '/min',
      p_session_id, (SELECT balance FROM public.wallets WHERE user_id = v_man_id), v_ref_man, 'completed',
      p_duration_seconds, p_charge_per_man);

    INSERT INTO public.ledger_transactions (user_id, session_id, transaction_type, debit, credit, rate_per_minute, duration_seconds, counterparty_id, reference_id, description)
    VALUES (v_man_id, p_session_id, 'group_call_charge', v_actual_charge, 0, p_charge_per_man, p_duration_seconds, p_woman_id, v_ref_man,
      v_prefix || 'Group Call: ' || v_label || ' @ ₹' || p_charge_per_man || '/min');

    PERFORM public.safe_ledger_insert(v_man_id, p_session_id, 'group_call_charge', v_actual_charge, 0,
      p_charge_per_man, p_duration_seconds, p_woman_id, v_ref_man,
      v_prefix || 'Group call charge ' || v_label, now());

    v_total_woman_earn := v_total_woman_earn + v_actual_earn;

    PERFORM public.safe_ledger_insert(p_woman_id, p_session_id, 'group_call_earning', 0, v_actual_earn,
      p_earn_per_man, p_duration_seconds, v_man_id, v_ref_woman,
      v_prefix || 'Group call earning ' || v_label, now());

    INSERT INTO public.wallet_transactions (user_id, type, transaction_type, amount, description, session_id, balance_after, idempotency_key, status, duration_seconds, rate_per_minute)
    VALUES (p_woman_id, 'credit', 'group_call_earning', v_actual_earn,
      v_prefix || 'Group Call Earning: ' || v_label || ' @ ₹' || p_earn_per_man || '/man',
      p_session_id, NULL, v_ref_woman, 'completed',
      p_duration_seconds, p_earn_per_man);

    INSERT INTO public.ledger_transactions (user_id, session_id, transaction_type, debit, credit, rate_per_minute, duration_seconds, counterparty_id, reference_id, description)
    VALUES (p_woman_id, p_session_id, 'group_call_earning', 0, v_actual_earn, p_earn_per_man, p_duration_seconds, v_man_id, v_ref_woman,
      v_prefix || 'Group Call Earning: ' || v_label || ' @ ₹' || p_earn_per_man || '/man');

    INSERT INTO public.women_earnings (user_id, amount, earning_type, description, group_id, man_user_id, rate_per_minute, minutes_billed, created_at)
    VALUES (p_woman_id, v_actual_earn, 'group_call',
      v_prefix || 'Group call earning ' || v_label || ' @ ₹' || p_earn_per_man || '/man',
      p_session_id, v_man_id, p_earn_per_man, v_fraction, now());
  END LOOP;

  IF v_total_woman_earn > 0 THEN
    UPDATE public.wallets SET balance = balance + v_total_woman_earn, updated_at = now() WHERE user_id = p_woman_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'minute', p_minute_number,
    'woman_earned', v_total_woman_earn, 'duration_seconds', p_duration_seconds,
    'group_name', v_group_name);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$;