
-- Fix the analytics function to use correct transaction_type values
CREATE OR REPLACE FUNCTION public.get_analytics_summary(p_start_date timestamptz, p_end_date timestamptz)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_totals jsonb;
  v_chart jsonb;
  v_gender jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_users', (SELECT count(*) FROM profiles),
    'active_users', (SELECT count(*) FROM user_status WHERE is_online = true),
    'total_matches', (SELECT count(*) FROM matches),
    'new_users_today', (SELECT count(*) FROM profiles WHERE created_at >= date_trunc('day', now()) AND created_at < date_trunc('day', now()) + interval '1 day'),
    'messages_count', (SELECT count(*) FROM chat_messages WHERE created_at >= p_start_date AND created_at <= p_end_date),
    'men_recharges', COALESCE((SELECT sum(credit) FROM ledger_transactions WHERE transaction_type = 'recharge' AND credit > 0 AND created_at >= p_start_date AND created_at <= p_end_date), 0),
    'men_spent', COALESCE((SELECT sum(debit) FROM ledger_transactions WHERE transaction_type IN ('chat_charge','video_call_charge','group_call_charge') AND debit > 0 AND created_at >= p_start_date AND created_at <= p_end_date), 0),
    'women_earnings', COALESCE((SELECT sum(credit) FROM ledger_transactions WHERE transaction_type = 'earning' AND credit > 0 AND created_at >= p_start_date AND created_at <= p_end_date), 0),
    'women_withdrawals', COALESCE((SELECT sum(amount) FROM withdrawal_requests WHERE status = 'completed' AND created_at >= p_start_date AND created_at <= p_end_date), 0),
    'avg_session_minutes', COALESCE((SELECT avg(total_minutes) FROM active_chat_sessions WHERE created_at >= p_start_date AND created_at <= p_end_date), 0)
  ) INTO v_totals;

  SELECT jsonb_build_object(
    'male', (SELECT count(*) FROM profiles WHERE lower(gender) = 'male'),
    'female', (SELECT count(*) FROM profiles WHERE lower(gender) = 'female'),
    'other', (SELECT count(*) FROM profiles WHERE gender IS NULL OR lower(gender) NOT IN ('male','female'))
  ) INTO v_gender;

  SELECT COALESCE(jsonb_agg(row_data ORDER BY bucket), '[]'::jsonb)
  INTO v_chart
  FROM (
    SELECT
      d.bucket,
      jsonb_build_object(
        'date', to_char(d.bucket, 'Mon DD'),
        'users', COALESCE(u.cnt, 0),
        'activeUsers', COALESCE(au.cnt, 0),
        'matches', COALESCE(m.cnt, 0),
        'messages', COALESCE(msg.cnt, 0),
        'revenue', COALESCE(r.recharges, 0) - COALESCE(w.withdrawals, 0)
      ) AS row_data
    FROM generate_series(
      date_trunc('day', p_start_date),
      date_trunc('day', p_end_date),
      '1 day'::interval
    ) AS d(bucket)
    LEFT JOIN LATERAL (
      SELECT count(*) AS cnt FROM profiles
      WHERE created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) u ON true
    LEFT JOIN LATERAL (
      SELECT count(DISTINCT sender_id) AS cnt FROM chat_messages
      WHERE created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) au ON true
    LEFT JOIN LATERAL (
      SELECT count(*) AS cnt FROM matches
      WHERE created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) m ON true
    LEFT JOIN LATERAL (
      SELECT count(*) AS cnt FROM chat_messages
      WHERE created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) msg ON true
    LEFT JOIN LATERAL (
      SELECT COALESCE(sum(credit), 0) AS recharges FROM ledger_transactions
      WHERE transaction_type = 'recharge' AND credit > 0
        AND created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) r ON true
    LEFT JOIN LATERAL (
      SELECT COALESCE(sum(amount), 0) AS withdrawals FROM withdrawal_requests
      WHERE status = 'completed'
        AND created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) w ON true
  ) sub;

  v_result := jsonb_build_object(
    'totals', v_totals,
    'gender', v_gender,
    'chart', v_chart
  );

  RETURN v_result;
END;
$$;

-- Now insert realistic sample data using correct transaction types
DO $$
DECLARE
  v_man_id uuid := '0b933372-7f04-4397-9aae-0e8be4730702';
  v_woman_id uuid := '04cad57a-2647-457e-beb4-9a5c60fbbe44';
  v_day integer;
  v_base_ts timestamptz;
  v_session_id uuid;
  v_mins integer;
BEGIN
  FOR v_day IN 0..29 LOOP
    v_base_ts := now() - (v_day || ' days')::interval;
    v_session_id := gen_random_uuid();

    -- Recharges every 3 days
    IF v_day % 3 = 0 THEN
      INSERT INTO ledger_transactions (user_id, transaction_type, credit, debit, description, created_at)
      VALUES (v_man_id, 'recharge', 200 + (random() * 300)::int, 0, 'Wallet recharge via Cashfree', v_base_ts - interval '8 hours');
    END IF;

    -- Daily chat charges - ₹4/min
    v_mins := 5 + (random() * 10)::int;
    INSERT INTO ledger_transactions (user_id, transaction_type, credit, debit, description, counterparty_id, session_id, rate_per_minute, duration_seconds, created_at)
    VALUES (v_man_id, 'chat_charge', 0, 4.0 * v_mins, 'Chat with Rani K - ' || v_mins || ' min', v_woman_id, v_session_id, 4.00, v_mins * 60, v_base_ts - interval '6 hours');

    -- Women earning from chat - ₹2/min
    INSERT INTO ledger_transactions (user_id, transaction_type, credit, debit, description, counterparty_id, session_id, rate_per_minute, duration_seconds, created_at)
    VALUES (v_woman_id, 'earning', 2.0 * v_mins, 0, 'Chat earning from Rajesh - ' || v_mins || ' min', v_man_id, v_session_id, 2.00, v_mins * 60, v_base_ts - interval '6 hours');

    -- Video call charges every 2 days - ₹8/min
    IF v_day % 2 = 0 THEN
      v_session_id := gen_random_uuid();
      v_mins := 3 + (random() * 7)::int;
      INSERT INTO ledger_transactions (user_id, transaction_type, credit, debit, description, counterparty_id, session_id, rate_per_minute, duration_seconds, created_at)
      VALUES (v_man_id, 'video_call_charge', 0, 8.0 * v_mins, 'Video call with Rani K - ' || v_mins || ' min', v_woman_id, v_session_id, 8.00, v_mins * 60, v_base_ts - interval '4 hours');

      INSERT INTO ledger_transactions (user_id, transaction_type, credit, debit, description, counterparty_id, session_id, rate_per_minute, duration_seconds, created_at)
      VALUES (v_woman_id, 'earning', 4.0 * v_mins, 0, 'Video earning from Rajesh - ' || v_mins || ' min', v_man_id, v_session_id, 4.00, v_mins * 60, v_base_ts - interval '4 hours');
    END IF;

    -- Group call charges every 4 days - ₹4/min
    IF v_day % 4 = 0 THEN
      v_session_id := gen_random_uuid();
      v_mins := 5 + (random() * 10)::int;
      INSERT INTO ledger_transactions (user_id, transaction_type, credit, debit, description, counterparty_id, session_id, rate_per_minute, duration_seconds, created_at)
      VALUES (v_man_id, 'group_call_charge', 0, 4.0 * v_mins, 'Group call - ' || v_mins || ' min', v_woman_id, v_session_id, 4.00, v_mins * 60, v_base_ts - interval '2 hours');

      INSERT INTO ledger_transactions (user_id, transaction_type, credit, debit, description, counterparty_id, session_id, rate_per_minute, duration_seconds, created_at)
      VALUES (v_woman_id, 'earning', 0.50 * v_mins, 0, 'Group call earning - ' || v_mins || ' min', v_man_id, v_session_id, 0.50, v_mins * 60, v_base_ts - interval '2 hours');
    END IF;

  END LOOP;
END $$;
